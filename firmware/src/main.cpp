// Combact-bot control — ESP32 firmware.
//
// SoftAP + UDP control link, 18-byte RC packets at ~50 Hz,
// 5 channels, 300 ms failsafe (competition allows up to 5 s),
// telemetry back to the phone at 5 Hz.

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <esp_wifi.h>
#include <esp_task_wdt.h>

#include "config.h"
#include "protocol.h"
#include "mixer.h"
#include "failsafe.h"
#include "motor_driver.h"

// ---------------- Drivers ----------------
#if DRIVE_DRIVER == DRIVER_BTS7960
static BTS7960Driver driveLeft (PIN_LEFT_RPWM,  PIN_LEFT_LPWM,
                                PIN_LEFT_REN,   PIN_LEFT_LEN,
                                0, 1, DRIVE_PWM_FREQ, DRIVE_PWM_BITS);
static BTS7960Driver driveRight(PIN_RIGHT_RPWM, PIN_RIGHT_LPWM,
                                PIN_RIGHT_REN,  PIN_RIGHT_LEN,
                                2, 3, DRIVE_PWM_FREQ, DRIVE_PWM_BITS);
#else
static L298Driver driveLeft (PIN_LEFT_IN1,  PIN_LEFT_IN2,  PIN_LEFT_ENA,
                             0, DRIVE_PWM_FREQ, DRIVE_PWM_BITS);
static L298Driver driveRight(PIN_RIGHT_IN3, PIN_RIGHT_IN4, PIN_RIGHT_ENB,
                             1, DRIVE_PWM_FREQ, DRIVE_PWM_BITS);
#endif
static BTS7960Driver weapon(PIN_WEAPON_RPWM, PIN_WEAPON_LPWM,
                            PIN_WEAPON_REN,  PIN_WEAPON_LEN,
                            4, 5, WEAPON_PWM_FREQ, WEAPON_PWM_BITS);

// ---------------- State ----------------
static WiFiUDP      udp;
static Failsafe     failsafe(FAILSAFE_TIMEOUT_MS);
static proto::LinkStats linkStats;
static proto::RcPacket rc;              // last accepted command
static bool         armed = false;      // weapon latch — cleared by failsafe
static bool         fsActive = true;    // start in failsafe until first packet
static IPAddress    clientIp;
static uint16_t     clientPort = 0;
static bool         haveClient = false;

static uint32_t lastTeleMs = 0;
static uint32_t rxCountWindow = 0, rxWindowStart = 0;
static uint16_t rxRateX10 = 0;
static uint32_t lastLedToggle = 0;
static bool     ledState = false;

static void outputsSafe() {
    driveLeft.stop();
    driveRight.stop();
    weapon.stop();
}

static int8_t peerRssiDbm() {
    wifi_sta_list_t list;
    if (esp_wifi_ap_get_sta_list(&list) == ESP_OK && list.num > 0) {
        return (int8_t)list.sta[0].rssi;
    }
    return 0;
}

static uint16_t batteryMv() {
#if PIN_BATT_ADC >= 0
    uint32_t acc = 0;
    for (int i = 0; i < BATT_SAMPLES; i++) acc += analogReadMilliVolts(PIN_BATT_ADC);
    float pinMv = (float)acc / BATT_SAMPLES;
    float mv = pinMv * (BATT_R_TOP_OHM + BATT_R_BOT_OHM) / BATT_R_BOT_OHM;
    return (uint16_t)(mv > 65535.0f ? 65535.0f : mv);
#else
    return 0;
#endif
}

static void applyCommand(const proto::RcPacket& p) {
    DriveOutput d = mixDifferential(p.ch[proto::CH_THROTTLE],
                                    p.ch[proto::CH_STEER],
                                    p.flags & proto::FLAG_LOW_SPEED,
                                    p.flags & proto::FLAG_INVERT,
                                    DRIVE_DEADBAND);
    driveLeft.setSpeed(d.left);
    driveRight.setSpeed(d.right);

    armed = (p.flags & proto::FLAG_ARMED) != 0;
#if WEAPON_SINGLE_DIRECTION
    int16_t hw = p.ch[proto::CH_HAMMER];
    if (hw < 0) hw = 0;
    weapon.setSpeed(armed ? hw : 0);
#else
    weapon.setSpeed(armed ? p.ch[proto::CH_HAMMER] : 0);
#endif
}

