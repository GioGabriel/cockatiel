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
import 'voice_profile_setup_page.dart';

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
  String? _voiceSetupDismissedForUid;

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
              final profile = widget.appState.currentUser;
              final shouldShowVoiceSetup = profile != null &&
                  profile.vocalPreferences == null &&
                  _voiceSetupDismissedForUid != profile.uid;
              if (shouldShowVoiceSetup) {
                return VoiceProfileSetupPage(
                  appState: widget.appState,
                  apiClient: widget.apiClient,
                  onFinished: () {
                    if (!mounted) return;
                    setState(() {
                      _voiceSetupDismissedForUid = profile.uid;
                    });
                  },
                );
              }
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
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: 'Cockatiel bird, microphone, and waveform',
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          size: 46,
                          color: theme.colorScheme.primary,
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Icon(
                            Icons.mic_rounded,
                            size: 22,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cockatiel',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Voice practice, made clear',
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
