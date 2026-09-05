import 'package:flutter/material.dart';

/// Semantic colors that are not represented by the Material color scheme.
///
/// Feature screens should use these roles instead of inventing one-off neon
/// colors. The values are deliberately restrained so color communicates state
/// without becoming the only way to understand it.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
    required this.focusRing,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color danger;
  final Color focusRing;

  @override
  AppThemeTokens copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? danger,
    Color? focusRing,
  }) {
    return AppThemeTokens(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

extension AppThemeTokensExtension on ThemeData {
  AppThemeTokens get appTokens {
    return extension<AppThemeTokens>() ??
        (brightness == Brightness.dark
            ? const AppThemeTokens(
                success: Color(0xFF69E6AB),
                warning: Color(0xFFFFD166),
                info: Color(0xFF9DB8FF),
                danger: Color(0xFFFFB4AB),
                focusRing: Color(0xFF66D9B0),
              )
            : const AppThemeTokens(
                success: Color(0xFF16794C),
                warning: Color(0xFF8A5A00),
                info: Color(0xFF005CC8),
                danger: Color(0xFFBA1A1A),
                focusRing: Color(0xFF006B57),
              ));
  }
}
