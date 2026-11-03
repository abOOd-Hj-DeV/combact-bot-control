import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller_view.dart';
import 'link.dart';
import 'protocol.dart';

/// Owns link state and command flags; rendering is delegated to
/// [ControllerView].
class DrivePage extends StatefulWidget {
  const DrivePage({super.key, required this.link});

  final RobotLink link;

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  static const _channel = MethodChannel('combact/link');
  static const _staleAfter = Duration(milliseconds: 1000);

  bool _armed = false;
  bool _invert = false;
  bool _lowSpeed = false;
  bool _fire = false;
  double _hammer = 0; // -1..1
  TelemetryPacket? _tele;
  DateTime? _teleAt;
  StreamSubscription<TelemetryPacket>? _sub;
  Timer? _staleTimer;

  @override
  void initState() {
    super.initState();
    // Bind to the robot's WiFi *before* opening the socket: Android keeps
    // mobile data as the default network, and bindProcessToNetwork only
    // affects sockets created after it.
    _bindWifi()
        .then((_) => widget.link.start())
        .then((_) => widget.link.beginSending());
    _sub = widget.link.telemetryStream.listen((t) {
      setState(() {
        _tele = t;
        _teleAt = DateTime.now();
      });
    });
    _staleTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_tele != null) setState(() {});
      _maybeRelink();
    });
  }

  static const _relinkAfter = Duration(milliseconds: 2500);
  DateTime _lastRelink = DateTime.now();
  bool _relinking = false;

  /// No telemetry for a while: the phone probably dropped and rejoined the
  /// robot's Wi-Fi, which leaves the UDP socket bound to a dead network.
  /// Re-bind the process to Wi-Fi and open a fresh socket, every 2.5 s.
  Future<void> _maybeRelink() async {
    if (_relinking || !_stale) return;
    if (DateTime.now().difference(_lastRelink) < _relinkAfter) return;
    _relinking = true;
    _lastRelink = DateTime.now();
    try {
      await _bindWifi();
      await widget.link.reconnect();
    } catch (_) {
      // Socket bind can fail while the interface is still coming up; the
      // next tick retries.
    } finally {
      _relinking = false;
    }
  }

  /// Route all app traffic over WiFi even though the robot's AP has no
  /// internet — Android would otherwise send via mobile data.
  Future<void> _bindWifi() async {
    try {
      await _channel.invokeMethod('bindWifi');
    } catch (_) {
      // MethodChannel missing (older shell) — the UI warns the user instead.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _staleTimer?.cancel();
    _channel.invokeMethod('unbind').catchError((_) {});
    super.dispose();
  }

  bool get _stale {
    final at = _teleAt;
    return at == null || DateTime.now().difference(at) > _staleAfter;
  }

  void _push() {
    final c = widget.link.command;
    c.flags = (_armed ? flagArmed : 0) |
        (_invert ? flagInvert : 0) |
        (_lowSpeed ? flagLowSpeed : 0);
    c.ch[chHammer] = _fire ? 1000 : (_hammer * 1000).round();
  }

  void _onDrive(double x, double y) {
    final c = widget.link.command;
    c.ch[chSteer] = (x * 1000).round();
    c.ch[chThrottle] = (y * 1000).round();
    _push();
  }

  void _setArmed(bool v) {
    setState(() {
      _armed = v;
      if (!v) {
        _fire = false;
        _hammer = 0;
      }
    });
    _push();
  }

  void _setHammer(double v) {
    setState(() => _hammer = v.clamp(-1.0, 1.0));
    _push();
  }

  void _setFire(bool v) {
    if (v && !_armed) return;
    setState(() => _fire = v);
    _push();
  }

  @override
  Widget build(BuildContext context) {
    return ControllerView(
      state: ControllerState(
        telemetry: _tele,
        telemetryStale: _stale,
        armed: _armed,
        invert: _invert,
        lowSpeed: _lowSpeed,
        fire: _fire,
        hammer: _hammer,
      ),
      onDrive: _onDrive,
      onArmed: _setArmed,
      onHammer: _setHammer,
      onFire: _setFire,
      onInvert: (v) {
        setState(() => _invert = v);
        _push();
      },
      onLowSpeed: (v) {
        setState(() => _lowSpeed = v);
        _push();
      },
    );
  }
}
