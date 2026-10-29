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
#define UDP_PORT         4210           // control in + telemetry out on one port

// ---------------- Timing ----------------
// Competition rule: stop everything if the link drops for 5 s.
// We trip much earlier — 300 ms — which is stricter and safer.
// If it feels twitchy on a congested venue, raise it (must stay < 5000).
#define FAILSAFE_TIMEOUT_MS   300
#define TELEMETRY_PERIOD_MS   200       // robot -> phone, 5 Hz
#define WDT_TIMEOUT_S         3

// ---------------- Drive motor driver ----------------
// Pick ONE driver type for the two drive motors.
#define DRIVER_L298N     1   // IN1/IN2 + ENA(PWM) per motor
#define DRIVER_BTS7960   2   // RPWM/LPWM per motor (+EN pins)
#define DRIVE_DRIVER     DRIVER_L298N

// Left motor (L298N mapping)
#define PIN_LEFT_IN1     26
#define PIN_LEFT_IN2     27
#define PIN_LEFT_ENA     25   // PWM
// Right motor (L298N mapping)
#define PIN_RIGHT_IN3    14
#define PIN_RIGHT_IN4    12
#define PIN_RIGHT_ENB    33   // PWM

// BTS7960 mapping (used only if DRIVE_DRIVER == DRIVER_BTS7960)
#define PIN_LEFT_RPWM    25
#define PIN_LEFT_LPWM    26
#define PIN_LEFT_REN     27
#define PIN_LEFT_LEN     14
#define PIN_RIGHT_RPWM   33
#define PIN_RIGHT_LPWM   12
#define PIN_RIGHT_REN    13
#define PIN_RIGHT_LEN    32

// PWM settings for drive motors
#define DRIVE_PWM_FREQ   20000    // 20 kHz — above audible range
#define DRIVE_PWM_BITS   10       // 0..1023

// ---------------- Weapon (hammer) motor ----------------
// Any single-channel H-bridge. RPWM swings one way, LPWM the other.
// Set WEAPON_SINGLE_DIRECTION to 1 if the hammer only needs one direction.
#define WEAPON_SINGLE_DIRECTION  0
#define PIN_WEAPON_RPWM   18
#define PIN_WEAPON_LPWM   19
#define PIN_WEAPON_REN    5    // set to -1 if enable pins are hard-wired high
#define PIN_WEAPON_LEN    17
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
