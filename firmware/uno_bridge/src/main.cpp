#include <Arduino.h>
#include <SoftwareSerial.h>
// Combact-bot motor bridge: Arduino UNO + L293D Motor Shield v1.
// The ESP32 (Wi-Fi brain) sends one ASCII frame per 20 ms into UNO pin 2
// (SoftwareSerial RX, 57600 baud; pin 0 is hidden under the shield):
//     M<left>,<right>,<weapon>*<xx>\n     values -1000..1000, xx = XOR of
//                                         every byte between 'M' and '*', hex
// If no valid frame arrives for FAILSAFE_MS every motor is stopped.
// Shield pins are the stock AFMotor ones: 74HC595 latch 12 / clk 4 / data 8 /
// enable 7, PWM M1=11 M2=3 M3=6 M4=5.  Left wheel = M1, right = M4, hammer = M2.

const int LATCH = 12, CLK = 4, SER = 8, EN = 7;
const int PWM_PIN[5] = {0, 11, 3, 6, 5};          // index by motor number 1..4
const uint8_t BIT_A[5] = {0, 2, 1, 5, 0};         // AFMotor MOTORn_A bits
const uint8_t BIT_B[5] = {0, 3, 4, 7, 6};         // AFMotor MOTORn_B bits
const int LEFT = 1, RIGHT = 4, WEAPON = 2;
const unsigned long FAILSAFE_MS = 300;
const int LINK_RX = 2, LINK_TX = A5;              // A5 unused: TX never driven
const long LINK_BAUD = 57600;

// Hammer = cam driven by WEAPON motor. One FIRE press runs the cam one full
// turn (strike + re-cock) and stops cocked. A very short tap only nudges the
// cam so the rest position can be aligned by hand. No sensor: times below
// are calibrated by trial for this robot's cam + battery.
const unsigned long HAMMER_CYCLE_MS = 1200;  // one full cam revolution
const unsigned long HAMMER_NUDGE_MS = 60;    // tiny step for manual alignment
const unsigned long HAMMER_TAP_MS   = 200;   // press shorter than this = nudge
const int HAMMER_POWER = 1000;               // cam always runs forward, full power

enum HammerState { H_IDLE, H_PRESSED, H_RUNNING };
HammerState hState = H_IDLE;
unsigned long hPressAt = 0, hRunUntil = 0;
bool hPrevPressed = false;
SoftwareSerial link(LINK_RX, LINK_TX);

uint8_t regState = 0;
char line[40];
uint8_t lineLen = 0;
unsigned long lastFrame = 0;
bool linked = false;

void flushReg() {
  digitalWrite(LATCH, LOW);
  shiftOut(SER, CLK, MSBFIRST, regState);
  digitalWrite(LATCH, HIGH);
}

void setMotor(int m, int v) {
  if (v > 1000) v = 1000;
  if (v < -1000) v = -1000;
  uint8_t s = regState & ~((1u << BIT_A[m]) | (1u << BIT_B[m]));
  if (v > 0) s |= (1u << BIT_A[m]);
  if (v < 0) { s |= (1u << BIT_B[m]); v = -v; }
  if (s != regState) { regState = s; flushReg(); }
  analogWrite(PWM_PIN[m], (long)v * 255 / 1000);
}

void stopAll() {
  for (int m = 1; m <= 4; m++) analogWrite(PWM_PIN[m], 0);
  regState = 0;
  flushReg();
}

void hammerRun(unsigned long ms) {
  hState = H_RUNNING;
  hRunUntil = millis() + ms;
  setMotor(WEAPON, HAMMER_POWER);
}

void hammerInput(bool pressed) {
  unsigned long now = millis();
  bool rising = pressed && !hPrevPressed;
  bool falling = !pressed && hPrevPressed;
  hPrevPressed = pressed;
  switch (hState) {
    case H_IDLE:
      if (rising) { hState = H_PRESSED; hPressAt = now; }
      break;
    case H_PRESSED:
      if (falling)                              hammerRun(HAMMER_NUDGE_MS);
      else if (now - hPressAt >= HAMMER_TAP_MS) hammerRun(HAMMER_CYCLE_MS);
      break;
    case H_RUNNING:
      break;                                    // ignore input until the cycle ends
  }
}

void hammerTick() {
  if (hState == H_RUNNING && (long)(millis() - hRunUntil) >= 0) {
    setMotor(WEAPON, 0);
    hState = hPrevPressed ? H_RUNNING : H_IDLE;   // wait for release before re-arming
    if (hPrevPressed) hRunUntil = millis();       // stays RUNNING (motor off) until released
  }
}

bool parseFrame(const char* s) {
  if (s[0] != 'M') return false;
  const char* star = strchr(s, '*');
  if (!star) return false;
  uint8_t x = 0;
  for (const char* p = s + 1; p < star; p++) x ^= (uint8_t)*p;
  if ((uint8_t)strtol(star + 1, nullptr, 16) != x) return false;
  int l, r, w;
  if (sscanf(s + 1, "%d,%d,%d", &l, &r, &w) != 3) return false;
  setMotor(LEFT, l);
  setMotor(RIGHT, r);
  hammerInput(w > 0);
  return true;
}

void setup() {
  Serial.begin(115200);
  link.begin(LINK_BAUD);
  pinMode(LATCH, OUTPUT); pinMode(CLK, OUTPUT); pinMode(SER, OUTPUT);
  pinMode(EN, OUTPUT); digitalWrite(EN, LOW);
  for (int m = 1; m <= 4; m++) pinMode(PWM_PIN[m], OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);
  stopAll();
  Serial.println(F("bridge ready"));
}

void loop() {
  while (link.available()) {
    char c = (char)link.read();
    if (c == '\n' || c == '\r') {
      line[lineLen] = 0;
      if (lineLen && parseFrame(line)) { lastFrame = millis(); linked = true; }
      lineLen = 0;
    } else if (lineLen < sizeof(line) - 1) {
      line[lineLen++] = c;
    } else {
      lineLen = 0;                                  // garbage: resync
    }
  }
  hammerTick();
  if (linked && millis() - lastFrame > FAILSAFE_MS) {
    linked = false;
    stopAll();
    hState = H_IDLE;
    hPrevPressed = false;
  }
  digitalWrite(LED_BUILTIN, linked ? HIGH : ((millis() / 250) & 1));
}
