#pragma once

// Pure-C++ drive mixer — host-testable, no Arduino deps.

#include <stdint.h>

struct DriveOutput {
    int16_t left;    // -1000..1000
    int16_t right;   // -1000..1000
};

// Arcade mix: throttle + steering -> left/right wheel speeds.
// `lowSpeed` scales output to ~40% for precision driving.
// `invert` flips the robot's sense of forward (upside-down driving).
DriveOutput mixDifferential(int16_t throttle, int16_t steer,
                            bool lowSpeed, bool invert,
                            int16_t deadband);

inline int16_t clamp1000(int32_t v) {
    if (v > 1000) return 1000;
    if (v < -1000) return -1000;
    return (int16_t)v;
}
