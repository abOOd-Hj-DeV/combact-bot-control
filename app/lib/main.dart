import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'drive_page.dart';
import 'link.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape-only: both hands on the sticks.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const CombatControllerApp());
}

class CombatControllerApp extends StatelessWidget {
  const CombatControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Combact Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: DrivePage(link: RobotLink()),
    );
  }
}
