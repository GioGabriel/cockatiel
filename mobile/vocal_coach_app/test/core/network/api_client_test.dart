import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vocal_coach_app/core/auth/auth_token_provider.dart';
import 'package:vocal_coach_app/core/config/app_config.dart';
import 'package:vocal_coach_app/core/network/api_client.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';
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

  test('sends selected training key, octave, difficulty, and pattern settings',
      () async {
    late http.BaseRequest request;
    final client = ApiClient(
      config: _config(),
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
            '{"session_id":"session-1","status":"started"}', 201);
      }),
    );

    final created = await client.createSession(
      mode: 'training',
      exerciseType: 'warmup_pitch',
      trainingConfig: {
        'difficulty': 'beginner',
        'key': 'D',
        'octave': 4,
        'target_pattern': 'warmup_ladder',
        'pace': 'slow',
        'phrase_mode': 'short',
      },
    );

    final body =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    expect(created.sessionId, 'session-1');
    expect(body['training_config'], {
      'difficulty': 'beginner',
      'key': 'D',
      'octave': 4,
      'target_pattern': 'warmup_ladder',
      'pace': 'slow',
      'phrase_mode': 'short',
    });
  });

  test('saveTrainingAttempt sends the exact compatible voice evidence shape',
      () async {
    late http.BaseRequest request;
    final client = ApiClient(
      config: _config(),
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          '{"session_id":"session-1","attempt":{"attempt_id":"attempt-1","attempt_index":1,"difficulty":"beginner","duration_sec":20,"score":50,"metric_summary":{"metric_mode":"voice","sample_count":24,"pitch_accuracy":50,"timing_accuracy":50,"breath_control":50,"pitch_stability":50,"vibrato_consistency":50,"note_transition_smoothness":50},"saved_at":1,"is_best":true},"selected_best_attempt_id":"attempt-1","best_attempt_score":50}',
          201,
        );
      }),
    );

    final summary = TrainingAttemptMetricSummary.voice(
      sampleCount: 24,
      pitchAccuracy: 50,
      timingAccuracy: 50,
      breathControl: 50,
      pitchStability: 50,
      vibratoConsistency: 50,
      noteTransitionSmoothness: 50,
      evidence: {
        'frame_count': 24,
        'mean_abs_cents': null,
        'p95_abs_cents': null,
        'segments': [
          {
            'segment_id': 'stage-1',
            'mean_abs_cents': null,
            'p95_abs_cents': null,
            'target_frequency_hz': 329.63,
            'pitch_stddev_cents': 18,
            'recommendation': 'Keep the center steady.',
          },
        ],
      },
    );

    await client.saveTrainingAttempt(
      sessionId: 'session-1',
      attemptIndex: 1,
      difficulty: 'beginner',
      durationSec: 20,
      metricSummary: summary,
    );

    final body =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    expect(body, {
      'attempt_index': 1,
      'difficulty': 'beginner',
      'duration_sec': 20,
      'metric_summary': {
        'metric_mode': 'voice',
        'sample_count': 24,
        'pitch_accuracy': 50.0,
        'timing_accuracy': 50.0,
        'breath_control': 50.0,
        'pitch_stability': 50.0,
        'vibrato_consistency': 50.0,
        'note_transition_smoothness': 50.0,
        'evidence': {
          'frame_count': 24,
          'mean_abs_cents': 0.0,
          'p95_abs_cents': 0.0,
          'segments': [
            {
              'segment_id': 'stage-1',
              'mean_abs_cents': 0.0,
              'p95_abs_cents': 0.0,
            },
          ],
        },
      },
    });
  });

  test('force refresh requests bypass the server session-list cache', () async {
    late Uri requestUri;
    final client = ApiClient(
      config: _config(),
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((incoming) async {
        requestUri = incoming.url;
        return http.Response('[]', 200);
      }),
    );

    await client.listSessions(forceRefresh: true);

    expect(requestUri.queryParameters['force_refresh'], 'true');
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
