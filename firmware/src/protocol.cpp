#include "protocol.h"
#include <string.h>

namespace proto {

uint16_t crc16(const uint8_t* data, size_t len) {
    uint16_t crc = 0xFFFF;
    for (size_t i = 0; i < len; i++) {
        crc ^= (uint16_t)data[i] << 8;
        for (int b = 0; b < 8; b++) {
            crc = (crc & 0x8000) ? (uint16_t)((crc << 1) ^ 0x1021)
                                 : (uint16_t)(crc << 1);
        }
    }
    return crc;
}

// Little-endian field offsets — serialised manually so wire layout never
// depends on compiler padding.

void encodeRc(RcPacket& p) {
    uint8_t* b = reinterpret_cast<uint8_t*>(&p);
    b[0] = 'R'; b[1] = 'C'; b[2] = kVersion; b[3] = p.flags;
    b[4] = (uint8_t)(p.seq & 0xFF);
    b[5] = (uint8_t)(p.seq >> 8);
    for (int i = 0; i < kChannelCount; i++) {
        uint16_t v = (uint16_t)p.ch[i];
        b[6 + i * 2]     = (uint8_t)(v & 0xFF);
        b[6 + i * 2 + 1] = (uint8_t)(v >> 8);
    }
    p.crc = crc16(b, 16);
    b[16] = (uint8_t)(p.crc & 0xFF);
    b[17] = (uint8_t)(p.crc >> 8);
}

bool decodeRc(const uint8_t* d, size_t len, RcPacket& out) {
    if (len != kRcPacketSize) return false;
    if (d[0] != 'R' || d[1] != 'C' || d[2] != kVersion) return false;
    uint16_t crc = (uint16_t)d[16] | ((uint16_t)d[17] << 8);
    if (crc16(d, 16) != crc) return false;
    out.flags = d[3];
    out.seq   = (uint16_t)d[4] | ((uint16_t)d[5] << 8);
    for (int i = 0; i < kChannelCount; i++) {
        uint16_t v = (uint16_t)d[6 + i * 2] | ((uint16_t)d[6 + i * 2 + 1] << 8);
        int16_t sv = (int16_t)v;
        out.ch[i] = sv < -1000 ? -1000 : (sv > 1000 ? 1000 : sv);  // clamp
    }
    out.crc = crc;
    return true;
}

void encodeTelemetry(TelemetryPacket& p) {
    uint8_t* b = reinterpret_cast<uint8_t*>(&p);
    b[0] = 'T'; b[1] = 'L'; b[2] = kVersion; b[3] = p.flags;
    b[4] = (uint8_t)(p.lastSeq & 0xFF);
    b[5] = (uint8_t)(p.lastSeq >> 8);
    b[6] = (uint8_t)(p.batteryMv & 0xFF);
    b[7] = (uint8_t)(p.batteryMv >> 8);
    b[8] = (uint8_t)p.rssiDbm;
    b[9] = p.reserved;
    b[10] = (uint8_t)(p.rxRateX10 & 0xFF);
    b[11] = (uint8_t)(p.rxRateX10 >> 8);
    b[12] = (uint8_t)(p.lost & 0xFF);
    b[13] = (uint8_t)(p.lost >> 8);
    p.crc = crc16(b, 14);
    b[14] = (uint8_t)(p.crc & 0xFF);
    b[15] = (uint8_t)(p.crc >> 8);
}

bool decodeTelemetry(const uint8_t* d, size_t len, TelemetryPacket& out) {
    if (len != kTelemetryPacketSize) return false;
    if (d[0] != 'T' || d[1] != 'L' || d[2] != kVersion) return false;
    uint16_t crc = (uint16_t)d[14] | ((uint16_t)d[15] << 8);
    if (crc16(d, 14) != crc) return false;
    memcpy(&out, d, kTelemetryPacketSize);
    return true;
}

} // namespace proto
