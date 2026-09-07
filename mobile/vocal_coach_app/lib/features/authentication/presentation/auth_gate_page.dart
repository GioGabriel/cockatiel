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
  static const _startupTimeout = Duration(seconds: 12);

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
    try {
      // Auth/profile initialization is allowed to continue in the background,
      // but it must not hold the entire app behind an unbounded splash. The
      // auth gate will react when AppState finishes and publish the home shell
      // if a signed-in user becomes available later.
      await widget.appState
          .initialize(widget.apiClient)
          .timeout(_startupTimeout);
    } on TimeoutException {
      // Keep the startup surface usable. AppState owns the eventual auth
      // result and will notify this gate when the in-flight request completes.
    } catch (_) {
      // AppState maps expected auth/API failures to safe user-facing state.
      // A startup exception must still release the splash rather than leaving
      // the user on an infinite loader.
    }

    bool completed = true;
    try {
      completed = await onboardingDone.timeout(
        const Duration(seconds: 3),
        onTimeout: () => true,
      );
    } catch (_) {
      // If local onboarding storage is unavailable, fail open to auth rather
      // than blocking access to the account screen.
      completed = true;
    }
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
      CoachingFeedback? feedback = session.feedbackForDisplay;
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
                !_onboardingChecked) {
              contentKey = 'bootstrap';
              content = const _BootstrappingPage();
            } else if (_showOnboarding) {
              contentKey = 'onboarding';
              content = OnboardingPage(onComplete: _onOnboardingComplete);
            } else if (widget.appState.isAuthenticated) {
              final profile = widget.appState.currentUser;
              final shouldShowVoiceSetup = widget.appState.isProfileReady &&
                  profile != null &&
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
            return SizedBox.expand(
              child: AnimatedSwitcher(
                duration: motionDisabled
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                // The default AnimatedSwitcher layout uses a loose Stack. That
                // lets a startup child shrink to its intrinsic logo/text width
                // while the auth gate is still resolving, which makes the
                // splash appear pinned to the left on wide web viewports.
                // Keep every route state viewport-sized during the transition.
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
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
      body: AnimatedCockatielSplash(),
    );
  }
}
