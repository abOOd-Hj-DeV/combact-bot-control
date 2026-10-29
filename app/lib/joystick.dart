import 'package:flutter/material.dart';

/// Two-axis virtual joystick for drive control.
/// Reports x/y in -1.0..1.0; y is positive up (screen is flipped).
class Joystick extends StatefulWidget {
  const Joystick({
    super.key,
    required this.onChanged,
    this.size = 200,
    this.springBack = true,
    this.stickColor = const Color(0xFF4FC3F7),
    this.baseColor = const Color(0xFF263238),
  });

  final void Function(double x, double y) onChanged;
  final double size;
  final bool springBack;
  final Color stickColor;
  final Color baseColor;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _stick = Offset.zero; // -1..1 in both axes

  void _update(Offset local, Size size) {
    final r = size.width / 2;
    var dx = (local.dx - r) / r;
    var dy = (local.dy - r) / r;
    final mag = Offset(dx, dy).distance;
    if (mag > 1.0) {
      dx /= mag;
      dy /= mag;
    }
    setState(() => _stick = Offset(dx, dy));
    widget.onChanged(dx, -dy); // invert: screen down = stick up
  }

  void _release() {
    if (!widget.springBack) return;
    setState(() => _stick = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    final knob = widget.size * 0.32;
    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition, Size.square(widget.size)),
      onPanUpdate: (d) => _update(d.localPosition, Size.square(widget.size)),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.baseColor,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              left: r + _stick.dx * (r - knob / 2) - knob / 2,
              top: r - _stick.dy * (r - knob / 2) - knob / 2,
              child: Container(
                width: knob,
                height: knob,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.stickColor,
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 6)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
