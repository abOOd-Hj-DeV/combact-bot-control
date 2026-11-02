import 'package:flutter/material.dart';

import 'theme.dart';

/// Vertical spring-to-centre lever for proportional hammer control.
/// Reports -1.0..1.0 (up = positive) and snaps back to 0 on release.
class HammerLever extends StatefulWidget {
  const HammerLever({
    super.key,
    required this.enabled,
    required this.onChanged,
    this.value = 0,
  });

  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<HammerLever> createState() => _HammerLeverState();
}

class _HammerLeverState extends State<HammerLever> {
  int? _pointer;

  void _set(Offset local, Size size) {
    final half = size.height / 2;
    final v = ((half - local.dy) / half).clamp(-1.0, 1.0);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final color = enabled ? CombatColors.danger : CombatColors.outline;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final trackW = (size.width * 0.28).clamp(14.0, 28.0);
      final handleH = (size.height * 0.14).clamp(28.0, 56.0);
      final travel = size.height - handleH;
      final y = (size.height / 2) - widget.value * (travel / 2);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled
            ? (e) {
                if (_pointer != null) return;
                _pointer = e.pointer;
                _set(e.localPosition, size);
              }
            : null,
        onPointerMove: (e) {
          if (e.pointer == _pointer) _set(e.localPosition, size);
        },
        onPointerUp: (e) {
          if (e.pointer == _pointer) {
            _pointer = null;
            widget.onChanged(0);
          }
        },
        onPointerCancel: (e) {
          if (e.pointer == _pointer) {
            _pointer = null;
            widget.onChanged(0);
          }
        },
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: handleH / 2,
              bottom: handleH / 2,
              child: Container(
                width: trackW,
                decoration: BoxDecoration(
                  color: CombatColors.panelHi,
                  borderRadius: BorderRadius.circular(trackW),
                  border: Border.all(color: CombatColors.outline),
                ),
              ),
            ),
            Positioned(
              top: size.height / 2 - 1,
              child: Container(
                  width: trackW + 16, height: 2, color: CombatColors.outline),
            ),
            Positioned(
              top: 0,
              child: Icon(Icons.keyboard_double_arrow_up,
                  color: color.withValues(alpha: 0.7), size: 18),
            ),
            Positioned(
              bottom: 0,
              child: Icon(Icons.keyboard_double_arrow_down,
                  color: color.withValues(alpha: 0.7), size: 18),
            ),
            Positioned(
              top: y - handleH / 2,
              child: Container(
                width: (size.width * 0.8).clamp(44.0, 72.0),
                height: handleH,
                decoration: BoxDecoration(
                  color: enabled ? CombatColors.danger : CombatColors.panelHi,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: enabled ? Colors.white54 : CombatColors.outline,
                      width: 1.5),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                              color: CombatColors.danger.withValues(alpha: 0.4),
                              blurRadius: 12)
                        ]
                      : null,
                ),
                child: Icon(Icons.drag_handle,
                    color: enabled ? Colors.white : CombatColors.textDim),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Hold-to-arm, tap-to-disarm safety switch.
class ArmButton extends StatelessWidget {
  const ArmButton({
    super.key,
    required this.armed,
    required this.onChanged,
    this.height = 56,
  });

  final bool armed;
  final ValueChanged<bool> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = armed ? CombatColors.danger : CombatColors.panelHi;
    return GestureDetector(
      onLongPress: armed ? null : () => onChanged(true),
      onTap: armed ? () => onChanged(false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: armed ? Colors.white70 : CombatColors.outline, width: 2),
          boxShadow: armed
              ? [
                  BoxShadow(
                      color: CombatColors.danger.withValues(alpha: 0.5),
                      blurRadius: 16)
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(armed ? Icons.lock_open : Icons.lock,
                color: armed ? Colors.white : CombatColors.textDim,
                size: height * 0.4),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(armed ? 'ARMED' : 'DISARMED',
                    style: TextStyle(
                        color: armed ? Colors.white : CombatColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: height * 0.3,
                        letterSpacing: 1.5)),
                Text(armed ? 'tap to disarm' : 'hold to arm',
                    style: TextStyle(
                        color: armed ? Colors.white70 : CombatColors.textDim,
                        fontSize: height * 0.19)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Big hold-to-fire button: full hammer power while pressed.
class FireButton extends StatelessWidget {
  const FireButton({
    super.key,
    required this.enabled,
    required this.pressed,
    required this.onPressed,
    this.size = 120,
  });

  final bool enabled;
  final bool pressed;
  final ValueChanged<bool> onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color fill = !enabled
        ? CombatColors.panelHi
        : (pressed ? const Color(0xFFFF6B5E) : CombatColors.danger);
    return Listener(
      onPointerDown: enabled ? (_) => onPressed(true) : null,
      onPointerUp: (_) => onPressed(false),
      onPointerCancel: (_) => onPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(
              color: enabled ? Colors.white70 : CombatColors.outline,
              width: 4),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: CombatColors.danger.withValues(alpha: 0.55),
                      blurRadius: pressed ? 30 : 16,
                      spreadRadius: pressed ? 4 : 0)
                ]
              : null,
        ),
        child: Center(
          child: Text('FIRE',
              style: TextStyle(
                  color: enabled ? Colors.white : CombatColors.textDim,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.22,
                  letterSpacing: 2)),
        ),
      ),
    );
  }
}

/// Compact toggle chip (INVERT / LOW).
class ToggleChip extends StatelessWidget {
  const ToggleChip({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? CombatColors.accent : CombatColors.textDim;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? CombatColors.accent.withValues(alpha: 0.15)
              : CombatColors.panelHi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value ? color : CombatColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
