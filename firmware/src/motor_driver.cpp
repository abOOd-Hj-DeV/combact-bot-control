#ifdef ARDUINO
#include "motor_driver.h"
#include <esp32-hal-ledc.h>

void PwmOut::attach(uint8_t pin, uint8_t channel, uint32_t freq, uint8_t bits) {
    pin_ = pin;
    channel_ = channel;
    maxDuty_ = (1u << bits) - 1u;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    ledcAttachChannel(pin_, freq, bits, channel_);
#else
    ledcSetup(channel_, freq, bits);
    ledcAttachPin(pin_, channel_);
#endif
    write(0);
}

void PwmOut::write(uint32_t duty) {
    if (duty > maxDuty_) duty = maxDuty_;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    ledcWrite(pin_, duty);
#else
    ledcWrite(channel_, duty);
#endif
}

// ---------------- L298N ----------------

void L298Driver::begin() {
    pinMode(in1_, OUTPUT);
    pinMode(in2_, OUTPUT);
    digitalWrite(in1_, LOW);
    digitalWrite(in2_, LOW);
    pwm_.attach(ena_, ch_, freq_, bits_);
}

void L298Driver::setSpeed(int16_t v) {
    if (v > 0) {
        digitalWrite(in1_, HIGH);
        digitalWrite(in2_, LOW);
    } else if (v < 0) {
        digitalWrite(in1_, LOW);
        digitalWrite(in2_, HIGH);
        v = (int16_t)-v;
    } else {
        digitalWrite(in1_, LOW);
        digitalWrite(in2_, LOW);
    }
    pwm_.write((uint32_t)v * pwm_.maxDuty() / 1000u);
}

void L298Driver::stop() {
    digitalWrite(in1_, LOW);
    digitalWrite(in2_, LOW);
    pwm_.write(0);
}

// ---------------- BTS7960 ----------------

void BTS7960Driver::begin() {
    if (ren_ != 0xFF) { pinMode(ren_, OUTPUT); digitalWrite(ren_, HIGH); }
    if (len_ != 0xFF) { pinMode(len_, OUTPUT); digitalWrite(len_, HIGH); }
    pwmR_.attach(rpwm_, chR_, freq_, bits_);
    pwmL_.attach(lpwm_, chL_, freq_, bits_);
}

void BTS7960Driver::setSpeed(int16_t v) {
    if (v >= 0) {
        pwmR_.write((uint32_t)v * pwmR_.maxDuty() / 1000u);
        pwmL_.write(0);
    } else {
        pwmR_.write(0);
        pwmL_.write((uint32_t)(-(int32_t)v) * pwmL_.maxDuty() / 1000u);
    }
}

void BTS7960Driver::stop() {
    pwmR_.write(0);
    pwmL_.write(0);
}


// ---------------- L293D shield (74HC595) ----------------

void ShieldRegister::begin() {
    pinMode(data_, OUTPUT);
    pinMode(clk_, OUTPUT);
    pinMode(latch_, OUTPUT);
    if (en_ != 0xFF) { pinMode(en_, OUTPUT); digitalWrite(en_, LOW); }
    state_ = 0;
    flush();
}

void ShieldRegister::setBits(uint8_t bitA, uint8_t bitB, bool a, bool b) {
    uint8_t s = state_;
    if (a) s |= (1u << bitA); else s &= ~(1u << bitA);
    if (b) s |= (1u << bitB); else s &= ~(1u << bitB);
    if (s == state_) return;
    state_ = s;
    flush();
}

void ShieldRegister::clear() {
    state_ = 0;
    flush();
}

void ShieldRegister::flush() {
    digitalWrite(latch_, LOW);
    shiftOut(data_, clk_, MSBFIRST, state_);
    digitalWrite(latch_, HIGH);
}

void ShieldMotor::begin() {
    reg_.setBits(bitA_, bitB_, false, false);
    pwm_.attach(pwmPin_, ch_, freq_, bits_);
}

void ShieldMotor::setSpeed(int16_t v) {
    if (v > 0) {
        reg_.setBits(bitA_, bitB_, true, false);
    } else if (v < 0) {
        reg_.setBits(bitA_, bitB_, false, true);
        v = (int16_t)-v;
    } else {
        reg_.setBits(bitA_, bitB_, false, false);
    }
    pwm_.write((uint32_t)v * pwm_.maxDuty() / 1000u);
}

void ShieldMotor::stop() {
    pwm_.write(0);
    reg_.setBits(bitA_, bitB_, false, false);
}

#endif // ARDUINO

// ---------------- UART bridge ----------------

void UartBridge::begin() {
    port_.begin(baud_, SERIAL_8N1, rx_, tx_);
    dirty_ = true;
    send();
}

void UartBridge::set(uint8_t ch, int16_t v) {
    if (ch > 2 || v_[ch] == v) return;
    v_[ch] = v;
    dirty_ = true;
}

void UartBridge::tick() {
    if (dirty_ || millis() - last_ >= period_) send();
}

void UartBridge::send() {
    char body[32];
    int n = snprintf(body, sizeof(body), "%d,%d,%d", v_[0], v_[1], v_[2]);
    uint8_t x = 0;
    for (int i = 0; i < n; i++) x ^= (uint8_t)body[i];
    port_.printf("M%s*%02X\n", body, x);
    dirty_ = false;
    last_ = millis();
}
