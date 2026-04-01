import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    const page = Color(0xFFF2F6FA);
    const panel = Color(0xFFFFFFFF);
    const surfaceAlt = Color(0xFFF7FAFC);
    const border = Color(0xFFD8E3EC);
    const accent = Color(0xFF1DA8D6);
    const primaryText = Color(0xFF1F2F3B);
    const secondaryText = Color(0xFF6B7F8E);

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: accent,
      secondary: accent,
      surface: panel,
    );

    final base = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        labelStyle: const TextStyle(color: secondaryText),
        hintStyle: const TextStyle(color: Color(0xFF98A9B5)),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineSmall: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: primaryText,
          letterSpacing: -0.2,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13,
          color: primaryText,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: secondaryText,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFFEFF4F9),
        selectedIconTheme: IconThemeData(color: Color(0xFF1DA8D6), size: 20),
        selectedLabelTextStyle: TextStyle(
          color: Color(0xFF1DA8D6),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedIconTheme: IconThemeData(color: Color(0xFF6F8596), size: 20),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFF6F8596), fontSize: 12),
        indicatorColor: Color(0x221DA8D6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryText,
          side: const BorderSide(color: border),
          backgroundColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: border),
        selectedColor: const Color(0x221DA8D6),
        backgroundColor: surfaceAlt,
      ),
    );
  }
}
