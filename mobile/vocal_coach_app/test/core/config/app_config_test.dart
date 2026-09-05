import 'package:flutter_test/flutter_test.dart';

import 'package:vocal_coach_app/core/config/app_config.dart';

void main() {
  test('normalizes a valid endpoint without a trailing slash', () {
    expect(
      AppConfig.normalizeApiBaseUrl('https://api.example.test///'),
      'https://api.example.test',
    );
  });

  test('rejects insecure non-local endpoint overrides', () {
    expect(
      () => AppConfig.normalizeApiBaseUrl('http://api.example.test'),
      throwsStateError,
    );
  });

  test('allows HTTP only for local development endpoints', () {
    expect(
      AppConfig.normalizeApiBaseUrl('http://127.0.0.1:8000/'),
      'http://127.0.0.1:8000',
    );
  });

  test('rejects endpoint overrides that contain paths, queries, or credentials',
      () {
    expect(
      () => AppConfig.normalizeApiBaseUrl('https://user:pass@example.test/api'),
      throwsStateError,
    );
    expect(
      () => AppConfig.normalizeApiBaseUrl(
          'https://api.example.test?token=secret'),
      throwsStateError,
    );
  });
}
