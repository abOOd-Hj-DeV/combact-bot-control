#pragma once

// Pure-C++ failsafe timer — host-testable, no Arduino deps.

#include <stdint.h>

class Failsafe {
public:
    explicit Failsafe(uint32_t timeoutMs) : timeoutMs_(timeoutMs) {}

    // Call whenever a fresh valid packet arrives.
    void onValidPacket(uint32_t nowMs) {
        lastOkMs_ = nowMs;
        havePacket_ = true;
    }

    // True while the link is considered dead (never linked, or timed out).
    bool active(uint32_t nowMs) const {
        return !havePacket_ || (nowMs - lastOkMs_) > timeoutMs_;
    }

    void reset() { havePacket_ = false; lastOkMs_ = 0; }

    uint32_t timeout() const { return timeoutMs_; }

private:
    uint32_t timeoutMs_;
    uint32_t lastOkMs_ = 0;
    bool     havePacket_ = false;
};
