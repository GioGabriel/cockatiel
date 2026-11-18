import 'dart:math' as math;
import 'package:vocal_coach_app/core/audio/live_audio_analyzer.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/warmup_note_explorer_page.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/training_session_page.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/karaoke_singing_page.dart';
import 'package:vocal_coach_app/features/ai_feedback_display/presentation/session_feedback_wait_page.dart';
import 'package:vocal_coach_app/app/shell/main_shell_page.dart';
import 'package:vocal_coach_app/features/user_profile/presentation/voice_calibration_page.dart';
import 'package:vocal_coach_app/features/authentication/presentation/voice_profile_setup_page.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/karaoke_session_setup_page.dart';
import 'dart:async';
import 'package:vocal_coach_app/features/analytics_dashboard/presentation/analytics_dashboard_page.dart';
import 'package:vocal_coach_app/features/history/presentation/practice_history_page.dart';
import 'package:vocal_coach_app/features/user_profile/presentation/user_profile_page.dart';
import 'package:vocal_coach_app/features/ai_feedback_display/presentation/analysis_queue_page.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/practice_plan_page.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/vocal_training_page.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/exercise_briefing_page.dart';
import 'package:vocal_coach_app/features/vocal_training/domain/vocal_coach_catalog.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/karaoke_catalog_page.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/karaoke_song_briefing_page.dart';
import 'package:vocal_coach_app/shared/models/karaoke_models.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

class _PreviewState extends ChangeNotifier implements AppState {
  _PreviewState(
      {this.range = VocalRange.tenor,
      this.jobs = const [],
      this.profileReady = true});
  final bool profileReady;
  final List<AIJob> jobs;
  final VocalRange range;
  int signInRequests = 0;
  int signUpRequests = 0;
  int signOutRequests = 0;
  @override
  void clearAuthMessages() {}
  @override
  Future<void> signInWithEmailPassword(
      {required ApiClient apiClient,
      required String email,
      required String password}) async {
    signInRequests++;
  }

  @override
  Future<void> signUpWithEmailPassword(
      {required ApiClient apiClient,
      required String email,
      required String password,
      required String displayName}) async {
    signUpRequests++;
  }

  @override
  Future<void> signOut() async {
    signOutRequests++;
  }

  @override
  UserProfileFull? get currentUser => UserProfileFull(
      uid: 'preview',
      email: 'singer@example.com',
      name: 'Alex',
      accessTier: AccessTier.registered,
      vocalPreferences: VocalPreferences(
          vocalRange: range,
          preferredCategories: const ['vocal_training'],
          trainingGoal: TrainingGoal.pitchImprovement));
  @override
  bool get isProfileReady => profileReady;
  @override
  List<AIJob> get aiJobs => jobs;
  @override
  bool get isAuthenticated => true;
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
  String? lastRange;
  bool lastForceRefresh = false;
  @override
  Future<AnalyticsDashboard> fetchAnalyticsDashboard() async =>
      AnalyticsDashboard(
          userId: 'preview',
          totalCompletedSessions: 8,
          streakDays: 3,
          avgScore7d: 74,
          generatedAt: 0,
          ranges: {
            for (final range in ['7d', '30d', '90d'])
              range: AnalyticsRange(
                  sessionCount: 8,
                  avgScore: 74,
                  avgPitchAccuracy: 77,
                  avgTimingAccuracy: 73,
                  avgBreathControl: 72,
                  primaryMetrics: [])
          });
  @override
  Future<TrainingRecommendations> fetchTrainingRecommendations() async =>
      TrainingRecommendations(userId: 'preview', generatedAt: 0, items: []);
  @override
  Future<AnalyticsTrends> fetchAnalyticsTrends({String range = '30d'}) async {
    lastRange = range;
    return _trend(range, populated: true);
  }

