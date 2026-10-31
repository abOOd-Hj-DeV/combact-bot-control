import 'dart:typed_data';

import 'package:combact_controller/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crc16 CCITT-FALSE check value', () {
    // Canonical check: "123456789" -> 0x29B1
    expect(crc16(Uint8List.fromList('123456789'.codeUnits)), 0x29B1);
  });

  test('RcPacket encode matches firmware wire format', () {
    final p = RcPacket()
      ..flags = flagArmed | flagInvert
      ..seq = 0x1234
      ..ch[chThrottle] = 500
      ..ch[chSteer] = -750
      ..ch[chHammer] = 1000;
    final b = p.encode();
    expect(b.length, kRcPacketSize);
    expect(b[0], 0x52); // 'R'
    expect(b[1], 0x43); // 'C'
    expect(b[2], 1);
    expect(b[3], flagArmed | flagInvert);
    expect(b[4], 0x34);
    expect(b[5], 0x12);
    expect(b[6] | (b[7] << 8), 500);
    expect(b[8] | (b[9] << 8), (-750) & 0xFFFF);
    // CRC field must validate
    expect(crc16(b, 16), b[16] | (b[17] << 8));
  });

  test('RcPacket clamps out-of-range channels on encode', () {
    final p = RcPacket()..ch[0] = 5000;
    final b = p.encode();
    expect(b[6] | (b[7] << 8), 1000);
  });

  test('TelemetryPacket decodes a valid packet', () {
    final d = Uint8List(kTelemetryPacketSize);
    d[0] = 0x54; d[1] = 0x4C; d[2] = 1;
    d[3] = teleLinked | teleArmed;
    d[4] = 0x34; d[5] = 0x12;
    d[6] = 0x80; d[7] = 0x2E; // 0x2E80 = 11904 mV
    d[8] = (256 - 55) & 0xFF; // -55 dBm
    d[10] = 0xF0; d[11] = 0x01; // 49.6 Hz
    d[12] = 3;
    final crc = crc16(d, 14);
    d[14] = crc & 0xFF; d[15] = crc >> 8;

    final t = TelemetryPacket.decode(d);
    expect(t, isNotNull);
    expect(t!.flags, teleLinked | teleArmed);
    expect(t.linked, isTrue);
    expect(t.armed, isTrue);
    expect(t.failsafe, isFalse);
    expect(t.lastSeq, 0x1234);
    expect(t.batteryMv, 0x2E80);
    expect(t.rssiDbm, -55);
    expect(t.rxRateHz, closeTo(49.6, 0.01));
    expect(t.lost, 3);
  });

  test('TelemetryPacket rejects bad magic and corrupt crc', () {
    final d = Uint8List(kTelemetryPacketSize);
    d[0] = 0x54; d[1] = 0x4C; d[2] = 1;
    final crc = crc16(d, 14);
    d[14] = crc & 0xFF; d[15] = crc >> 8;
    expect(TelemetryPacket.decode(d), isNotNull);

    final bad = Uint8List.fromList(d)..[0] = 0x58;
    expect(TelemetryPacket.decode(bad), isNull);

    final corrupt = Uint8List.fromList(d)..[6] ^= 0xFF;
    expect(TelemetryPacket.decode(corrupt), isNull);

    expect(TelemetryPacket.decode(Uint8List(10)), isNull);
  });
}
