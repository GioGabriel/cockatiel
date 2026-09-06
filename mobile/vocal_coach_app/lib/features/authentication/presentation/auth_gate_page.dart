import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/shell/main_shell_page.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/session_models.dart';
import '../../../shared/widgets/animated_cockatiel_splash.dart';
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
            late final Widget content;
            late final String contentKey;
            if (snapshot.connectionState == ConnectionState.waiting ||
                widget.appState.isBootstrapping ||
                !_onboardingChecked) {
              contentKey = 'bootstrap';
              content = const _BootstrappingPage();
            } else if (_showOnboarding) {
              contentKey = 'onboarding';
              content = OnboardingPage(onComplete: _onOnboardingComplete);
            } else if (widget.appState.isAuthenticated) {
              final profile = widget.appState.currentUser;
              final shouldShowVoiceSetup = profile != null &&
                  profile.vocalPreferences == null &&
                  _voiceSetupDismissedForUid != profile.uid;
              if (shouldShowVoiceSetup) {
                contentKey = 'voice-setup-${profile.uid}';
                content = VoiceProfileSetupPage(
                  appState: widget.appState,
                  apiClient: widget.apiClient,
                  onFinished: () {
                    if (!mounted) return;
                    setState(() {
                      _voiceSetupDismissedForUid = profile.uid;
                    });
                  },
                );
              } else {
                contentKey = 'main-${profile?.uid ?? 'authenticated'}';
                content = MainShellPage(
                  appState: widget.appState,
                  apiClient: widget.apiClient,
                );
              }
            } else {
              contentKey = 'authentication';
              content = AuthenticationPage(
                appState: widget.appState,
                apiClient: widget.apiClient,
              );
            }

            final motionDisabled =
                MediaQuery.maybeOf(context)?.disableAnimations ?? false;
            return AnimatedSwitcher(
              duration: motionDisabled
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offset,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(contentKey),
                child: content,
              ),
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
    return const Scaffold(
      body: AnimatedCockatielSplash(showProgress: true),
    );
  }
}