  @override
  Future<TrainingProgress> fetchTrainingProgress() async =>
      TrainingProgress(userId: 'preview', generatedAt: 0, items: []);
  @override
  Future<TrainingProgress> fetchKaraokeProgress() => fetchTrainingProgress();
  @override
  Future<List<SessionDetailsResponse>> listSessions(
      {bool forceRefresh = false}) async {
    lastForceRefresh = forceRefresh;
    return [];
  }

  @override
  Future<TrainingCatalog> fetchTrainingCatalog() async =>
      TrainingCatalog.fromJson(_fixture('audit_training_catalog'));
  @override
  Future<KaraokeCatalog> fetchKaraokeCatalog() async =>
      KaraokeCatalog.fromJson(_fixture('audit_song_catalog'));
  @override
  Future<SessionDetailsResponse> fetchSession(
          {required String sessionId}) async =>
      SessionDetailsResponse(
          sessionId: sessionId,
          userId: 'preview',
          mode: 'training',
          exerciseType: 'breath_support_ladder',
          status: 'created');
  @override
  Future<UserProfileFull> fetchFullProfile() async =>
      _PreviewState().currentUser!;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecoveryPreviewApi extends _PreviewApi {
  bool unavailable = true;
  int requestCount = 0;
  void _check() {
    requestCount++;
    if (unavailable) {
      throw const ApiException(
          statusCode: 0,
          code: 'NETWORK_ERROR',
          message:
              'We could not connect. Check your internet connection and try again.');
    }
  }

  @override
  Future<AnalyticsDashboard> fetchAnalyticsDashboard() async {
    _check();
    return super.fetchAnalyticsDashboard();
  }

  @override
  Future<TrainingCatalog> fetchTrainingCatalog() async {
    _check();
    return super.fetchTrainingCatalog();
  }

  @override
  Future<KaraokeCatalog> fetchKaraokeCatalog() async {
    _check();
    return super.fetchKaraokeCatalog();
  }

  @override
  Future<UserProfileFull> fetchFullProfile() async {
    _check();
    return super.fetchFullProfile();
  }

  @override
  Future<List<SessionDetailsResponse>> listSessions(
      {bool forceRefresh = false}) async {
    _check();
    return [];
  }
}

class _LoadingPreviewApi extends _PreviewApi {
  static final pending = <Future<void> Function()>[];
  Future<T> _wait<T>(Future<T> Function() result) {
    final gate = Completer<T>();
    pending.add(() async => gate.complete(await result()));
    return gate.future;
  }

  static Future<void> releaseAll() async {
    final callbacks = List.of(pending);
    pending.clear();
    await Future.wait(callbacks.map((complete) => complete()));
  }

  @override
  Future<AnalyticsDashboard> fetchAnalyticsDashboard() =>
      _wait(super.fetchAnalyticsDashboard);
  @override
  Future<TrainingCatalog> fetchTrainingCatalog() =>
      _wait(super.fetchTrainingCatalog);
  @override
  Future<KaraokeCatalog> fetchKaraokeCatalog() =>
      _wait(super.fetchKaraokeCatalog);
  @override
  Future<UserProfileFull> fetchFullProfile() => _wait(super.fetchFullProfile);
}

class _PreviewAnalyzer extends LiveAudioAnalyzer {
  final _frames = StreamController<LiveAudioFrame>.broadcast();
  @override
  Stream<LiveAudioFrame> get frames => _frames.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => _frames.close();
}

class _PreviewSongContent extends KaraokeContentClient {
  @override
  Future<SongLyrics?> fetchLyrics(
          {required String title,
          required String artist,
          required int durationSec}) async =>
      const SongLyrics(
          syncedLyrics:
              '[00:00.00]Find a comfortable note\n[00:03.00]Let your voice flow');
}

class _HistoryPreviewApi extends _PreviewApi {
  @override
  Future<List<SessionDetailsResponse>> listSessions(
          {bool forceRefresh = false}) async =>
      [
        SessionDetailsResponse(
            sessionId: 'saved-take',
            userId: 'preview',
            mode: 'training',
            exerciseType: 'warmup_pitch',
            status: 'completed',
            overallScore: 74,
            createdAt: DateTime(2026, 11, 18, 10).millisecondsSinceEpoch,
            completedAt: DateTime(2026, 11, 18, 10, 5).millisecondsSinceEpoch),
      ];
}

class _DelayedAnalyticsApi extends _PreviewApi {
  final requests = <String, Completer<AnalyticsTrends>>{};
  bool delay = false;

