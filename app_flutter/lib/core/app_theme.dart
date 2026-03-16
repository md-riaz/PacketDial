import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PacketDial design tokens — dark and light variants.
class AppTheme {
  AppTheme._();

  // ── Brand Palette (dark) ───────────────────────────────────────────────────
  static const Color surface = Color(0xFF0D0D1A);
  static const Color surfaceVariant = Color(0xFF14142B);
  static const Color surfaceCard = Color(0xFF1A1A2E);
  static const Color surfaceCardAlt = Color(0xFF1E1E36);
  static const Color border = Color(0xFF2A2A4A);
  static const Color borderSubtle = Color(0xFF222244);

  static const Color primary = Color(0xFF7C8BF5);
  static const Color primaryDim = Color(0xFF5C6BC0);
  static const Color accent = Color(0xFF26A69A);
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
  static const Color inputFill = Color(0xFF14142B);

  // ── Brand Palette (light) ─────────────────────────────────────────────────
  static const Color lSurface = Color(0xFFF8F9FF);        // near-white with a hint of blue
  static const Color lSurfaceVariant = Color(0xFFEEF0FB); // very light lavender
  static const Color lSurfaceCard = Color(0xFFFFFFFF);    // pure white cards
  static const Color lSurfaceCardAlt = Color(0xFFF3F4FC);
  static const Color lBorder = Color(0xFFD8DAF0);
  static const Color lBorderSubtle = Color(0xFFE8EAF6);

  static const Color lPrimary = Color(0xFF4A5CC8);        // deeper indigo for contrast on white
  static const Color lPrimaryDim = Color(0xFF7C8BF5);
  static const Color lAccent = Color(0xFF00897B);
  static const Color lAccentBright = Color(0xFF26A69A);

  static const Color lTextPrimary = Color(0xFF14142A);    // near-black
  static const Color lTextSecondary = Color(0xFF3D3D60);
  static const Color lTextTertiary = Color(0xFF7878A0);
  static const Color lInputFill = Color(0xFFF0F1FA);

  // ── Spacing Scale ─────────────────────────────────────────────────────────
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // ── Radius Scale ──────────────────────────────────────────────────────────
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;

  // ── Animation Durations ───────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ── Window Geometry ────────────────────────────────────────────────────────
  static const Size defaultWindowSize = Size(450, 850);
  static const Size minWindowSize = Size(400, 750);
  static const Size maxWindowSize = Size(600, 1100);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient titleBarGradient = LinearGradient(
    colors: [Color(0xFF1A1040), Color(0xFF0D0D1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient titleBarGradientLight = LinearGradient(
    colors: [Color(0xFFE8EBF8), Color(0xFFEEF0FB)],
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

  static const LinearGradient numpadGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF3F4FC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient pageGradient = LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A1040)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pageGradientLight = LinearGradient(
    colors: [Color(0xFFF8F9FF), Color(0xFFEEF0FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Tinted info / tip card decoration.
  static BoxDecoration infoCard({Color? color}) {
    final c = color ?? primary;
    return BoxDecoration(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(radiusMd + 2),
      border: Border.all(color: c.withValues(alpha: 0.3)),
    );
  }

  // ── Shadows & Glows ────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadowLight => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
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

  // ── Context-aware color helpers ────────────────────────────────────────────
  /// Returns the correct gradient for the current theme brightness.
  static LinearGradient pageGradientOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? pageGradient
        : pageGradientLight;
  }

  static LinearGradient titleBarGradientOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? titleBarGradient
        : titleBarGradientLight;
  }

  static LinearGradient numpadGradientOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? numpadGradient
        : numpadGradientLight;
  }

  static List<BoxShadow> cardShadowOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cardShadow
        : cardShadowLight;
  }

  // ── ThemeData: dark ────────────────────────────────────────────────────────
  static ThemeData get dark => _buildTheme(Brightness.dark);

  // ── ThemeData: light ───────────────────────────────────────────────────────
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? surface : lSurface;
    final variant = isDark ? surfaceVariant : lSurfaceVariant;
    final card = isDark ? surfaceCard : lSurfaceCard;
    final brd = isDark ? border : lBorder;
    final pri = isDark ? primary : lPrimary;
    final acc = isDark ? accent : lAccent;
    final err = errorRed;
    final tp = isDark ? textPrimary : lTextPrimary;
    final ts = isDark ? textSecondary : lTextSecondary;
    final tt = isDark ? textTertiary : lTextTertiary;
    final fill = isDark ? inputFill : lInputFill;

    final baseText = isDark
        ? GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        surface: bg,
        primary: pri,
        secondary: acc,
        error: err,
        onPrimary: Colors.white,
        onSurface: tp,
        onSecondary: Colors.white,
        onError: Colors.white,
        outline: brd,
        surfaceContainerHighest: card,
      ),
      textTheme: baseText.copyWith(
        headlineLarge:
            baseText.headlineLarge?.copyWith(color: tp, fontWeight: FontWeight.w700),
        headlineMedium:
            baseText.headlineMedium?.copyWith(color: tp, fontWeight: FontWeight.w600),
        titleLarge:
            baseText.titleLarge?.copyWith(color: tp, fontWeight: FontWeight.w600),
        titleMedium:
            baseText.titleMedium?.copyWith(color: tp, fontWeight: FontWeight.w500),
        titleSmall: baseText.titleSmall?.copyWith(color: ts),
        bodyLarge: baseText.bodyLarge?.copyWith(color: tp),
        bodyMedium: baseText.bodyMedium?.copyWith(color: ts),
        bodySmall: baseText.bodySmall?.copyWith(color: tt),
        labelLarge: baseText.labelLarge
            ?.copyWith(color: tp, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelMedium: baseText.labelMedium?.copyWith(color: ts),
        labelSmall: baseText.labelSmall?.copyWith(color: tt, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: variant,
        foregroundColor: tp,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: tp,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: brd.withValues(alpha: 0.5)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: variant,
        indicatorColor: pri.withValues(alpha: 0.15),
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: pri, size: 22);
          }
          return IconThemeData(color: tt, size: 20);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: brd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: brd),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: pri, width: 1.5),
        ),
        labelStyle: TextStyle(color: ts),
        hintStyle: TextStyle(color: tt),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: pri,
        unselectedLabelColor: tt,
        indicatorColor: pri,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
      ),
      dividerTheme: DividerThemeData(
        color: brd.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: pri,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: variant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tp,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: GoogleFonts.inter(color: tp, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return pri;
          return Colors.transparent;
        }),
        side: BorderSide(color: tt),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: brd),
          ),
        ),
      ),
    );
  }
}

