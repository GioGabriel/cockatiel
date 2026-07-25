import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  /// Light theme — clean white surfaces on light gray background.
  static ThemeData light() {
    const primary = Color(0xFF007AFF);
    const secondary = Color(0xFFFF2D55);
    const background = Color(0xFFF2F2F7);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    final textTheme = _buildTextTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      iconTheme: const IconThemeData(size: 20),
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
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.inter(),
      ),
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  /// Dark theme — deep black/navy surfaces with glowing teal accents.
  ///
  /// Designed to match modern dark-UI patterns: subtle card elevation via
  /// lighter surface tones, glowing primary accents, and high-contrast text.
  static ThemeData dark() {
    const bg        = Color(0xFF09090F);
    const surface1  = Color(0xFF111119);
    const surface2  = Color(0xFF1C1C27);
    const border    = Color(0xFF2A2A3C);
    const primary   = Color(0xFF5B6EFA);
    const secondary = Color(0xFFA78BFA);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      brightness: Brightness.dark,
      surface: surface1,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: surface1,
      surfaceContainerHighest: surface2,
      onSurface: const Color(0xFFEAEAF2),
      onSurfaceVariant: const Color(0xFF8A8AA8),
      outline: border,
      outlineVariant: const Color(0xFF1F1F2E),
    );

    final textTheme = _buildTextTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      iconTheme: const IconThemeData(size: 20),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: border,
            width: 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface1,
        selectedColor: primary.withValues(alpha: 0.2),
        side: BorderSide(color: scheme.outline),
        labelStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: primary.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.inter(color: scheme.onSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface1,
        contentTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: scheme.outline.withValues(alpha: 0.5),
    );
  }

  /// Shared text theme construction for both light and dark.
  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;

    final baseTextTheme = GoogleFonts.interTextTheme(base);
    final outfitTheme = GoogleFonts.outfitTextTheme(baseTextTheme);
    return outfitTheme.copyWith(
      displayLarge: outfitTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: outfitTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: outfitTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: outfitTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: outfitTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: outfitTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: outfitTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: outfitTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: outfitTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: outfitTheme.bodyMedium?.copyWith(height: 1.42),
      labelLarge: outfitTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
