import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_token_provider.dart';
import '../config/app_config.dart';
import '../../shared/models/analytics_models.dart';
import '../../shared/models/audio_snippet_models.dart';
import '../../shared/models/session_models.dart';
import '../../shared/models/training_models.dart';
import '../../shared/models/karaoke_models.dart';
import '../../shared/models/user_models.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.traceId,
    this.validationPaths = const <String>[],
    this.validationErrorTypes = const <String>[],
  });

  final int statusCode;
  final String code;
  final String message;
  final String? traceId;
  final List<String> validationPaths;
  final List<String> validationErrorTypes;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code, traceId: $traceId)';
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    required AuthTokenProvider tokenProvider,
    http.Client? httpClient,
  })  : _config = config,
        _tokenProvider = tokenProvider,
        _httpClient = _TimeoutClient(
          httpClient ?? http.Client(),
          timeout: const Duration(seconds: 30),
        );

  final AppConfig _config;
  final AuthTokenProvider _tokenProvider;
  final http.Client _httpClient;

  Uri _apiUri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPrefix = _config.apiPrefix.startsWith('/')
        ? _config.apiPrefix
        : '/${_config.apiPrefix}';
    return Uri.parse('${_config.apiBaseUrl}$normalizedPrefix/$path').replace(
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokenProvider.getToken();
    return {
      'Content-Type': 'application/json',
      if (token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
    };
  }

  Future<void> pingBackend() async {
    try {
      await _httpClient
          .get(Uri.parse('${_config.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore keep-alive errors or timeouts during cold start
    }
  }

  Future<SessionCreateResponse> createSession({
    required String mode,
    required String exerciseType,
    Map<String, dynamic>? trainingConfig,
  }) async {
    final payload = <String, dynamic>{
      'mode': mode,
      'exercise_type': exerciseType,
      if (trainingConfig != null) 'training_config': trainingConfig,
    };
    final response = await _httpClient.post(
      _apiUri('sessions'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _throwIfError(response);
    return SessionCreateResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MetricsAcceptedResponse> submitMetrics({
    required String sessionId,
    required List<CanonicalMetricFrame> metrics,
  }) async {
    final payload = {'metrics': metrics.map((item) => item.toJson()).toList()};
    final response = await _httpClient.post(
      _apiUri('sessions/$sessionId/metrics'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _throwIfError(response);
    return MetricsAcceptedResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FinalizeResponse> finalizeSession({required String sessionId}) async {
    final response = await _httpClient.post(
      _apiUri('sessions/$sessionId/finalize'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return FinalizeResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<TrainingAttemptSavedResponse> saveTrainingAttempt({
    required String sessionId,
    required int attemptIndex,
    required String difficulty,
    required int durationSec,
    required TrainingAttemptMetricSummary metricSummary,
  }) async {
    final payload = {
      'attempt_index': attemptIndex,
      'difficulty': difficulty,
      'duration_sec': durationSec,
      'metric_summary': metricSummary.toCreateJson(),
    };

    final response = await _httpClient.post(
      _apiUri('sessions/$sessionId/attempts'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _throwIfError(response);
    return TrainingAttemptSavedResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SessionDetailsResponse> fetchSession(
      {required String sessionId}) async {
    final response = await _httpClient.get(
      _apiUri('sessions/$sessionId'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return SessionDetailsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SessionDetailsResponse>> listSessions() async {
    final response = await _httpClient.get(
      _apiUri('sessions'),
      headers: await _headers(),
    );
    _throwIfError(response);
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) =>
            SessionDetailsResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AIJob>> fetchAIJobs() async {
    final response = await _httpClient.get(
      _apiUri('ai/jobs'),
      headers: await _headers(),
    );
    _throwIfError(response);
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => AIJob.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AIJob> fetchAIJob({required String jobId}) async {
    final response = await _httpClient.get(
      _apiUri('ai/jobs/$jobId'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return AIJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CoachingFeedback> fetchFeedback({required String sessionId}) async {
    final response = await _httpClient.get(
      _apiUri('sessions/$sessionId/feedback'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return CoachingFeedback.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> fetchCurrentUser() async {
    final response = await _httpClient.get(
      _apiUri('auth/me'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return UserProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AnalyticsDashboard> fetchAnalyticsDashboard() async {
    final response = await _httpClient.get(
      _apiUri('analytics/dashboard'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return AnalyticsDashboard.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AnalyticsTrends> fetchAnalyticsTrends({String range = '30d'}) async {
    final uri = _apiUri('analytics/trends', queryParameters: {'range': range});
    final response = await _httpClient.get(
      uri,
      headers: await _headers(),
    );
    _throwIfError(response);
    return AnalyticsTrends.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<TrainingCatalog> fetchTrainingCatalog() async {
    final response = await _httpClient.get(
      _apiUri('training/catalog'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return TrainingCatalog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TrainingProgress> fetchTrainingProgress() async {
    final response = await _httpClient.get(
      _apiUri('training/progress'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return TrainingProgress.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TrainingRecommendations> fetchTrainingRecommendations() async {
    final response = await _httpClient.get(
      _apiUri('training/recommendations'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return TrainingRecommendations.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AudioSnippet> uploadAudioSnippet({
    required String sessionId,
    required String audioBase64,
    required double durationSec,
    String contentType = 'audio/wav',
    int sampleRateHz = 44100,
    int channelCount = 1,
    int? recordedAtMs,
  }) async {
    final payload = {
      'audio_base64': audioBase64,
      'content_type': contentType,
      'duration_sec': durationSec,
      'sample_rate_hz': sampleRateHz,
      'channel_count': channelCount,
      if (recordedAtMs != null) 'recorded_at_ms': recordedAtMs,
    };
    final response = await _httpClient.post(
      _apiUri('sessions/$sessionId/audio-snippets'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _throwIfError(response);
    return AudioSnippet.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AudioSnippetList> fetchAudioSnippets(
      {required String sessionId}) async {
    final response = await _httpClient.get(
      _apiUri('sessions/$sessionId/audio-snippets'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return AudioSnippetList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<KaraokeCatalog> fetchKaraokeCatalog() async {
    final response = await _httpClient.get(
      _apiUri('karaoke/catalog'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return KaraokeCatalog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TrainingProgress> fetchKaraokeProgress() async {
    final response = await _httpClient.get(
      _apiUri('karaoke/progress'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return TrainingProgress.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<KaraokeDrill> fetchKaraokeDrill({required String drillId}) async {
    final response = await _httpClient.get(
      _apiUri('karaoke/catalog/$drillId'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return KaraokeDrill.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UserProfileFull> fetchFullProfile() async {
    final response = await _httpClient.get(
      _apiUri('profile'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return UserProfileFull.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UserProfileFull> updateVocalPreferences(
    VocalPreferencesUpdate prefs,
  ) async {
    final response = await _httpClient.put(
      _apiUri('profile/preferences'),
      headers: await _headers(),
      body: jsonEncode(prefs.toJson()),
    );
    try {
      _throwIfError(response);
    } on ApiException catch (error) {
      if (_isUnsupportedVoiceCalibration(error, prefs)) {
        throw ApiException(
          statusCode: error.statusCode,
          code: 'PROFILE_CONTRACT_OUTDATED',
          message:
              'Voice setup finished, but this server is missing the save feature. Start the current local API or ask the administrator to update Cockatiel, then try again.',
          traceId: error.traceId,
          validationPaths: error.validationPaths,
          validationErrorTypes: error.validationErrorTypes,
        );
      }
      rethrow;
    }
    return UserProfileFull.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UserProfileFull> upgradeToPremium() async {
    final response = await _httpClient.post(
      _apiUri('profile/tier/upgrade'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return UserProfileFull.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static void _throwIfError(http.Response response) {
    if (response.statusCode < 200 || response.statusCode > 299) {
      var code = 'HTTP_${response.statusCode}';
      var message = _fallbackMessage(response.statusCode);
      String? traceId;
      var validationPaths = const <String>[];
      var validationErrorTypes = const <String>[];

      try {
        final decoded = jsonDecode(response.body);
        final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
        if (error is Map<String, dynamic>) {
          final parsedCode = error['code'];
          final parsedMessage = error['message'];
          final parsedTraceId = error['trace_id'];
          if (parsedCode is String && parsedCode.trim().isNotEmpty) {
            code = parsedCode.trim();
          }
          if (parsedMessage is String && parsedMessage.trim().isNotEmpty) {
            message = _limit(parsedMessage.trim(), 240);
          }
          if (parsedTraceId is String && parsedTraceId.trim().isNotEmpty) {
            traceId = _limit(parsedTraceId.trim(), 64);
          }

          final details = error['details'];
          if (details is Map<String, dynamic>) {
            final errors = details['errors'];
            if (errors is List<dynamic>) {
              final paths = <String>{};
              final types = <String>{};
              for (final item in errors) {
                if (item is! Map<String, dynamic>) continue;
                final location = item['loc'];
                if (location is List<dynamic>) {
                  final path = location
                      .whereType<String>()
                      .map((part) => part.trim())
                      .where((part) => part.isNotEmpty)
                      .join('.');
                  if (path.isNotEmpty) paths.add(_limit(path, 120));
                }
                final type = item['type'];
                if (type is String && type.trim().isNotEmpty) {
                  types.add(_limit(type.trim(), 80));
                }
              }
              validationPaths = List.unmodifiable(paths);
              validationErrorTypes = List.unmodifiable(types);
            }
          }
        }
      } on FormatException {
        // Keep the safe status-derived message for non-JSON responses.
      }

      throw ApiException(
        statusCode: response.statusCode,
        code: code,
        message: message,
        traceId: traceId,
        validationPaths: validationPaths,
        validationErrorTypes: validationErrorTypes,
      );
    }
  }

  static String _fallbackMessage(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'The requested resource was not found.';
      case 408:
      case 504:
        return 'The request took too long. Please try again.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      default:
        return 'The server could not complete that request. Please try again.';
    }
  }

  static String _limit(String value, int maxLength) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }

  static bool _isUnsupportedVoiceCalibration(
    ApiException error,
    VocalPreferencesUpdate prefs,
  ) {
    if (prefs.voiceCalibration == null ||
        error.statusCode != 422 ||
        error.code != 'VALIDATION_ERROR' ||
        !error.validationErrorTypes.contains('extra_forbidden')) {
      return false;
    }
    return error.validationPaths.any(
      (path) =>
          path == 'voice_calibration' || path.endsWith('.voice_calibration'),
    );
  }
}

class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner, {required this.timeout});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await _inner.send(request).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        code: 'NETWORK_TIMEOUT',
        message: 'The request took too long. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message:
            'Unable to reach the server. Check your connection and try again.',
      );
    }
  }

  @override
  void close() => _inner.close();
}
