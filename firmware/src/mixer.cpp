#include "mixer.h"

static int16_t applyDeadband(int16_t v, int16_t db) {
    if (v > -db && v < db) return 0;
    return v;
}

DriveOutput mixDifferential(int16_t throttle, int16_t steer,
                            bool lowSpeed, bool invert,
                            int16_t deadband) {
    throttle = applyDeadband(clamp1000(throttle), deadband);
    steer    = applyDeadband(clamp1000(steer), deadband);

    if (invert) {                      // robot flipped: swap forwards
        throttle = (int16_t)-throttle;
        steer    = (int16_t)-steer;
    }

    int32_t left  = (int32_t)throttle + steer;
    int32_t right = (int32_t)throttle - steer;

    // Proportional rescale if the mix overflows — keeps steering feel.
    int32_t peak = 1000;
    if (left  >  peak) peak = left;
    if (left  < -peak) peak = -left;
    if (right >  peak) peak = right;
    if (right < -peak) peak = -right;
    if (peak > 1000) {
        left  = left  * 1000 / peak;
        right = right * 1000 / peak;
    }

    if (lowSpeed) {
        left  = left  * 400 / 1000;
        right = right * 400 / 1000;
    }

    DriveOutput out;
    out.left  = (int16_t)left;
    out.right = (int16_t)right;
    return out;
}
