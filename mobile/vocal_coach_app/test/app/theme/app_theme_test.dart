import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:vocal_coach_app/app/theme/app_theme.dart';
import 'package:vocal_coach_app/app/theme/app_theme_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('dark theme exposes semantic tokens through the shared theme', () {
    final theme = AppTheme.dark();
    final tokens = theme.appTokens;

    expect(tokens.success, isNot(equals(Colors.greenAccent)));
    expect(tokens.danger, isNot(equals(Colors.redAccent)));
    expect(theme.cardTheme.elevation, 0);
    expect(theme.colorScheme.onSurfaceVariant, isNotNull);
  });
}
