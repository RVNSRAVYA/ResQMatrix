import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// ResQMatrix design tokens. Existing screens use the same navy/teal values,
/// so the whole app stays visually consistent.
class AppColors {
  static const ink = Color(0xFF14273D);
  static const inkDeep = Color(0xFF0B1B2E);
  static const teal = Color(0xFF0F9F91);
  static const mint = Color(0xFF5EEAD4);
  static const canvas = Color(0xFFF3F6FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE3E9F0);
  static const muted = Color(0xFF66768A);
  static const orange = Color(0xFFE87935);
  static const red = Color(0xFFCB3A4B);
  static const indigo = Color(0xFF5B63D3);
  static const blue = Color(0xFF3F82C6);
  static const green = Color(0xFF18865A);
  static const amber = Color(0xFFE4A126);
  static const violet = Color(0xFF8B5FC7);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF0B1B2E), Color(0xFF16405A), Color(0xFF14786F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color risk(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return green;
      case 'moderate':
        return amber;
      case 'high':
        return orange;
      case 'critical':
        return red;
      default:
        return teal;
    }
  }
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.ink,
      surface: AppColors.surface,
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.teal, 1.8),
        errorBorder: border(AppColors.red),
        focusedErrorBorder: border(AppColors.red, 1.8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.teal.withValues(alpha: .14),
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.teal),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.teal : const Color(0xFFCBD5E1)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
