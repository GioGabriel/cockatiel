import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'ai_feedback_updates';
  static const _channelName = 'AI Feedback Updates';
  static const _channelDescription = 'Notifies when AI analysis finishes.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _sessionTapController =
      StreamController<String>.broadcast();

  bool _initialized = false;

  Stream<String> get sessionTapStream => _sessionTapController.stream;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  Future<void> showAnalysisCompleted({
    required String sessionId,
    required String exerciseType,
  }) async {
    await initialize();
    await _plugin.show(
      sessionId.hashCode,
      'Feedback ready',
      'Your $exerciseType analysis is complete. Tap to open.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'session:$sessionId',
    );
  }

  Future<void> showAnalysisFailed({
    required String sessionId,
    required String exerciseType,
  }) async {
    await initialize();
    await _plugin.show(
      sessionId.hashCode ^ 0xFF,
      'Analysis failed',
      'Your $exerciseType analysis failed. Tap to review.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'session:$sessionId',
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('session:')) {
      return;
    }
    final sessionId = payload.substring('session:'.length).trim();
    if (sessionId.isEmpty) {
      return;
    }
    _sessionTapController.add(sessionId);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.instance._onNotificationTap(response);
}
