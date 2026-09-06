import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vocal_coach_app/core/auth/auth_token_provider.dart';
import 'package:vocal_coach_app/core/config/app_config.dart';
import 'package:vocal_coach_app/core/network/api_client.dart';
import 'package:vocal_coach_app/shared/models/user_models.dart';

class _FakeTokenProvider implements AuthTokenProvider {
  _FakeTokenProvider(this.token);

  final String token;

  @override
  Future<String> getToken() async => token;
}

AppConfig _config() {
  return AppConfig(
    apiBaseUrl: 'https://api.example.test',
    useFirebaseAuthEmulator: false,
    firebaseAuthEmulatorHost: '127.0.0.1',
    firebaseAuthEmulatorPort: 9099,
  );
}

void main() {
  test('maps structured API errors without retaining the raw response body',
      () async {
    final client = ApiClient(
      config: _config(),
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"AUTH_INVALID","message":"Authentication failed.","trace_id":"trace-1","details":{"secret":"do-not-display"}}}',
          401,
        ),
      ),
    );

    final error = await catchError(() => client.fetchCurrentUser());

    expect(error, isA<ApiException>());
    final apiError = error as ApiException;
    expect(apiError.statusCode, 401);
    expect(apiError.code, 'AUTH_INVALID');
    expect(apiError.message, 'Authentication failed.');
    expect(apiError.toString(), isNot(contains('do-not-display')));
    expect(apiError.toString(), isNot(contains('secret')));
  });

  test('turns validation details into an actionable user message', () {
    const error = ApiException(
      statusCode: 422,
      code: 'VALIDATION_ERROR',
      message: 'Request validation failed.',
      validationPaths: ['body.metric_summary.sample_count'],
    );

    expect(
      error.userMessage,
      'Request validation failed. Check: body.metric_summary.sample_count.',
    );
  });

  test('omits an empty bearer token instead of sending an invalid credential',
      () async {
    late http.BaseRequest request;
    final client = ApiClient(
      config: _config(),
      tokenProvider: _FakeTokenProvider(''),
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          '{"uid":"user-1","email":"user@example.com","name":"User"}',
          200,
        );
      }),
    );

    await client.fetchCurrentUser();

    expect(request.headers.containsKey('authorization'), isFalse);
  });

  test('explains when the server is too old for voice calibration metadata',
      () async {
    final client = ApiClient(
      config: _config(),
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"VALIDATION_ERROR","message":"Request validation failed.","trace_id":"trace-2","details":{"errors":[{"loc":["body","voice_calibration"],"msg":"Extra inputs are not permitted","type":"extra_forbidden"}]}}}',
          422,
        ),
      ),
    );

    final error = await catchError(
      () => client.updateVocalPreferences(
        const VocalPreferencesUpdate(
          vocalRange: VocalRange.alto,
          preferredCategories: ['vocal_training'],
          trainingGoal: TrainingGoal.generalSkillBuilding,
          voiceCalibration: VoiceCalibration(
            voiceType: VocalRange.alto,
            confidence: 0.8,
            averageFrequencyHz: 220,
            lowestFrequencyHz: 180,
            highestFrequencyHz: 280,
            sampleCount: 32,
            calibratedAtMs: 1760000000000,
          ),
        ),
      ),
    );

    expect(error, isA<ApiException>());
    final apiError = error as ApiException;
    expect(apiError.code, 'PROFILE_CONTRACT_OUTDATED');
    expect(
      apiError.message,
      'Voice setup finished, but this server is missing the save feature. Start the current local API or ask the administrator to update Cockatiel, then try again.',
    );
    expect(apiError.toString(), isNot(contains('Extra inputs')));
  });
}

Future<Object?> catchError(Future<Object?> Function() operation) async {
  try {
    await operation();
  } catch (error) {
    return error;
  }
  return null;
}