static void sendTelemetry(uint32_t now) {
    proto::TelemetryPacket t;
    t.flags = 0;
    if (!fsActive)  t.flags |= proto::TELE_LINKED;
    if (armed)      t.flags |= proto::TELE_ARMED;
    if (fsActive)   t.flags |= proto::TELE_FAILSAFE;
    t.lastSeq   = linkStats.lastSeq;
    t.batteryMv = batteryMv();
    t.rssiDbm   = peerRssiDbm();
    t.rxRateX10 = rxRateX10;
    t.lost      = linkStats.lost;
    proto::encodeTelemetry(t);
    udp.beginPacket(clientIp, clientPort);
    udp.write(reinterpret_cast<const uint8_t*>(&t), proto::kTelemetryPacketSize);
    udp.endPacket();
}

void setup() {
    // Safe outputs BEFORE anything else, so a reboot during a match
    // never glitches the motors.
    pinMode(PIN_LED_STATUS, OUTPUT);
    digitalWrite(PIN_LED_STATUS, LOW);
    driveLeft.begin();
    driveRight.begin();
    weapon.begin();
    outputsSafe();

    Serial.begin(115200);
    Serial.println(F("combact-bot: boot"));

    WiFi.mode(WIFI_AP);
    WiFi.softAP(WIFI_SSID, WIFI_PASSWORD, WIFI_CHANNEL, WIFI_HIDDEN);
    esp_wifi_set_ps(WIFI_PS_NONE);          // biggest latency win
    esp_wifi_set_max_tx_power(84);          // 84 * 0.25 dBm = 21 dBm ceiling

    udp.begin(UDP_PORT);

#if PIN_BATT_ADC >= 0
    analogSetPinAttenuation(PIN_BATT_ADC, ADC_11db);
#endif

    esp_task_wdt_init(WDT_TIMEOUT_S, true);
    esp_task_wdt_add(NULL);

    Serial.print(F("combact-bot: AP up, ip="));
    Serial.println(WiFi.softAPIP());
    rxWindowStart = millis();
}

void loop() {
    esp_task_wdt_reset();
    uint32_t now = millis();

    // ---- RX: apply the newest valid packet, drop everything else ----
    int n = udp.parsePacket();
    if (n > 0) {
        static uint8_t buf[64];
        int r = udp.read(buf, sizeof(buf));
        proto::RcPacket p;
        if (r == (int)proto::kRcPacketSize &&
            proto::decodeRc(buf, (size_t)r, p) &&
            linkStats.accept(p.seq)) {
            clientIp   = udp.remoteIP();
            clientPort = udp.remotePort();
            haveClient = true;
            failsafe.onValidPacket(now);
            rc = p;
            rxCountWindow++;
        }
    }

    // ---- Failsafe ----
    fsActive = failsafe.active(now);
    if (fsActive) {
        outputsSafe();
        armed = false;               // hammer stays dead until re-armed
    } else {
        applyCommand(rc);
    }

    // ---- RX rate metering (packets/sec * 10) ----
    if (now - rxWindowStart >= 1000) {
        rxRateX10 = (uint16_t)(rxCountWindow * 10 * 1000 / (now - rxWindowStart));
        rxCountWindow = 0;
        rxWindowStart = now;
    }

    // ---- Telemetry ----
    if (haveClient && now - lastTeleMs >= TELEMETRY_PERIOD_MS) {
        lastTeleMs = now;
        sendTelemetry(now);
    }

    // ---- Status LED: solid = linked, fast blink = failsafe ----
    if (fsActive) {
        if (now - lastLedToggle >= 100) {
            lastLedToggle = now;
            ledState = !ledState;
            digitalWrite(PIN_LED_STATUS, ledState);
        }
    } else if (!ledState) {
        ledState = true;
        digitalWrite(PIN_LED_STATUS, HIGH);
    }
}
