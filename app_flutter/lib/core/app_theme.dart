import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PacketDial premium dark theme & design tokens.
class AppTheme {
  AppTheme._();

  // ── Brand Palette ──────────────────────────────────────────────────────────
  static const Color surface = Color(0xFF0D0D1A);
  static const Color surfaceVariant = Color(0xFF14142B);
  static const Color surfaceCard = Color(0xFF1A1A2E);
  static const Color surfaceCardAlt = Color(0xFF1E1E36);
  static const Color border = Color(0xFF2A2A4A);
  static const Color borderSubtle = Color(0xFF222244);

  static const Color primary = Color(0xFF7C8BF5); // soft indigo
  static const Color primaryDim = Color(0xFF5C6BC0);
  static const Color accent = Color(0xFF26A69A); // teal
  static const Color accentBright = Color(0xFF4DD0B8);

  static const Color callGreen = Color(0xFF43A047);
  static const Color callGreenBright = Color(0xFF66BB6A);
  static const Color hangupRed = Color(0xFFE53935);
  static const Color hangupRedBright = Color(0xFFEF5350);

  static const Color warningAmber = Color(0xFFFFA726);
  static const Color errorRed = Color(0xFFEF5350);
  static const Color textPrimary = Color(0xFFE8E8F0);
  static const Color textSecondary = Color(0xFF9999B5);
  static const Color textTertiary = Color(0xFF6B6B88);
  static const Color inputFill = Color(0xFF14142B); // Same as surfaceVariant

  // ── Window Geometry ────────────────────────────────────────────────────────
  static const Size defaultWindowSize = Size(450, 850);
  static const Size minWindowSize = Size(400, 750);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient titleBarGradient = LinearGradient(
    colors: [Color(0xFF1A1040), Color(0xFF0D0D1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient callButtonGradient = LinearGradient(
    colors: [Color(0xFF2E7D32), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient hangupButtonGradient = LinearGradient(
    colors: [Color(0xFFC62828), Color(0xFFAD1457)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF5C6BC0), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient numpadGradient = LinearGradient(
    colors: [Color(0xFF1E1E36), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Shadows & Glows ────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> glowShadow(Color color, {double blur = 12}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  // ── Glassmorphism Decoration ──────────────────────────────────────────────
  static BoxDecoration glassCard({
    Color? color,
    double borderRadius = 12,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: color ?? surfaceCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? border.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: cardShadow,
      );

  // ── Status Dot ─────────────────────────────────────────────────────────────
  static Widget statusDot(Color color, {double size = 8}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glowShadow(color, blur: 8),
        ),
      );

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        secondary: accent,
        error: errorRed,
        onPrimary: Colors.white,
        onSurface: textPrimary,
        onSecondary: Colors.white,
        outline: border,
        surfaceContainerHighest: surfaceCard,
      ),
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: baseText.headlineMedium
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: baseText.titleLarge
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: baseText.titleMedium
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
        titleSmall: baseText.titleSmall?.copyWith(color: textSecondary),
        bodyLarge: baseText.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondary),
        bodySmall: baseText.bodySmall?.copyWith(color: textTertiary),
        labelLarge: baseText.labelLarge?.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
        labelMedium: baseText.labelMedium?.copyWith(color: textSecondary),
        labelSmall: baseText.labelSmall
            ?.copyWith(color: textTertiary, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceVariant,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceVariant,
        indicatorColor: primary.withValues(alpha: 0.15),
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: textTertiary, size: 20);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textTertiary,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceCard,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        side: const BorderSide(color: textTertiary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
        ),
      ),
    );
  }
}
