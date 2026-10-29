import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'joystick.dart';
import 'link.dart';
import 'protocol.dart';

class DrivePage extends StatefulWidget {
  const DrivePage({super.key, required this.link});

  final RobotLink link;

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  static const _channel = MethodChannel('combact/link');

  bool _armed = false;
  bool _invert = false;
  bool _lowSpeed = false;
  bool _fire = false;
  int _hammer = 0; // -1000..1000 proportional speed
  TelemetryPacket? _tele;
  StreamSubscription<TelemetryPacket>? _sub;

  @override
  void initState() {
    super.initState();
    _bindWifi();
    widget.link.start().then((_) => widget.link.beginSending());
    _sub = widget.link.telemetryStream.listen((t) {
      setState(() => _tele = t);
    });
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
    _channel.invokeMethod('unbind').catchError((_) {});
    super.dispose();
  }

  void _push() {
    final c = widget.link.command;
    c.flags = (_armed ? flagArmed : 0) |
        (_invert ? flagInvert : 0) |
        (_lowSpeed ? flagLowSpeed : 0);
    c.ch[chHammer] = _fire ? 1000 : _hammer;
  }

  void _onDrive(double x, double y) {
    final c = widget.link.command;
    c.ch[chSteer] = (x * 1000).round();
    c.ch[chThrottle] = (y * 1000).round();
    _push();
  }

  void _setArmed(bool v) {
    setState(() => _armed = v);
    _push();
  }

  void _setHammer(int v) {
    _hammer = v.clamp(-1000, 1000);
    _push();
  }

  void _setFire(bool v) {
    setState(() => _fire = v);
    _push();
  }

  @override
  Widget build(BuildContext context) {
    final tele = _tele;
    final linked = tele?.linked ?? false;
    final failsafe = tele?.failsafe ?? true;
    return Scaffold(
      backgroundColor: const Color(0xFF10161A),
      body: SafeArea(
        child: Column(
          children: [
            _statusBar(linked, failsafe),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _drivePad(),
                  _weaponPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(bool linked, bool failsafe) {
    final tele = _tele;
    final Color c = tele == null
        ? Colors.grey
        : (failsafe ? Colors.orange : (linked ? Colors.green : Colors.red));
    final String state = tele == null
        ? 'NO TELEMETRY'
        : (failsafe ? 'FAILSAFE' : 'LINKED');
    return Container(
      color: const Color(0xFF1B2329),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.circle, color: c, size: 14),
          const SizedBox(width: 8),
          Text(state, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
          const Spacer(),
          _teleItem(Icons.battery_full,
              '${(tele?.batteryMv ?? 0) / 1000.0}V'),
          _teleItem(Icons.signal_cellular_alt, '${tele?.rssiDbm ?? 0}dBm'),
          _teleItem(Icons.speed, '${tele?.rxRateHz.toStringAsFixed(0) ?? 0}Hz'),
          _teleItem(Icons.error_outline, 'lost ${tele?.lost ?? 0}'),
        ],
      ),
    );
  }

  Widget _teleItem(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ]),
      );

  Widget _drivePad() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('DRIVE', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Joystick(size: 220, onChanged: _onDrive),
          const SizedBox(height: 12),
          Row(children: [
            _toggle('INVERT', _invert, (v) {
              setState(() => _invert = v);
              _push();
            }),
            const SizedBox(width: 12),
            _toggle('LOW', _lowSpeed, (v) {
              setState(() => _lowSpeed = v);
              _push();
            }),
          ]),
        ],
      );

  Widget _weaponPanel() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 1.6,
            child: Switch(
              value: _armed,
              onChanged: _setArmed,
              activeThumbColor: Colors.red,
              inactiveThumbColor: Colors.grey,
            ),
          ),
          Text(
            _armed ? 'ARMED' : 'DISARMED',
            style: TextStyle(
              color: _armed ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _hammer.toDouble(),
                min: -1000,
                max: 1000,
                onChanged: _armed ? (v) => _setHammer(v.round()) : null,
                onChangeEnd: (_) => _setHammer(0),
              ),
            ),
          ),
          const Text('HAMMER', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          GestureDetector(
            onTapDown: _armed ? (_) => _setFire(true) : null,
            onTapUp: (_) => _setFire(false),
            onTapCancel: () => _setFire(false),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _armed
                    ? (_fire ? Colors.redAccent : Colors.red.shade800)
                    : Colors.grey.shade800,
                border: Border.all(color: Colors.white24, width: 3),
              ),
              child: const Center(
                child: Text('FIRE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
            ),
          ),
        ],
      );

  Widget _toggle(String label, bool v, ValueChanged<bool> onChanged) => Column(
        children: [
          Switch(value: v, onChanged: onChanged),
          Text(label, style: const TextStyle(color: Colors.white54)),
        ],
      );
}