  @override
  Future<AnalyticsTrends> fetchAnalyticsTrends({String range = '30d'}) {
    if (!delay) return super.fetchAnalyticsTrends(range: range);
    return (requests[range] = Completer<AnalyticsTrends>()).future;
  }
}

AnalyticsTrends _trend(String range, {bool populated = false}) =>
    AnalyticsTrends(
        userId: 'preview',
        range: range,
        generatedAt: 0,
        points: populated
            ? [
                for (final day in ['01', '02'])
                  AnalyticsTrendPoint(
                      date: '2026-11-$day',
                      sessionCount: 1,
                      avgScore: 70,
                      avgPitchAccuracy: 70,
                      avgTimingAccuracy: 70,
                      avgBreathControl: 70,
                      primaryMetrics: [])
              ]
            : []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'), (call) async {
      if (['hasPermission', 'isRecording', 'isPaused'].contains(call.method)) {
        return false;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues(
        {'vocal_coach_intro_dismissed': true});
  });
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

  Future<void> showPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: page));
    await tester.pumpAndSettle();
  }

  testWidgets('profile information uses copy affordances for clipboard actions',
      (tester) async {
    await showPage(tester,
        UserProfilePage(appState: _PreviewState(), apiClient: _PreviewApi()));
    expect(find.byIcon(Icons.copy_outlined), findsNWidgets(3));
    await tester.tap(find.text('Display name'));
    await tester.pump();
    expect(find.text('Name copied to clipboard'), findsOneWidget);
  });

  for (final page in ['analytics', 'songs', 'training', 'profile']) {
    testWidgets('$page error can recover after retry', (tester) async {
      final api = _RecoveryPreviewApi();
      final Widget view = switch (page) {
        'analytics' => AnalyticsDashboardPage(apiClient: api),
        'songs' =>
          KaraokeCatalogPage(apiClient: api, appState: _PreviewState()),
        'training' =>
          VocalTrainingPage(apiClient: api, appState: _PreviewState()),
        _ => UserProfilePage(
            apiClient: api, appState: _PreviewState(profileReady: false)),
      };
      await showPage(tester, view);
      final count = api.requestCount;
      api.unavailable = false;
      final retry = page == 'training'
          ? find.byIcon(Icons.refresh_rounded).first
          : find.text('Retry');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(api.requestCount, greaterThan(count));
      expect(find.text('Retry'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('main navigation keeps tabs visible and uses a rail on desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showPage(tester,
        MainShellPage(appState: _PreviewState(), apiClient: _PreviewApi()));
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Songs')));
    await tester.pumpAndSettle();
    expect(find.byType(KaraokeCatalogPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop onboarding keeps the action within a readable column',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showPage(tester, OnboardingPage(onComplete: () {}));
    final action = find.byKey(const ValueKey('onboarding-primary-action'));
    expect(tester.getSize(action).width, lessThanOrEqualTo(440));
    expect(tester.getCenter(action).dx, closeTo(720, 1));
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(1440, 1000)
  ]) {
    for (final view in ['Sign Up', 'Forgot Password?']) {
      testWidgets(
          '$view remains usable at $size with keyboard and enlarged text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(RepaintBoundary(
            key: const Key('auth-mode-capture'),
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark(),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        disableAnimations: true,
                        textScaler:
                            TextScaler.linear(size.width == 320 ? 2 : 1),
                        viewInsets: EdgeInsets.only(
                            bottom: size.width == 320 ? 180 : 0)),
                    child: child!),
                home: AuthenticationPage(
                    appState: _PreviewState(), apiClient: _PreviewApi()))));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(view));
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
        if (size.width != 320 &&
            const bool.fromEnvironment('CAPTURE_PANEL_VISUALS')) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('auth-mode-capture')));
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory(
                '${Directory.systemTemp.path}/cockatiel-panel-previews');
            await directory.create(recursive: true);
            final name = view == 'Sign Up' ? 'sign-up' : 'password-reset';
            await File(
                    '${directory.path}/$name${size.width == 1440 ? '-desktop' : ''}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final submit =
            find.text(view == 'Sign Up' ? 'Create Account' : 'Send Reset Link');
        await tester.ensureVisible(submit);
        expect(tester.getSize(find.byType(TextFormField).first).width,
            lessThanOrEqualTo(420));
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Email is required.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('sign in validates locally before calling authentication',
      (tester) async {
    final state = _PreviewState();
    await showPage(
        tester, AuthenticationPage(appState: state, apiClient: _PreviewApi()));
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(state.signInRequests, 0);
  });

  testWidgets('sign up rejects mismatched passwords without sending a request',
      (tester) async {
    final state = _PreviewState();
    await showPage(
        tester, AuthenticationPage(appState: state, apiClient: _PreviewApi()));
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Alex');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'alex@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'good-password');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'different-password');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(state.signUpRequests, 0);
  });

  testWidgets('password visibility exposes labelled accessible controls',
      (tester) async {
    await showPage(
        tester,
        AuthenticationPage(
            appState: _PreviewState(), apiClient: _PreviewApi()));
    final control = find.byTooltip('Show password');
    expect(control, findsOneWidget);
    await tester.ensureVisible(control);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse);
  });

  testWidgets(
      'song search recovers from no results and opens the selected briefing',
      (tester) async {
    await showPage(
        tester,
        KaraokeCatalogPage(
            appState: _PreviewState(), apiClient: _PreviewApi()));
    await tester.enterText(find.byType(TextField), 'no_matching_song_12345');
    await tester.pumpAndSettle();
    expect(
        find.text('No songs match your search. Try another title or artist.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Open Sky');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Sky Warmup'));
    await tester.pumpAndSettle();
    expect(find.byType(KaraokeSongBriefingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'analytics period uses an accessible button and fetches the chosen range',
      (tester) async {
    final api = _PreviewApi();
    await showPage(tester, AnalyticsDashboardPage(apiClient: api));
    final weekly = find.widgetWithText(TextButton, 'Weekly');
    expect(weekly, findsOneWidget);
    await tester.ensureVisible(weekly);
    await tester.tap(weekly);
    await tester.pumpAndSettle();
    expect(api.lastRange, '7d');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('analytics ignores an older period response after a newer choice',
      (tester) async {
    final api = _DelayedAnalyticsApi();
    await showPage(tester, AnalyticsDashboardPage(apiClient: api));
    api.delay = true;
    await tester.tap(find.widgetWithText(TextButton, 'Weekly'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '90 Days'));
    await tester.pump();
    api.requests['90d']!.complete(_trend('90d'));
    await tester.pumpAndSettle();
    api.requests['7d']!.complete(_trend('7d', populated: true));
    await tester.pumpAndSettle();
    expect(find.text('Score Trend'), findsNothing);
    expect(find.text('No sessions in this period yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('analytics period failure is visible and can be retried',
      (tester) async {
    final api = _DelayedAnalyticsApi();
    await showPage(tester, AnalyticsDashboardPage(apiClient: api));
    api.delay = true;
    await tester.tap(find.widgetWithText(TextButton, 'Weekly'));
    await tester.pump();
    api.requests['7d']!.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load this period. Please try again.'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    api.requests['7d']!.complete(_trend('7d', populated: true));
    await tester.pumpAndSettle();
    expect(find.text('Score Trend'), findsOneWidget);
    expect(find.text('Could not load this period. Please try again.'),
        findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('profile sign out can be cancelled before explicit confirmation',
      (tester) async {
    final state = _PreviewState();
    await showPage(
        tester, UserProfilePage(appState: state, apiClient: _PreviewApi()));
    await tester.scrollUntilVisible(find.text('Sign Out'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.signOutRequests, 0);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(state.signOutRequests, 1);
  });

  testWidgets(
      'exercise setup preserves mezzo profile and offers all six ranges',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: ExerciseBriefingPage(
            categoryTitle: 'Vocal Training',
            exercise: vocalCoachCatalog.first.exercises.first,
            apiClient: _PreviewApi(),
            appState: _PreviewState(range: VocalRange.mezzoSoprano))));
    await tester.pumpAndSettle();
    for (final label in [
      'Soprano',
      'Mezzo-Soprano',
      'Alto',
      'Tenor',
      'Baritone',
      'Bass'
    ]) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    final mezzo = tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mezzo-Soprano'));
    expect(mezzo.selected, isTrue);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Soprano'))
            .selected,
        isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  final screens = <String, Widget Function()>{
    'analytics-error': () =>
        AnalyticsDashboardPage(apiClient: _RecoveryPreviewApi()),
    'songs-error': () => KaraokeCatalogPage(
        apiClient: _RecoveryPreviewApi(), appState: _PreviewState()),
    'training-fallback': () => VocalTrainingPage(
        apiClient: _RecoveryPreviewApi(), appState: _PreviewState()),
    'profile-error': () => UserProfilePage(
        apiClient: _RecoveryPreviewApi(),
        appState: _PreviewState(profileReady: false)),
    'history-error': () => PracticeHistoryPage(
        apiClient: _RecoveryPreviewApi(), appState: _PreviewState()),
    'analytics-loading': () =>
        AnalyticsDashboardPage(apiClient: _LoadingPreviewApi()),
    'songs-loading': () => KaraokeCatalogPage(
        apiClient: _LoadingPreviewApi(), appState: _PreviewState()),
    'training-loading': () => VocalTrainingPage(
        apiClient: _LoadingPreviewApi(), appState: _PreviewState()),
    'profile-loading': () => UserProfilePage(
        apiClient: _LoadingPreviewApi(),
        appState: _PreviewState(profileReady: false)),
    'note-explorer': () => const WarmupNoteExplorerPage(
        tonicKey: 'C', octave: 4, analyzerFactory: _PreviewAnalyzer.new),
    'training-session': () => TrainingSessionPage(
        apiClient: _PreviewApi(),
        appState: _PreviewState(),
        mode: 'training',
        exerciseType: 'breath_support_ladder',
        sessionId: 'preview',
        exerciseInstructions: const ['Breathe gently and follow the guide.']),
    'song-session': () => KaraokeSingingPage(
        apiClient: _PreviewApi(),
        appState: _PreviewState(),
        sessionId: 'preview',
        drill: KaraokeCatalog.fromJson(_fixture('audit_song_catalog'))
            .categories
            .first
            .drills
            .first,
        contentClient: _PreviewSongContent()),
    'review-wait': () => SessionFeedbackWaitPage(
        loadReview: () async =>
            FinalizeResponse(sessionId: 'preview', status: 'processing'),
        onOpenQueue: () {}),
    'history-saved': () => PracticeHistoryPage(
        apiClient: _HistoryPreviewApi(), appState: _PreviewState()),
    'review-queue-active': () => AnalysisQueuePage(
        apiClient: _PreviewApi(),
        appState: _PreviewState(jobs: [
          AIJob(
              jobId: 'review',
              sessionId: 'saved-take',
              state: 'processing',
              attempt: 0,
              maxAttempts: 3,
              queuedAt: 0,
              updatedAt: 0,
              mode: 'training',
              exerciseType: 'warmup_pitch')
        ])),
    'navigation-shell': () =>
        MainShellPage(appState: _PreviewState(), apiClient: _PreviewApi()),
    'voice-calibration': () => const VoiceCalibrationPage(),
    'voice-setup': () => VoiceProfileSetupPage(
        appState: _PreviewState(), apiClient: _PreviewApi(), onFinished: () {}),
    'song-setup': () => KaraokeSessionSetupPage(
        appState: _PreviewState(),
        apiClient: _PreviewApi(),
        title: 'Song setup',
        exerciseOptions: const ['Open Sky Warmup', 'Acoustic Pitch Ladder']),
    'analytics': () => AnalyticsDashboardPage(apiClient: _PreviewApi()),
    'history': () => PracticeHistoryPage(
        apiClient: _PreviewApi(), appState: _PreviewState()),
    'profile': () =>
        UserProfilePage(apiClient: _PreviewApi(), appState: _PreviewState()),
    'review-queue': () =>
        AnalysisQueuePage(apiClient: _PreviewApi(), appState: _PreviewState()),
    'practice-plan': () => PracticePlanPage(onTrain: () {}, onSong: () {}),
    'training-catalog': () =>
        VocalTrainingPage(apiClient: _PreviewApi(), appState: _PreviewState()),
    'exercise-briefing': () => ExerciseBriefingPage(
        categoryTitle: 'Vocal Training',
        exercise: vocalCoachCatalog.first.exercises.first,
        apiClient: _PreviewApi(),
        appState: _PreviewState()),
    'song-catalog': () =>
        KaraokeCatalogPage(apiClient: _PreviewApi(), appState: _PreviewState()),
    'song-briefing': () => KaraokeSongBriefingPage(
        drill: KaraokeCatalog.fromJson(_fixture('audit_song_catalog'))
            .categories
            .first
            .drills
            .first,
        apiClient: _PreviewApi(),
        appState: _PreviewState()),
    'home': () =>
        HomeDashboardPage(appState: _PreviewState(), apiClient: _PreviewApi()),
    'sign-in': () =>
        AuthenticationPage(appState: _PreviewState(), apiClient: _PreviewApi()),
    'voice-profile': () => VocalPreferencesPage(apiClient: _PreviewApi()),
    'onboarding': () => OnboardingPage(onComplete: () {}),
    'onboarding-pitch': () => OnboardingPage(onComplete: () {}),
    'onboarding-song': () => OnboardingPage(onComplete: () {}),
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
  Future<void> captureDetail(
      WidgetTester tester, String name, double width) async {
    if (width == 320 || !const bool.fromEnvironment('CAPTURE_PANEL_VISUALS')) {
      return;
    }
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('detail-capture')));
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output =
          Directory('${Directory.systemTemp.path}/cockatiel-panel-previews');
      await output.create(recursive: true);
      await File('${output.path}/$name${width == 1440 ? '-desktop' : ''}.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    Future<void> showDetail(WidgetTester tester, Widget view) async {
      tester.view.physicalSize = Size(
          width,
          width == 320
              ? 568
              : width == 1440
                  ? 1000
                  : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepaintBoundary(
          key: const Key('detail-capture'),
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(width == 320 ? 2 : 1)),
                  child: child!),
              home: view)));
      await tester.pumpAndSettle();
    }

    testWidgets('training category opens its exercise briefing at width $width',
        (tester) async {
      await showDetail(
          tester,
          VocalTrainingPage(
              apiClient: _PreviewApi(), appState: _PreviewState()));
      final tracks = find.widgetWithText(OutlinedButton, 'Explore exercises');
      for (var attempt = 0;
          attempt < 20 && tracks.evaluate().isEmpty;
          attempt++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(tracks, findsWidgets);
      final track = tracks.first;
      await tester.ensureVisible(track);
      await tester.pumpAndSettle();
      expect(track.hitTestable(), findsOneWidget);
      await tester.tap(track);
      await tester.pumpAndSettle();
      final name = TrainingCatalog.fromJson(_fixture('audit_training_catalog'))
          .categories
          .first
          .exercises
          .first
          .name;
      await tester.scrollUntilVisible(find.text(name), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text(name), findsWidgets);
      expect(tester.takeException(), isNull);
      await captureDetail(tester, 'exercise-library', width);
      await tester.ensureVisible(find.text(name).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).first);
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseBriefingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('expanded coaching details remain readable at width $width',
        (tester) async {
      await showDetail(tester, screens['feedback']!());
      await tester.scrollUntilVisible(find.text('Read full feedback'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Read full feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read full feedback'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Strengths'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Your notes stayed steady.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureDetail(tester, 'coaching-details', width);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final screen in screens.entries) {
    for (final scenario in [
      (320.0, 844.0, 1.0),
      (390.0, 844.0, 1.0),
      (320.0, 568.0, 2.0),
      (844.0, 390.0, 1.3),
      (768.0, 1024.0, 1.0),
      (1440.0, 1000.0, 1.0)
    ]) {
      final (width, height, textScale) = scenario;
      testWidgets(
          '${screen.key} usable at ${width.toInt()}x${height.toInt()} text $textScale',
          (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await _LoadingPreviewApi.releaseAll();
          await tester.pump();
        });
        const capture = Key('client-screen-capture');
        await tester.pumpWidget(RepaintBoundary(
            key: capture,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark(),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(textScale),
                        disableAnimations: true),
                    child: child!),
                home: screen.value())));
        await tester.runAsync(() => precacheImage(
            const AssetImage('assets/images/auth_3d_elements.jpg'),
            tester.element(find.byType(Scaffold).first)));
        if (screen.key.endsWith('-loading') ||
            ['review-wait', 'song-session'].contains(screen.key)) {
          await tester.pump(const Duration(milliseconds: 500));
        } else {
          await tester.pumpAndSettle();
        }
        if (screen.key.startsWith('onboarding-')) {
          final steps = screen.key == 'onboarding-song' ? 2 : 1;
          for (var step = 0; step < steps; step++) {
            await tester
                .tap(find.byKey(const ValueKey('onboarding-primary-action')));
            await tester.pumpAndSettle();
          }
        }
        if (screen.key == 'song-session') {
          expect(find.text('Cockatiel Practice Library'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        if (width == 1440 &&
            !screen.key.startsWith('onboarding') &&
            !['sign-in', 'onboarding', 'navigation-shell']
                .contains(screen.key)) {
          final scrolls = find.byType(Scrollable);
          if (scrolls.evaluate().isNotEmpty) {
            expect(tester.getSize(scrolls.first).width, lessThanOrEqualTo(1040),
                reason: '${screen.key} needs a bounded desktop reading area');
          }
        }
        if ((width == 390 || width == 1440) &&
            textScale == 1 &&
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
            await File(
                    '${output.path}/${screen.key}${width == 1440 ? '-desktop' : ''}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Visit lower content too; off-screen slivers can hide layout errors.
        if (width == 390 || textScale == 2) {
          final vertical = find.byType(Scrollable).evaluate().where((element) =>
              [AxisDirection.down, AxisDirection.up]
                  .contains((element.widget as Scrollable).axisDirection));
          if (vertical.isNotEmpty) {
            final state = vertical.first as StatefulElement;
            final scroll = state.state as ScrollableState;
            for (var step = 0;
                step < 30 && scroll.position.extentAfter > 1;
                step++) {
              final next = math.min(
                  scroll.position.maxScrollExtent,
                  scroll.position.pixels +
                      scroll.position.viewportDimension * .8);
              if (next <= scroll.position.pixels) break;
              scroll.position.jumpTo(next);
              await tester.pump(const Duration(milliseconds: 100));
              expect(tester.takeException(), isNull,
                  reason: '${screen.key} lower content at scroll step $step');
            }
          }
        }
        if (screen.key.endsWith('-loading')) {
          await tester.pumpWidget(const SizedBox.shrink());
          await _LoadingPreviewApi.releaseAll();
          await tester.pump();
        }
      });
    }
  }
}
