import 'package:flutter/material.dart';

class CombatColors {
  static const bg = Color(0xFF0B0F14);
  static const panel = Color(0xFF151C24);
  static const panelHi = Color(0xFF1E2833);
  static const outline = Color(0xFF3A4752);
  static const text = Color(0xFFE6EDF3);
  static const textDim = Color(0xFF8B98A5);
  static const accent = Color(0xFF4FC3F7);
  static const ok = Color(0xFF34C759);
  static const warn = Color(0xFFFF9F0A);
  static const danger = Color(0xFFFF3B30);
}

ThemeData combatTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CombatColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: CombatColors.accent,
        secondary: CombatColors.danger,
        surface: CombatColors.panel,
      ),
      fontFamily: 'Roboto',
    );
