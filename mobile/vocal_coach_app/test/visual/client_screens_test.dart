import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/app/theme/app_theme.dart';
import 'package:vocal_coach_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:vocal_coach_app/features/ai_feedback_display/presentation/feedback_page.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';
import 'package:vocal_coach_app/shared/widgets/practice_focus.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/widgets/karaoke_pitch_visualizer.dart';

import 'package:vocal_coach_app/features/home_dashboard/presentation/home_dashboard_page.dart';
import 'package:vocal_coach_app/features/authentication/presentation/authentication_page.dart';
import 'package:vocal_coach_app/features/user_profile/presentation/vocal_preferences_page.dart';
import 'package:vocal_coach_app/core/state/app_state.dart';
import 'package:vocal_coach_app/core/network/api_client.dart';
import 'package:vocal_coach_app/shared/models/user_models.dart';
import 'package:vocal_coach_app/shared/models/analytics_models.dart';
import 'package:vocal_coach_app/shared/models/training_models.dart';

class _PreviewState extends ChangeNotifier implements AppState {
  @override
  UserProfileFull? get currentUser => const UserProfileFull(
      uid: 'preview',
      email: 'singer@example.com',
      name: 'Alex',
      accessTier: AccessTier.registered);
  @override
  int get pendingAIJobsCount => 0;
  @override
  String? get accountDataNotice => null;
  @override
  bool get isAuthenticating => false;
  @override
  bool get isSendingPasswordReset => false;
  @override
  String? get authError => null;
  @override
  String? get authNotice => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewApi implements ApiClient {
  @override
  Future<AnalyticsDashboard> fetchAnalyticsDashboard() async =>
      AnalyticsDashboard(
          userId: 'preview',
          totalCompletedSessions: 8,
          streakDays: 3,
          avgScore7d: 74,
          generatedAt: 0,
          ranges: {});
  @override
  Future<TrainingRecommendations> fetchTrainingRecommendations() async =>
      TrainingRecommendations(userId: 'preview', generatedAt: 0, items: []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final family in ['Inter', 'Outfit']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family.ttf')))
          .load();
    }
  });
  final screens = <String, Widget Function()>{
    'home': () =>
        HomeDashboardPage(appState: _PreviewState(), apiClient: _PreviewApi()),
    'sign-in': () =>
        AuthenticationPage(appState: _PreviewState(), apiClient: _PreviewApi()),
    'voice-profile': () => VocalPreferencesPage(apiClient: _PreviewApi()),
    'onboarding': () => OnboardingPage(onComplete: () {}),
    'feedback': () => FeedbackPage(
        result: FinalizeResponse(
            sessionId: 'preview',
            status: 'completed',
            feedback: CoachingFeedback(
                sessionId: 'preview',
                overallScore: 74,
                strengths: ['Your notes stayed steady.'],
                improvements: [
                  'Give each note a little more time before moving on.'
                ],
                nextExercises: ['Slow three-note matching'],
                modelUsed: 'coaching-logic-engine',
                summary:
                    'A steady start. Focus on a gentle, accurate landing on each note.'))),
    'practice': () => PracticeFocus(
        title: 'Pitch matching',
        finishLabel: 'Stop take',
        cue: 'Sing Do gently',
        secondsRemaining: 16,
        progress: .2,
        onFinish: () {},
        visual: KaraokePitchVisualizer(
            stages: [
              TrainingRuntimeStage(
                  stageId: 'do',
                  title: 'Do',
                  targetLabel: '261.63',
                  instruction: 'Hum gently',
                  durationSec: 2,
                  startSec: 0,
                  endSec: 2)
            ],
            currentElapsedSec: .5,
            pitchHistory: const [PitchPoint(.1, 255), PitchPoint(.3, 261)],
            minHz: 130,
            maxHz: 520,
            getTargetFrequency: double.tryParse,
            isRunning: true,
            targetLabel: 'Do',
            detectedFrequencyHz: 261.63,
            detectedNoteLabel: 'C4',
            detectedCents: 0)),
  };
  for (final screen in screens.entries) {
    for (final width in [320.0, 390.0]) {
      testWidgets('${screen.key} stays usable at ${width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
        });
        const capture = Key('client-screen-capture');
        await tester.pumpWidget(RepaintBoundary(
            key: capture,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark(),
                home: screen.value())));
        await tester.runAsync(() => precacheImage(
            const AssetImage('assets/images/auth_3d_elements.jpg'),
            tester.element(find.byType(Scaffold).first)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 390 &&
            const bool.fromEnvironment('CAPTURE_PANEL_VISUALS')) {
          await tester.runAsync(() async {
            final boundary =
                tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final output = Directory(
                '${Directory.systemTemp.path}/cockatiel-panel-previews');
            await output.create(recursive: true);
            await File('${output.path}/${screen.key}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
