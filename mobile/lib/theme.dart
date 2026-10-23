import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Midnight base, nebula violet, and moonlit gold as the one warm accent.
  static const Color background = Color(0xFF07060F);
  static const Color backgroundDeep = Color(0xFF030208);
  static const Color surface = Color(0xFF15122A);
  static const Color primary = Color(0xFF9D8CFF);
  static const Color accent = Color(0xFFE9C98B);
  static const Color rose = Color(0xFFD98BC4);
  static const Color ink = Color(0xFF1A1330);
  static const Color textPrimary = Color(0xFFF1EDFF);
  static const Color textSecondary = Color(0xFF9C95BC);
  static const Color hairline = Color(0x33E9C98B);

  /// Serif used for headings and dream text — gives the app its storybook voice.
  static TextStyle display({
    double size = 36,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w500,
    FontStyle? style,
    double height = 1.15,
  }) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        color: color,
        fontWeight: weight,
        fontStyle: style,
        height: height,
      );

  /// Small, widely tracked caps used as section labels.
  static TextStyle eyebrow({Color color = accent}) => GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.2,
        color: color,
      );

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: hairline, width: 0.8),
    );

    return base.copyWith(
      // Scaffolds are transparent so the shared NightSky shows through.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: accent,
        surface: surface,
      ),
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textPrimary,
        titleTextStyle: eyebrow(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: accent.withValues(alpha: 0.7), width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.8)),
        prefixIconColor: textSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: primary.withValues(alpha: 0.35),
        selectionHandleColor: accent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xB30A0816),
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: states.contains(WidgetState.selected) ? accent : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : textSecondary,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: GoogleFonts.manrope(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: hairline),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values) platform: const _DreamPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Pages dissolve into each other with a slight settle, like a scene changing in a dream.
class _DreamPageTransitionsBuilder extends PageTransitionsBuilder {
  const _DreamPageTransitionsBuilder();

  static final _fadeIn = CurveTween(curve: Curves.easeOutCubic);
  static final _settle = Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic));
  static final _fadeOut = Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: secondaryAnimation.drive(_fadeOut),
      child: FadeTransition(
        opacity: animation.drive(_fadeIn),
        child: ScaleTransition(scale: animation.drive(_settle), child: child),
      ),
    );
  }
}
