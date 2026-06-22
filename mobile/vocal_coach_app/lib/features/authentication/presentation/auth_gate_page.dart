import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/session_models.dart';
import '../../ai_feedback_display/presentation/feedback_page.dart';
import '../../home_dashboard/presentation/home_dashboard_page.dart';
import 'authentication_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  late final Future<void> _bootstrapFuture;
  StreamSubscription<String>? _notificationTapSub;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = widget.appState.initialize(widget.apiClient);
    _notificationTapSub = NotificationService.instance.sessionTapStream.listen(
      _openSessionFeedback,
    );
  }

  @override
  void dispose() {
    _notificationTapSub?.cancel();
    super.dispose();
  }

  Future<void> _openSessionFeedback(String sessionId) async {
    if (!mounted || !widget.appState.isAuthenticated) {
      return;
    }

    try {
      final session = await widget.apiClient.fetchSession(sessionId: sessionId);
      CoachingFeedback? feedback = session.feedback;
      if (feedback == null && session.status == 'completed') {
        feedback = await widget.apiClient.fetchFeedback(sessionId: sessionId);
      }
      if (!mounted || feedback == null) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FeedbackPage(
            result: FinalizeResponse(
              sessionId: sessionId,
              status: 'completed',
              feedback: feedback,
            ),
          ),
        ),
      );
    } catch (_) {
      // Ignore notification tap errors and keep app stable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (_, snapshot) {
        return AnimatedBuilder(
          animation: widget.appState,
          builder: (_, __) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                widget.appState.isBootstrapping) {
              return const _BootstrappingPage();
            }
            if (widget.appState.isAuthenticated) {
              return HomeDashboardPage(
                appState: widget.appState,
                apiClient: widget.apiClient,
              );
            }
            return AuthenticationPage(
              appState: widget.appState,
              apiClient: widget.apiClient,
            );
          },
        );
      },
    );
  }
}

class _BootstrappingPage extends StatelessWidget {
  const _BootstrappingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F8FB), Color(0xFFF7F9FC)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Preparing your workspace...'),
            ],
          ),
        ),
      ),
    );
  }
}