/// Context-aware color accessors — always returns the right palette for the
/// current theme brightness. Use `context.colors.surface` etc. in widgets.
extension AppColors on BuildContext {
  AppColorSet get colors {
    final dark = Theme.of(this).brightness == Brightness.dark;
    return AppColorSet(dark);
  }
}

class AppColorSet {
  final bool _dark;
  const AppColorSet(this._dark);

  Color get surface => _dark ? AppTheme.surface : AppTheme.lSurface;
  Color get surfaceVariant =>
      _dark ? AppTheme.surfaceVariant : AppTheme.lSurfaceVariant;
  Color get surfaceCard => _dark ? AppTheme.surfaceCard : AppTheme.lSurfaceCard;
  Color get surfaceCardAlt =>
      _dark ? AppTheme.surfaceCardAlt : AppTheme.lSurfaceCardAlt;
  Color get border => _dark ? AppTheme.border : AppTheme.lBorder;
  Color get borderSubtle =>
      _dark ? AppTheme.borderSubtle : AppTheme.lBorderSubtle;
  Color get primary => _dark ? AppTheme.primary : AppTheme.lPrimary;
  Color get primaryDim => _dark ? AppTheme.primaryDim : AppTheme.lPrimaryDim;
  Color get accent => _dark ? AppTheme.accent : AppTheme.lAccent;
  Color get accentBright =>
      _dark ? AppTheme.accentBright : AppTheme.lAccentBright;
  Color get textPrimary => _dark ? AppTheme.textPrimary : AppTheme.lTextPrimary;
  Color get textSecondary =>
      _dark ? AppTheme.textSecondary : AppTheme.lTextSecondary;
  Color get textTertiary =>
      _dark ? AppTheme.textTertiary : AppTheme.lTextTertiary;
  Color get inputFill => _dark ? AppTheme.inputFill : AppTheme.lInputFill;

  // Semantic colors stay the same in both themes
  Color get callGreen => AppTheme.callGreen;
  Color get callGreenBright => AppTheme.callGreenBright;
  Color get hangupRed => AppTheme.hangupRed;
  Color get hangupRedBright => AppTheme.hangupRedBright;
  Color get warningAmber => AppTheme.warningAmber;
  Color get errorRed => AppTheme.errorRed;
  Color get accentBrightFixed => AppTheme.accentBright;

  LinearGradient get pageGradient =>
      _dark ? AppTheme.pageGradient : AppTheme.pageGradientLight;
  LinearGradient get titleBarGradient =>
      _dark ? AppTheme.titleBarGradient : AppTheme.titleBarGradientLight;
  LinearGradient get numpadGradient =>
      _dark ? AppTheme.numpadGradient : AppTheme.numpadGradientLight;

  List<BoxShadow> get cardShadow =>
      _dark ? AppTheme.cardShadow : AppTheme.cardShadowLight;

  BoxDecoration glassCard({
    Color? color,
    double borderRadius = 12,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: color ?? surfaceCard.withValues(alpha: _dark ? 0.8 : 1.0),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? border.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: cardShadow,
      );
}
