import 'package:flutter/material.dart';

import 'theme.dart';

/// Floating two-axis joystick that owns a whole touch zone.
///
/// The base appears wherever the thumb lands, the knob follows the finger 1:1
/// (screen up = forward) and everything springs back to centre on release.
/// Reports x/y in -1.0..1.0 with y positive = forward.
class JoystickZone extends StatefulWidget {
  const JoystickZone({
    super.key,
    required this.onChanged,
    this.maxRadius = 120,
    this.deadZone = 0.06,
    this.label = 'DRIVE',
    this.accent = CombatColors.accent,
  });

  final void Function(double x, double y) onChanged;
  final double maxRadius;
  final double deadZone;
  final String label;
  final Color accent;

  @override
  State<JoystickZone> createState() => _JoystickZoneState();
}

class _JoystickZoneState extends State<JoystickZone> {
  int? _pointer;
  Offset? _origin;
  Offset _stick = Offset.zero; // screen coords, -1..1
  double _radius = 0;

  double _effectiveRadius(Size zone) {
    final fit = (zone.shortestSide / 2) - 12;
    return fit < widget.maxRadius ? fit : widget.maxRadius;
  }

  void _down(PointerDownEvent e, Size zone) {
    if (_pointer != null) return;
    _radius = _effectiveRadius(zone);
    final p = e.localPosition;
    _pointer = e.pointer;
    _origin = Offset(
      p.dx.clamp(_radius, zone.width - _radius),
      p.dy.clamp(_radius, zone.height - _radius),
    );
    _move(p);
  }

  void _move(Offset p) {
    final o = _origin;
    if (o == null || _radius <= 0) return;
    var v = (p - o) / _radius;
    final mag = v.distance;
    if (mag > 1) v = v / mag;
    setState(() => _stick = v);
    final out = mag < widget.deadZone ? Offset.zero : v;
    widget.onChanged(out.dx, -out.dy);
  }

  void _up() {
    if (_pointer == null) return;
    setState(() {
      _pointer = null;
      _origin = null;
      _stick = Offset.zero;
    });
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final zone = Size(c.maxWidth, c.maxHeight);
      final r = _effectiveRadius(zone);
      final knob = r * 0.62;
      final o = _origin;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _down(e, zone),
        onPointerMove: (e) {
          if (e.pointer == _pointer) _move(e.localPosition);
        },
        onPointerUp: (e) {
          if (e.pointer == _pointer) _up();
        },
        onPointerCancel: (e) {
          if (e.pointer == _pointer) _up();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (o == null)
              Center(
                child: _IdleHint(radius: r, label: widget.label),
              ),
            if (o != null) ...[
              Positioned(
                left: o.dx - r,
                top: o.dy - r,
                child: _Base(radius: r, accent: widget.accent, stick: _stick),
              ),
              Positioned(
                left: o.dx + _stick.dx * (r - knob / 2) - knob / 2,
                top: o.dy + _stick.dy * (r - knob / 2) - knob / 2,
                child: _Knob(size: knob, accent: widget.accent),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.radius, required this.label});
  final double radius;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CombatColors.outline, width: 1.5),
            ),
          ),
          const Icon(Icons.keyboard_arrow_up,
              color: CombatColors.outline, size: 28),
          Align(
            alignment: const Alignment(0, 0.85),
            child: Icon(Icons.keyboard_arrow_down,
                color: CombatColors.outline, size: 28),
          ),
          Align(
            alignment: const Alignment(-0.85, 0),
            child: Icon(Icons.keyboard_arrow_left,
                color: CombatColors.outline, size: 28),
          ),
          Align(
            alignment: const Alignment(0.85, 0),
            child: Icon(Icons.keyboard_arrow_right,
                color: CombatColors.outline, size: 28),
          ),
          Align(
            alignment: const Alignment(0, -0.85),
            child: Icon(Icons.keyboard_arrow_up,
                color: CombatColors.outline, size: 28),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: CombatColors.textDim,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text('touch anywhere here',
                  style: TextStyle(color: CombatColors.outline, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Base extends StatelessWidget {
  const _Base({required this.radius, required this.accent, required this.stick});
  final double radius;
  final Color accent;
  final Offset stick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CombatColors.panel.withValues(alpha: 0.85),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
      ),
      child: CustomPaint(painter: _CrossPainter(accent, stick)),
    );
  }
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.accent, this.stick);
  final Color accent;
  final Offset stick;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final line = Paint()
      ..color = CombatColors.outline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), line);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), line);
    final vec = Paint()
      ..color = accent.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + stick * r * 0.7, vec);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.stick != stick;
}

class _Knob extends StatelessWidget {
  const _Knob({required this.size, required this.accent});
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [accent, accent.withValues(alpha: 0.75)],
        ),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 2),
        ],
      ),
    );
  }
}
