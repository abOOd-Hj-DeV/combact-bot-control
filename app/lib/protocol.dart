/// Wire protocol shared with the ESP32 firmware — keep in sync with
/// firmware/src/protocol.h. All fields little-endian.
library;

import 'dart:typed_data';

const int kProtocolVersion = 1;
const int kChannelCount = 5;

/// Channel indices.
const int chThrottle = 0;
const int chSteer = 1;
const int chHammer = 2;
const int chAux1 = 3;
const int chAux2 = 4;

/// RC flag bits.
const int flagArmed = 1 << 0;
const int flagInvert = 1 << 1;
const int flagLowSpeed = 1 << 2;

/// Telemetry flag bits.
const int teleLinked = 1 << 0;
const int teleArmed = 1 << 1;
const int teleFailsafe = 1 << 2;

const int kRcPacketSize = 18;
const int kTelemetryPacketSize = 16;

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF).
int crc16(Uint8List data, [int? len]) {
  final n = len ?? data.length;
  var crc = 0xFFFF;
  for (var i = 0; i < n; i++) {
    crc ^= data[i] << 8;
    for (var b = 0; b < 8; b++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}

/// Phone -> robot control packet (18 bytes).
class RcPacket {
  int flags = 0;
  int seq = 0;
  final List<int> ch = List<int>.filled(kChannelCount, 0);

  Uint8List encode() {
    final b = Uint8List(kRcPacketSize);
    b[0] = 0x52; // 'R'
    b[1] = 0x43; // 'C'
    b[2] = kProtocolVersion;
    b[3] = flags & 0xFF;
    b[4] = seq & 0xFF;
    b[5] = (seq >> 8) & 0xFF;
    for (var i = 0; i < kChannelCount; i++) {
      final v = ch[i].clamp(-1000, 1000) & 0xFFFF;
      b[6 + i * 2] = v & 0xFF;
      b[6 + i * 2 + 1] = (v >> 8) & 0xFF;
    }
    final crc = crc16(b, 16);
    b[16] = crc & 0xFF;
    b[17] = (crc >> 8) & 0xFF;
    return b;
  }
}

/// Robot -> phone telemetry packet (16 bytes).
class TelemetryPacket {
  int flags = 0;
  int lastSeq = 0;
  int batteryMv = 0;
  int rssiDbm = 0;
  double rxRateHz = 0;
  int lost = 0;

  bool get linked => (flags & teleLinked) != 0;
  bool get armed => (flags & teleArmed) != 0;
  bool get failsafe => (flags & teleFailsafe) != 0;

  static TelemetryPacket? decode(Uint8List d) {
    if (d.length != kTelemetryPacketSize) return null;
    if (d[0] != 0x54 || d[1] != 0x4C || d[2] != kProtocolVersion) return null;
    final crc = d[14] | (d[15] << 8);
    if (crc16(d, 14) != crc) return null;
    final t = TelemetryPacket();
    t.flags = d[3];
    t.lastSeq = d[4] | (d[5] << 8);
    t.batteryMv = d[6] | (d[7] << 8);
    t.rssiDbm = d[8] > 127 ? d[8] - 256 : d[8];
    t.rxRateHz = (d[10] | (d[11] << 8)) / 10.0;
    t.lost = d[12] | (d[13] << 8);
    return t;
  }
}
