import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_token_provider.dart';
import '../config/app_config.dart';
import '../../shared/models/analytics_models.dart';
import '../../shared/models/audio_snippet_models.dart';
import '../../shared/models/session_models.dart';
import '../../shared/models/training_models.dart';
import '../../shared/models/user_models.dart';

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    required AuthTokenProvider tokenProvider,
    http.Client? httpClient,
  })  : _config = config,
        _tokenProvider = tokenProvider,
        _httpClient = httpClient ?? http.Client();

  final AppConfig _config;
  final AuthTokenProvider _tokenProvider;
  final http.Client _httpClient;

  Future<Map<String, String>> _headers() async {
    final token = await _tokenProvider.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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
      Uri.parse('${_config.apiBaseUrl}/v1/sessions'),
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
      Uri.parse('${_config.apiBaseUrl}/v1/sessions/$sessionId/metrics'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _throwIfError(response);
    return MetricsAcceptedResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FinalizeResponse> finalizeSession({required String sessionId}) async {
    final response = await _httpClient.post(
      Uri.parse('${_config.apiBaseUrl}/v1/sessions/$sessionId/finalize'),
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
      Uri.parse('${_config.apiBaseUrl}/v1/sessions/$sessionId/attempts'),
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
      Uri.parse('${_config.apiBaseUrl}/v1/sessions/$sessionId'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return SessionDetailsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AIJob>> fetchAIJobs() async {
    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/v1/ai/jobs'),
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
      Uri.parse('${_config.apiBaseUrl}/v1/ai/jobs/$jobId'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return AIJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CoachingFeedback> fetchFeedback({required String sessionId}) async {
    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/v1/sessions/$sessionId/feedback'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return CoachingFeedback.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> fetchCurrentUser() async {
    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/v1/auth/me'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return UserProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AnalyticsDashboard> fetchAnalyticsDashboard() async {
    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/v1/analytics/dashboard'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return AnalyticsDashboard.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AnalyticsTrends> fetchAnalyticsTrends({String range = '30d'}) async {
    final uri = Uri.parse('${_config.apiBaseUrl}/v1/analytics/trends').replace(
      queryParameters: {'range': range},
    );
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
      Uri.parse('${_config.apiBaseUrl}/v1/training/catalog'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return TrainingCatalog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TrainingProgress> fetchTrainingProgress() async {
    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/v1/training/progress'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return TrainingProgress.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TrainingRecommendations> fetchTrainingRecommendations() async {
    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/v1/training/recommendations'),
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
      Uri.parse('${_config.apiBaseUrl}/v1/sessions/$sessionId/audio-snippets'),
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
      Uri.parse('${_config.apiBaseUrl}/v1/sessions/$sessionId/audio-snippets'),
      headers: await _headers(),
    );
    _throwIfError(response);
    return AudioSnippetList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  static void _throwIfError(http.Response response) {
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiException(statusCode: response.statusCode, body: response.body);
    }
  }
}
