import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    const primary = Color(0xFF0E7C86);
    const secondary = Color(0xFFE1B261);
    const background = Color(0xFFF4F7FB);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    final baseTextTheme = GoogleFonts.manropeTextTheme(
      Typography.material2021().black,
    );
    final displayTextTheme = GoogleFonts.soraTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.sora(fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.sora(fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.sora(fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.sora(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.sora(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.sora(fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.sora(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.manrope(height: 1.45),
      bodyMedium: GoogleFonts.manrope(height: 1.42),
      labelLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: displayTextTheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.manrope(),
      ),
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}
