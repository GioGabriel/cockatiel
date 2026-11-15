import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';

/// Cockatiel's shared visual system.
///
/// Midnight surfaces, lavender actions and pink accents follow the client reference.
/// Text and controls retain solid surfaces for legibility.
class AppTheme {
  AppTheme._();

  static const _lightPrimary = Color(0xFF7040BA);
  static const _lightSecondary = Color(0xFF8F3C7E);
  static const _lightBackground = Color(0xFFF9F5FF);

  static const _darkBackground = Color(0xFF070419);
  static const _darkSurface = Color(0xFF120C2B);
  static const _darkSurfaceRaised = Color(0xFF21143C);
  static const _darkBorder = Color(0xFF483460);
  static const _darkPrimary = Color(0xFFC4A7FF);
  static const _darkSecondary = Color(0xFFF2A7D5);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(
      primary: _lightPrimary,
      secondary: _lightSecondary,
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFF5EEFF),
      onSurface: const Color(0xFF17202A),
      onSurfaceVariant: const Color(0xFF52606D),
      outline: const Color(0xFFB7C2CF),
      outlineVariant: const Color(0xFFD9E0E8),
    );

    return _buildTheme(
      scheme: scheme,
      brightness: Brightness.light,
      background: _lightBackground,
      surface: Colors.white,
      raisedSurface: const Color(0xFFF1F4F8),
      tokens: const AppThemeTokens(
        success: Color(0xFF16794C),
        warning: Color(0xFF8A5A00),
        info: Color(0xFF005CC8),
        danger: Color(0xFFBA1A1A),
        focusRing: _lightPrimary,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
      surface: _darkSurface,
    ).copyWith(
      primary: _darkPrimary,
      onPrimary: const Color(0xFF28134D),
      secondary: _darkSecondary,
      onSecondary: const Color(0xFF451337),
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceRaised,
      onSurface: const Color(0xFFF5EEFF),
      onSurfaceVariant: const Color(0xFFC6B9DA),
      outline: _darkBorder,
      outlineVariant: const Color(0xFF332446),
    );

    return _buildTheme(
      scheme: scheme,
      brightness: Brightness.dark,
      background: _darkBackground,
      surface: _darkSurface,
      raisedSurface: _darkSurfaceRaised,
      tokens: const AppThemeTokens(
        success: Color(0xFF69E6AB),
        warning: Color(0xFFFFD166),
        info: Color(0xFFF2A7D5),
        danger: Color(0xFFFFB4AB),
        focusRing: _darkPrimary,
      ),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color raisedSurface,
    required AppThemeTokens tokens,
  }) {
    final textTheme = _buildTextTheme(brightness);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: scheme.outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      extensions: <ThemeExtension<dynamic>>[tokens],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raisedSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: tokens.focusRing, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: tokens.danger),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle:
              const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle:
              const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          textStyle:
              const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raisedSurface,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(fontFamily: 'Inter', color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: raisedSurface,
        contentTextStyle:
            TextStyle(fontFamily: 'Inter', color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: scheme.outlineVariant,
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;
    final outfitTheme = base.apply(fontFamily: 'Inter');
    return outfitTheme.copyWith(
      displayLarge: outfitTheme.displayLarge
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
      displayMedium: outfitTheme.displayMedium
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
      headlineLarge: outfitTheme.headlineLarge
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
      headlineMedium: outfitTheme.headlineMedium
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
      headlineSmall: outfitTheme.headlineSmall
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
      titleLarge: outfitTheme.titleLarge
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
      titleMedium: outfitTheme.titleMedium
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
      titleSmall: outfitTheme.titleSmall
          ?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
      bodyLarge: outfitTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: outfitTheme.bodyMedium?.copyWith(height: 1.42),
      labelLarge: outfitTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
