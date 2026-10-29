#pragma once

// Arduino-side motor drivers. Everything above this layer is pure C++.

#ifdef ARDUINO
#include <Arduino.h>
#include <stdint.h>

// Small wrapper hiding the ledc API difference between
// Arduino-ESP32 2.x (ledcSetup/ledcAttachPin) and 3.x (ledcAttachChannel).
class PwmOut {
public:
    void attach(uint8_t pin, uint8_t channel, uint32_t freq, uint8_t bits);
    void write(uint32_t duty);
    uint32_t maxDuty() const { return maxDuty_; }
private:
    uint8_t  pin_ = 0, channel_ = 0;
    uint32_t maxDuty_ = 1023;
};

class IMotorDriver {
public:
    virtual ~IMotorDriver() {}
    virtual void begin() = 0;
    virtual void setSpeed(int16_t v) = 0;   // -1000..1000
    virtual void stop() = 0;
};

// L298N / TB6612-style: two direction pins + one PWM pin.
class L298Driver : public IMotorDriver {
public:
    L298Driver(uint8_t in1, uint8_t in2, uint8_t ena,
               uint8_t pwmChannel, uint32_t freq, uint8_t bits)
        : in1_(in1), in2_(in2), ena_(ena), ch_(pwmChannel),
          freq_(freq), bits_(bits) {}
    void begin() override;
    void setSpeed(int16_t v) override;
    void stop() override;
private:
    uint8_t in1_, in2_, ena_, ch_;
    uint32_t freq_;
    uint8_t  bits_;
    PwmOut   pwm_;
};

// BTS7960 / IBT-2 style: one PWM pin per direction (+ optional enable pins).
class BTS7960Driver : public IMotorDriver {
public:
    BTS7960Driver(uint8_t rpwm, uint8_t lpwm, uint8_t ren, uint8_t len,
                  uint8_t chR, uint8_t chL, uint32_t freq, uint8_t bits)
        : rpwm_(rpwm), lpwm_(lpwm), ren_(ren), len_(len),
          chR_(chR), chL_(chL), freq_(freq), bits_(bits) {}
    void begin() override;
    void setSpeed(int16_t v) override;
    void stop() override;
private:
    uint8_t rpwm_, lpwm_, ren_, len_, chR_, chL_;
    uint32_t freq_;
    uint8_t  bits_;
    PwmOut   pwmR_, pwmL_;
};

#endif // ARDUINO
