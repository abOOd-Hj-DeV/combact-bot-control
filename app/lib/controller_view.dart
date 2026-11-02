import 'package:flutter/material.dart';

import 'controls.dart';
import 'joystick.dart';
import 'protocol.dart';
import 'theme.dart';

/// Immutable UI state the controller screen renders.
class ControllerState {
  const ControllerState({
    this.telemetry,
    this.telemetryStale = true,
    this.armed = false,
    this.invert = false,
    this.lowSpeed = false,
    this.fire = false,
    this.hammer = 0,
  });

  final TelemetryPacket? telemetry;
  final bool telemetryStale;
  final bool armed;
  final bool invert;
  final bool lowSpeed;
  final bool fire;
  final double hammer; // -1..1
}

/// Pure layout for the drive screen: left thumb = floating joystick,
/// right thumb = hammer lever + FIRE, ARM and mode chips on top.
/// Fully responsive — every size derives from the available box.
class ControllerView extends StatelessWidget {
  const ControllerView({
    super.key,
    required this.state,
    required this.onDrive,
    required this.onArmed,
    required this.onHammer,
    required this.onFire,
    required this.onInvert,
    required this.onLowSpeed,
  });

  final ControllerState state;
  final void Function(double x, double y) onDrive;
  final ValueChanged<bool> onArmed;
  final ValueChanged<double> onHammer;
  final ValueChanged<bool> onFire;
  final ValueChanged<bool> onInvert;
  final ValueChanged<bool> onLowSpeed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CombatColors.bg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final barH = (c.maxHeight * 0.13).clamp(36.0, 52.0);
          return Column(
            children: [
              SizedBox(height: barH, child: _StatusBar(state: state)),
              const Divider(height: 1, color: CombatColors.outline),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: JoystickZone(onChanged: onDrive),
                    ),
                    const VerticalDivider(width: 1, color: CombatColors.outline),
                    Expanded(flex: 9, child: _WeaponPanel(view: this)),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});
  final ControllerState state;

  @override
  Widget build(BuildContext context) {
    final t = state.telemetry;
    final noLink = t == null || state.telemetryStale;
    final Color c = noLink
        ? CombatColors.textDim
        : (t.failsafe
            ? CombatColors.warn
            : (t.linked ? CombatColors.ok : CombatColors.danger));
    final String label =
        noLink ? 'NO LINK' : (t.failsafe ? 'FAILSAFE' : 'LINKED');
    final String hint = noLink ? 'join WiFi COMBACT-BOT' : '';

    return Container(
      color: CombatColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 8)
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.5)),
          if (hint.isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(hint,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: CombatColors.textDim, fontSize: 12)),
            ),
          ],
          const Spacer(),
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  _Stat(Icons.battery_std,
                      noLink ? '--' : '${(t.batteryMv / 1000).toStringAsFixed(1)}V'),
                  _Stat(Icons.network_wifi, noLink ? '--' : '${t.rssiDbm}dBm'),
                  _Stat(Icons.speed,
                      noLink ? '--' : '${t.rxRateHz.toStringAsFixed(0)}Hz'),
                  _Stat(Icons.report_problem_outlined,
                      noLink ? '--' : 'lost ${t.lost}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Row(children: [
          Icon(icon, size: 15, color: CombatColors.textDim),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: CombatColors.text,
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      );
}

class _WeaponPanel extends StatelessWidget {
  const _WeaponPanel({required this.view});
  final ControllerView view;

  @override
  Widget build(BuildContext context) {
    final s = view.state;
    return LayoutBuilder(builder: (context, c) {
      final pad = (c.maxHeight * 0.04).clamp(6.0, 14.0);
      final armH = (c.maxHeight * 0.2).clamp(44.0, 64.0);
      final fire = (c.maxHeight * 0.42).clamp(80.0, 160.0);
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          children: [
            ArmButton(armed: s.armed, onChanged: view.onArmed, height: armH),
            SizedBox(height: pad),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: HammerLever(
                            enabled: s.armed,
                            value: s.hammer,
                            onChanged: view.onHammer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('HAMMER',
                            style: TextStyle(
                                color: CombatColors.textDim,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: FireButton(
                            enabled: s.armed,
                            pressed: s.fire,
                            onPressed: view.onFire,
                            size: fire,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ToggleChip(
                                label: 'INVERT',
                                icon: Icons.flip,
                                value: s.invert,
                                onChanged: view.onInvert,
                              ),
                              const SizedBox(width: 8),
                              ToggleChip(
                                label: 'LOW',
                                icon: Icons.slow_motion_video,
                                value: s.lowSpeed,
                                onChanged: view.onLowSpeed,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
