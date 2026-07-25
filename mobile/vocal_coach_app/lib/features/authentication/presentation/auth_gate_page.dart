import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/shell/main_shell_page.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/session_models.dart';
import '../../ai_feedback_display/presentation/feedback_page.dart';
import '../../onboarding/presentation/onboarding_page.dart';
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
  bool _showOnboarding = false;
  bool _onboardingChecked = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
    _notificationTapSub = NotificationService.instance.sessionTapStream.listen(
      _openSessionFeedback,
    );
  }

  Future<void> _bootstrap() async {
    // Check onboarding status in parallel with app state init.
    final onboardingDone = OnboardingPage.hasCompletedOnboarding();
    await widget.appState.initialize(widget.apiClient);
    final completed = await onboardingDone;
    if (!mounted) return;
    setState(() {
      _showOnboarding = !completed;
      _onboardingChecked = true;
    });
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
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
      if (!mounted) {
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
                widget.appState.isBootstrapping ||
                !_onboardingChecked) {
              return const _BootstrappingPage();
            }
            if (_showOnboarding) {
              return OnboardingPage(onComplete: _onOnboardingComplete);
            }
            if (widget.appState.isAuthenticated) {
              return MainShellPage(
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

class _BootstrappingPage extends StatefulWidget {
  const _BootstrappingPage();

  @override
  State<_BootstrappingPage> createState() => _BootstrappingPageState();
}

class _BootstrappingPageState extends State<_BootstrappingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F8FB), Color(0xFFF4F7FB)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Vocal Coach',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your AI-powered singing companion',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
