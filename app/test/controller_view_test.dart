import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:combact_controller/controller_view.dart';
import 'package:combact_controller/joystick.dart';
import 'package:combact_controller/protocol.dart';

Widget _view(ControllerState s, {void Function(double, double)? onDrive}) =>
    MaterialApp(
      home: ControllerView(
        state: s,
        onDrive: onDrive ?? (_, _) {},
        onArmed: (_) {},
        onHammer: (_) {},
        onFire: (_) {},
        onInvert: (_) {},
        onLowSpeed: (_) {},
      ),
    );

TelemetryPacket _tele() => TelemetryPacket()
  ..flags = teleLinked | teleArmed
  ..lastSeq = 7
  ..batteryMv = 11800
  ..rssiDbm = -55
  ..rxRateHz = 50
  ..lost = 2;

void main() {
  for (final size in const [
    Size(640, 360),
    Size(800, 360),
    Size(915, 412),
    Size(1280, 600),
    Size(2000, 900),
  ]) {
    testWidgets('no overflow at ${size.width}x${size.height}', (t) async {
      await t.binding.setSurfaceSize(size);
      t.view.devicePixelRatio = 1.0;
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_view(
          ControllerState(telemetry: _tele(), telemetryStale: false, armed: true)));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('ARMED'), findsOneWidget);
      expect(find.text('FIRE'), findsOneWidget);
      expect(find.text('LINKED'), findsOneWidget);
      await t.pumpWidget(_view(const ControllerState()));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('NO LINK'), findsOneWidget);
      expect(find.text('DISARMED'), findsOneWidget);
    });
  }

  testWidgets('joystick: finger up => forward, right => right, release => 0',
      (t) async {
    await t.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final log = <Offset>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: JoystickZone(onChanged: (x, y) => log.add(Offset(x, y))),
      ),
    ));
    final zone = find.byType(JoystickZone);
    final center = t.getCenter(zone);
    final g = await t.startGesture(center);
    await t.pump();
    await g.moveBy(const Offset(0, -80));
    await t.pump();
    expect(log.last.dy, greaterThan(0.5), reason: 'up is forward');
    expect(log.last.dx.abs(), lessThan(0.05));
    await g.moveBy(const Offset(80, 80));
    await t.pump();
    expect(log.last.dx, greaterThan(0.5), reason: 'right is right');
    await g.up();
    await t.pump();
    expect(log.last, Offset.zero);
    expect(t.takeException(), isNull);
  });

  testWidgets('joystick base appears under the finger anywhere in the zone',
      (t) async {
    await t.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: JoystickZone(onChanged: (_, _) {})),
    ));
    final box = t.getRect(find.byType(JoystickZone));
    final g = await t.startGesture(box.center + const Offset(-150, 60));
    await t.pump();
    expect(find.text('touch anywhere here'), findsNothing);
    await g.up();
    await t.pump();
    expect(find.text('touch anywhere here'), findsOneWidget);
  });
}
