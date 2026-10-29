import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';

/// UDP control link to the robot.
///
/// Sends the full channel state every [period] so a lost packet is replaced
/// by the next one 20 ms later. Receives 5 Hz telemetry back on the same
/// socket. Failsafe lives on the robot: if packets stop arriving for
/// ~300 ms it stops everything by itself.
class RobotLink {
  RobotLink({this.host = '192.168.4.1', this.port = 4210, this.period = const Duration(milliseconds: 20)});

  final String host;
  final int port;
  final Duration period;

  RawDatagramSocket? _socket;
  Timer? _txTimer;
  int _seq = 0;
  bool _sending = false;

  /// Last telemetry decoded from the robot; null until first packet.
  TelemetryPacket? telemetry;

  /// Stream of telemetry updates for the UI.
  final _telemetryCtrl = StreamController<TelemetryPacket>.broadcast();
  Stream<TelemetryPacket> get telemetryStream => _telemetryCtrl.stream;

  bool get connected => _socket != null;

  Future<void> start() async {
    _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.listen(_onData);
    _txTimer ??= Timer.periodic(period, (_) => _send());
  }

  void _onData(RawSocketEvent e) {
    if (e != RawSocketEvent.read) return;
    final dg = _socket?.receive();
    if (dg == null) return;
    final t = TelemetryPacket.decode(Uint8List.fromList(dg.data));
    if (t != null) {
      telemetry = t;
      _telemetryCtrl.add(t);
    }
  }

  /// Current command written by the UI before each tick.
  RcPacket command = RcPacket();

  void _send() {
    final s = _socket;
    if (s == null || !_sending) return;
    command.seq = _seq = (_seq + 1) & 0xFFFF;
    s.send(command.encode(), InternetAddress(host), port);
  }

  /// Begin streaming. Called by the UI when the drive screen is active.
  void beginSending() => _sending = true;

  /// Stop streaming (all zeros packet is sent one last time so the
  /// robot sees a clean stop before its failsafe trips).
  Future<void> stopSending() async {
    _sending = false;
    command = RcPacket();
    _sending = true; // send the zeroed command once, then stop
    _send();
    _sending = false;
  }

  Future<void> stop() async {
    await stopSending();
    _txTimer?.cancel();
    _txTimer = null;
    _socket?.close();
    _socket = null;
  }
}
