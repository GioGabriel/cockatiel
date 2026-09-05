import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({
    required this.apiBaseUrl,
    required this.useFirebaseAuthEmulator,
    required this.firebaseAuthEmulatorHost,
    required this.firebaseAuthEmulatorPort,
    this.apiPrefix = '/v1',
  });

  final String apiBaseUrl;
  final String apiPrefix;
  final bool useFirebaseAuthEmulator;
  final String firebaseAuthEmulatorHost;
  final int firebaseAuthEmulatorPort;

  /// Normalizes and validates a compile-time API endpoint override.
  static String normalizeApiBaseUrl(String value, {bool? isReleaseBuild}) =>
      _normalizeBaseUrl(
        value,
        isReleaseBuild: isReleaseBuild ?? kReleaseMode,
      );

  static AppConfig resolve() {
    const overrideUrl =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
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

    final requestedFirebaseAuthEmulator =
        _asBool(useFirebaseAuthEmulatorRaw, fallback: false);
    final authEmulatorHost = _resolveAuthEmulatorHost(authEmulatorHostOverride);
    final authEmulatorPort = _safePort(authEmulatorPortRaw);
    final baseUrl = _normalizeBaseUrl(
      overrideUrl.isNotEmpty ? overrideUrl : _productionApiBaseUrl,
    );
    final isLocal = _isLocalUrl(baseUrl);
    final allowLocalDevelopment = isLocal && !kReleaseMode;

    return AppConfig(
      apiBaseUrl: baseUrl,
      // The Firebase emulator can never be enabled for a release build or a
      // non-local API endpoint.
      useFirebaseAuthEmulator:
          requestedFirebaseAuthEmulator && allowLocalDevelopment,
      firebaseAuthEmulatorHost: authEmulatorHost,
      firebaseAuthEmulatorPort: authEmulatorPort,
    );
  }
}

const _productionApiBaseUrl = 'https://cockatiel-wdkv.onrender.com';

String _normalizeBaseUrl(String raw, {bool isReleaseBuild = kReleaseMode}) {
  final value = raw.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host.isEmpty ||
      !{'http', 'https'}.contains(uri.scheme)) {
    throw StateError('API_BASE_URL must be an absolute HTTP(S) URL.');
  }
  if ((uri.path.isNotEmpty && uri.path != '/') ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.userInfo.isNotEmpty) {
    throw StateError('API_BASE_URL must contain only scheme, host, and port.');
  }
  if (uri.scheme != 'https' && (!_isLocalUrl(value) || isReleaseBuild)) {
    throw StateError(
        'Non-HTTPS API_BASE_URL values are only allowed for local development.');
  }
  return value;
}

bool _isLocalUrl(String value) {
  final host = Uri.tryParse(value)?.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
}

int _safePort(String raw) {
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed < 1 || parsed > 65535) {
    return 9099;
  }
  return parsed;
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
