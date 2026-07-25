import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({
    required this.apiBaseUrl,
    required this.useDevAuthToken,
    required this.useFirebaseAuthEmulator,
    required this.firebaseAuthEmulatorHost,
    required this.firebaseAuthEmulatorPort,
  });

  final String apiBaseUrl;
  final bool useDevAuthToken;
  final bool useFirebaseAuthEmulator;
  final String firebaseAuthEmulatorHost;
  final int firebaseAuthEmulatorPort;

  static AppConfig resolve() {
    const overrideUrl =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const useDevAuthTokenRaw =
        String.fromEnvironment('USE_DEV_AUTH_TOKEN', defaultValue: 'false');
    const useFirebaseAuthEmulatorRaw = String.fromEnvironment(
      'USE_FIREBASE_AUTH_EMULATOR',
      defaultValue: 'false',
    );
    const authEmulatorHostOverride = String.fromEnvironment(
      'FIREBASE_AUTH_EMULATOR_HOST',
      defaultValue: '',
    );
    const authEmulatorPortRaw = String.fromEnvironment(
      'FIREBASE_AUTH_EMULATOR_PORT',
      defaultValue: '9099',
    );

    final useDevAuthToken = _asBool(useDevAuthTokenRaw, fallback: false);
    final useFirebaseAuthEmulator =
        _asBool(useFirebaseAuthEmulatorRaw, fallback: false);
    final authEmulatorHost = _resolveAuthEmulatorHost(authEmulatorHostOverride);
    final authEmulatorPort = int.tryParse(authEmulatorPortRaw) ?? 9099;

    if (overrideUrl.isNotEmpty) {
      return AppConfig(
        apiBaseUrl: overrideUrl,
        useDevAuthToken: useDevAuthToken,
        useFirebaseAuthEmulator: useFirebaseAuthEmulator,
        firebaseAuthEmulatorHost: authEmulatorHost,
        firebaseAuthEmulatorPort: authEmulatorPort,
      );
    }

    if (kIsWeb) {
      return AppConfig(
        apiBaseUrl: 'http://127.0.0.1:8000',
        useDevAuthToken: useDevAuthToken,
        useFirebaseAuthEmulator: useFirebaseAuthEmulator,
        firebaseAuthEmulatorHost: authEmulatorHost,
        firebaseAuthEmulatorPort: authEmulatorPort,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AppConfig(
          apiBaseUrl: 'http://127.0.0.1:8000',
          useDevAuthToken: useDevAuthToken,
          useFirebaseAuthEmulator: useFirebaseAuthEmulator,
          firebaseAuthEmulatorHost: authEmulatorHost,
          firebaseAuthEmulatorPort: authEmulatorPort,
        );
      default:
        return AppConfig(
          apiBaseUrl: 'http://127.0.0.1:8000',
          useDevAuthToken: useDevAuthToken,
          useFirebaseAuthEmulator: useFirebaseAuthEmulator,
          firebaseAuthEmulatorHost: authEmulatorHost,
          firebaseAuthEmulatorPort: authEmulatorPort,
        );
    }
  }
}

String _resolveAuthEmulatorHost(String override) {
  if (override.trim().isNotEmpty) {
    return override.trim();
  }
  if (kIsWeb) {
    return '127.0.0.1';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return '10.0.2.2';
    default:
      return '127.0.0.1';
  }
}

bool _asBool(String raw, {required bool fallback}) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return fallback;
  }
  return {'1', 'true', 'yes', 'on'}.contains(normalized);
}

final appConfig = AppConfig.resolve();
