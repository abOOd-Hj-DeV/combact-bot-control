#pragma once

// ============================================================
//  Wire protocol shared by the ESP32 firmware and the phone app.
//  Pure C++ — no Arduino deps — so the host unit tests can use it.
//  All multi-byte fields are little-endian.
// ============================================================

#include <stdint.h>
#include <stddef.h>

namespace proto {

constexpr uint8_t kVersion = 1;
constexpr int     kChannelCount = 5;

// Channel indices
enum Channel : uint8_t {
    CH_THROTTLE = 0,   // -1000..1000 forward/back
    CH_STEER    = 1,   // -1000..1000 left/right
    CH_HAMMER   = 2,   // -1000..1000 hammer speed (needs ARM flag)
    CH_AUX1     = 3,   // spare analog (e.g. drive power trim)
    CH_AUX2     = 4,   // spare analog
};

// RC packet flag bits
enum RcFlags : uint8_t {
    FLAG_ARMED       = 1 << 0,   // weapon enable — required for hammer output
    FLAG_INVERT      = 1 << 1,   // flip drive if the robot is upside down
    FLAG_LOW_SPEED   = 1 << 2,   // precision mode, scales drive output
};

// Telemetry state bits
enum TeleFlags : uint8_t {
    TELE_LINKED      = 1 << 0,   // receiving valid packets
    TELE_ARMED       = 1 << 1,   // weapon currently armed
    TELE_FAILSAFE    = 1 << 2,   // failsafe active right now
};

// ---------- Downlink: phone -> robot, 18 bytes ----------
struct RcPacket {
    uint8_t  magic0 = 'R';
    uint8_t  magic1 = 'C';
    uint8_t  version = kVersion;
    uint8_t  flags = 0;
    uint16_t seq = 0;
    int16_t  ch[kChannelCount] = {0, 0, 0, 0, 0};
    uint16_t crc = 0;
};
constexpr size_t kRcPacketSize = 18;
static_assert(sizeof(RcPacket) == kRcPacketSize, "RcPacket wire size changed");

// ---------- Uplink: robot -> phone, 16 bytes ----------
struct TelemetryPacket {
    uint8_t  magic0 = 'T';
    uint8_t  magic1 = 'L';
    uint8_t  version = kVersion;
    uint8_t  flags = 0;          // TeleFlags
    uint16_t lastSeq = 0;        // last accepted RC seq
    uint16_t batteryMv = 0;
    int8_t   rssiDbm = 0;        // STA RSSI seen by the AP (of the peer)
    uint8_t  reserved = 0;
    uint16_t rxRateX10 = 0;      // valid packets/sec * 10
    uint16_t lost = 0;           // estimated dropped packets (seq gaps)
    uint16_t crc = 0;
};
constexpr size_t kTelemetryPacketSize = 16;
static_assert(sizeof(TelemetryPacket) == kTelemetryPacketSize,
              "TelemetryPacket wire size changed");

// CRC-16/CCITT-FALSE — poly 0x1021, init 0xFFFF.
uint16_t crc16(const uint8_t* data, size_t len);

// Serialise/deserialise. decode returns false on bad size/magic/crc.
void    encodeRc(RcPacket& p);
bool    decodeRc(const uint8_t* data, size_t len, RcPacket& out);
void    encodeTelemetry(TelemetryPacket& p);
bool    decodeTelemetry(const uint8_t* data, size_t len, TelemetryPacket& out);

// True if seq `s` is newer than `prev`, handling uint16 wraparound.
inline bool seqNewer(uint16_t s, uint16_t prev) {
    return (int16_t)(s - prev) > 0;
}

// Tracks RC stream health on the receiver side.
struct LinkStats {
    bool     havePacket = false;
    uint16_t lastSeq = 0;
    uint16_t lost = 0;

    // Returns true when the packet is the freshest so far and should be applied.
    bool accept(uint16_t seq) {
        if (!havePacket) {
            havePacket = true;
            lastSeq = seq;
            return true;
        }
        if (!seqNewer(seq, lastSeq)) return false;     // stale / replay / dup
        uint16_t gap = (uint16_t)(seq - lastSeq - 1); // packets we skipped
        if (gap < 1000) lost += gap;                  // huge gap = counter reset
        lastSeq = seq;
        return true;
    }
};

} // namespace proto
