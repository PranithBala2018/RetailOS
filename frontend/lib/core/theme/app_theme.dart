import 'package:flutter/material.dart';

/// Light/dark theme definitions, per SPRINT0.md (Frontend §"Themes").
/// Module-specific theming (POS billing screen density, receipt preview,
/// etc.) extends this in later sprints — this is the shared baseline.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static const Color _seedColor = Color(0xFF0F62FE);
}
