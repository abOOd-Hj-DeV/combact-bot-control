import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'drive_page.dart';
import 'link.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape-only: both hands on the sticks.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CombatControllerApp());
}

class CombatControllerApp extends StatelessWidget {
  const CombatControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Combact Controller',
      debugShowCheckedModeBanner: false,
      theme: combatTheme(),
      home: DrivePage(link: RobotLink()),
    );
  }
}
