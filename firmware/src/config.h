#pragma once

// ============================================================
//  Combact-bot control — all user-tunable settings live here.
//  Pins below are defaults for a 38-pin ESP32 DevKit; change
//  them to match your wiring before flashing.
// ============================================================

// ---------------- Network ----------------
#define WIFI_SSID        "COMBACT-BOT"
#define WIFI_PASSWORD    "combact123"   // WPA2, min 8 chars — change before the event
#define WIFI_CHANNEL     6              // 1, 6 or 11; pick the least crowded at the venue
#define WIFI_HIDDEN      0
#define DEBUG_RX         1              // 1 Hz serial log of incoming UDP
#define UDP_PORT         4210           // control in + telemetry out on one port

// ---------------- Timing ----------------
// Competition rule: stop everything if the link drops for 5 s.
// We trip much earlier — 300 ms — which is stricter and safer.
// If it feels twitchy on a congested venue, raise it (must stay < 5000).
#define FAILSAFE_TIMEOUT_MS   300
#define TELEMETRY_PERIOD_MS   200       // robot -> phone, 5 Hz
#define WDT_TIMEOUT_S         3

// ---------------- Motor driver ----------------
// Target hardware: a generic 4-channel brushed-DC driver board
// (IN1/IN2 per channel, optional EN per channel). We drive every motor
// in "two PWM inputs" mode: PWM on IN1 = forward, PWM on IN2 = reverse,
// both low = coast. This works for L9110S / DRV8833 / TB6612 style boards
// (no EN pin -> leave the EN GPIO unconnected) and for L298N-style boards
// (EN is held HIGH by the firmware, or jumper it to 5V).
// Channels used: CH1 = left wheel, CH2 = right wheel, CH3 = hammer, CH4 spare.
// All pins below are plain output-capable GPIOs: no boot-strapping pins
// (0/2/12/15), no flash pins (6-11), no input-only pins (34-39).
#define DRIVER_L298N     1   // IN1/IN2 + ENA(PWM) per motor (legacy mapping)
#define DRIVER_BTS7960   2   // two PWM inputs per motor (+ optional EN pins)
#define DRIVER_SHIELD    3   // L293D Motor Shield v1 (74HC595 dir + PWM/motor)
#define DRIVER_UART      4   // Arduino UNO + Motor Shield bridge over Serial2 (firmware/uno_bridge)
#define DRIVE_DRIVER     DRIVER_UART

// ---- UART bridge: ESP32 GPIO17 (TX) -> UNO pin 0 (RX), common GND ----
#define UART_BRIDGE_TX_PIN   17
#define UART_BRIDGE_RX_PIN   16   // unused, left free
#define UART_BRIDGE_BAUD     115200
#define UART_BRIDGE_PERIOD_MS 20  // frame rate when nothing changes (keeps UNO failsafe fed)

// ---- L293D Motor Shield v1 (Adafruit clone) wiring: shield pin -> ESP32 ----
#define SHIELD_PIN_DIR_SER    19   // shield D8  (74HC595 data,  AFMotor MOTORDATA)
#define SHIELD_PIN_DIR_CLK    18   // shield D4  (74HC595 clock)
#define SHIELD_PIN_DIR_LATCH  23   // shield D12 (74HC595 latch, AFMotor MOTORLATCH)
#define SHIELD_PIN_DIR_EN     -1   // shield D7  -> tie to GND (or give it a GPIO)
#define SHIELD_PIN_PWM_M1     25   // shield D11
#define SHIELD_PIN_PWM_M2     26   // shield D3
#define SHIELD_PIN_PWM_M3     33   // shield D6
#define SHIELD_PIN_PWM_M4     32   // shield D5
// 74HC595 bit numbers per motor (AFMotor convention): A = fwd, B = rev
#define SHIELD_M1_A 2
#define SHIELD_M1_B 3
#define SHIELD_M2_A 1
#define SHIELD_M2_B 4
#define SHIELD_M3_A 5
#define SHIELD_M3_B 7
#define SHIELD_M4_A 0
#define SHIELD_M4_B 6
// Which shield channel drives what
#define SHIELD_LEFT_MOTOR    1    // M1
#define SHIELD_RIGHT_MOTOR   4    // M4
#define SHIELD_WEAPON_MOTOR  2    // M2 (hammer) — change to 3 if wired to M3
#define SHIELD_PWM_FREQ      5000 // L293D is slow; keep PWM modest

// Driver CH1 — left wheel
#define PIN_LEFT_RPWM    25   // -> CH1 IN1 (forward)
#define PIN_LEFT_LPWM    26   // -> CH1 IN2 (reverse)
#define PIN_LEFT_REN     27   // -> CH1 EN  (if the board has one; else unused)
#define PIN_LEFT_LEN     -1
// Driver CH2 — right wheel
#define PIN_RIGHT_RPWM   32   // -> CH2 IN1 (forward)
#define PIN_RIGHT_LPWM   33   // -> CH2 IN2 (reverse)
#define PIN_RIGHT_REN    14   // -> CH2 EN  (if the board has one; else unused)
#define PIN_RIGHT_LEN    -1

// Legacy L298N mapping (used only if DRIVE_DRIVER == DRIVER_L298N)
#define PIN_LEFT_IN1     25
#define PIN_LEFT_IN2     26
#define PIN_LEFT_ENA     27   // PWM
#define PIN_RIGHT_IN3    32
#define PIN_RIGHT_IN4    33
#define PIN_RIGHT_ENB    14   // PWM

// PWM settings for drive motors
#define DRIVE_PWM_FREQ   20000    // 20 kHz — above audible range
#define DRIVE_PWM_BITS   10       // 0..1023

// ---------------- Weapon (hammer) motor — driver CH3 ----------------
// Same two-PWM-inputs scheme as the wheels.
// Set WEAPON_SINGLE_DIRECTION to 1 if the hammer only needs one direction.
#define WEAPON_SINGLE_DIRECTION  0
#define PIN_WEAPON_RPWM   18   // -> CH3 IN1 (forward / strike)
#define PIN_WEAPON_LPWM   19   // -> CH3 IN2 (reverse / retract)
#define PIN_WEAPON_REN    23   // -> CH3 EN  (if the board has one; else unused)
#define PIN_WEAPON_LEN    -1
#define WEAPON_PWM_FREQ   20000
#define WEAPON_PWM_BITS   10

// ---------------- Battery sensing ----------------
// Voltage divider -> ADC pin. R_TOP between VBat and pin, R_BOT pin to GND.
// Set PIN_BATT_ADC to -1 to disable (telemetry then reports 0 mV).
#define PIN_BATT_ADC      34          // ADC1_CH6
#define BATT_R_TOP_OHM    10000.0f
#define BATT_R_BOT_OHM    3300.0f     // gives ~4.03x divider; safe to ~16.6 V
#define BATT_SAMPLES      8

// ---------------- Control shaping ----------------
#define DRIVE_DEADBAND    40          // |value| below this counts as 0
#define SLEW_LIMIT        0           // 0 = off; e.g. 25 = max change per packet

// ---------------- Status LED ----------------
#define PIN_LED_STATUS    2           // onboard LED: solid = linked, blink = failsafe
