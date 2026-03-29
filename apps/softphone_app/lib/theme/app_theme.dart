import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D5C63),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF3EFE7),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.only(bottom: 12),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF11212D),
        selectedIconTheme: IconThemeData(color: Color(0xFFF7B267)),
        selectedLabelTextStyle: TextStyle(
          color: Color(0xFFF7B267),
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: Color(0xFFCCD6DD)),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFFCCD6DD)),
      ),
    );
  }
}
