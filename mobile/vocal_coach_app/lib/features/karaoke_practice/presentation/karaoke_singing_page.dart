import 'package:vocal_coach_app/shared/widgets/studio_scaffold.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../../../core/audio/live_audio_analyzer.dart';
import '../../../core/audio/pitch/live_pitch_guidance.dart';
import '../../../core/network/api_client.dart';
import '../../../core/scoring/vocal_metric_scorer.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/karaoke_models.dart';
import '../../../shared/models/session_models.dart';
import '../../../shared/utils/vocal_utils.dart';
import '../../../shared/widgets/audio_waveform_visualizer.dart';
import '../../ai_feedback_display/presentation/analysis_queue_page.dart';
import '../../vocal_training/presentation/widgets/karaoke_pitch_visualizer.dart';
import 'widgets/lyric_scroller.dart';
import '../domain/song_content_parser.dart';
import '../domain/song_practice_review.dart';
import '../../ai_feedback_display/presentation/feedback_page.dart';
import '../../ai_feedback_display/presentation/session_feedback_wait_page.dart';
import '../../../shared/widgets/voice_studio.dart';

bool _isUsableKaraokeFrequency(double? frequencyHz) {
  return frequencyHz != null && frequencyHz.isFinite && frequencyHz > 0;
}

class KaraokeSingingPage extends StatefulWidget {
  const KaraokeSingingPage({
    super.key,
    required this.apiClient,
    required this.appState,
    required this.drill,
    required this.sessionId,
    this.contentClient,
  });

  final ApiClient apiClient;
  final AppState appState;
  final KaraokeDrill drill;
  final String sessionId;
  final KaraokeContentClient? contentClient;

  @override
  State<KaraokeSingingPage> createState() => _KaraokeSingingPageState();
}

class _KaraokeSingingPageState extends State<KaraokeSingingPage> {
  final AudioPlayer _player = AudioPlayer();
  late final LiveAudioAnalyzer _analyzer;
  late final VocalMetricAccumulator _metricAccumulator;
  late final LivePitchGuidanceController _pitchGuidance;
  late final KaraokeContentClient _contentClient;
  late final bool _ownsContentClient;
  StreamSubscription<LiveAudioFrame>? _audioSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _micOnlyTimer;
  final Stopwatch _micOnlyStopwatch = Stopwatch();

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isFinishing = false;
  String? _reviewError;
  bool _requiresNewTake = false;
  final _review = SongPracticeReviewController();
  String? _error;
  List<String> _contentNotices = const [];
  bool _hasInstrumentalAudio = false;

  List<LyricLine> _lyrics = [];
  String? _plainLyrics;
  List<TrainingRuntimeStage> _stages = [];

  final List<PitchPoint> _pitchHistory = [];

  Duration _currentPosition = Duration.zero;
  double _liveAmplitude = 0;
  double? _liveFrequencyHz;
  double? _liveCentsError;
  String _liveCoachCue = 'Press start when you are ready.';

  @override
  void initState() {
    super.initState();
    _analyzer = LiveAudioAnalyzer(
      minFrequencyHz: defaultLivePitchMinFrequencyHz,
      // Keep the live detector wide enough for the upper end of a valid song
      // map; target-relative guidance still decides whether the note is right.
      maxFrequencyHz: defaultLivePitchMaxFrequencyHz,
    );
    _metricAccumulator = VocalMetricAccumulator();
    _pitchGuidance = LivePitchGuidanceController();
    _contentClient = widget.contentClient ?? KaraokeContentClient();
    _ownsContentClient = widget.contentClient == null;
    _initializeKaraoke();
  }

  Future<void> _initializeKaraoke() async {
    try {
      final notices = <String>[];

      final lyricContent = await _contentClient.fetchLyrics(
        title: widget.drill.title,
        artist: widget.drill.artistName,
        durationSec: widget.drill.durationSec,
      );
      if (!mounted) return;
      if (lyricContent?.syncedLyrics != null) {
        _lyrics = parseSongLyrics(lyricContent!.syncedLyrics!);
      }
      _plainLyrics = lyricContent?.plainLyrics;
      if (_lyrics.isEmpty && _plainLyrics == null) {
        notices.add(
            'Synchronized lyrics are unavailable. You can still follow the pitch guide.');
      }

      if (widget.drill.pitchMapUrl.isNotEmpty) {
        final decoded =
            await _contentClient.fetchPitchMap(widget.drill.pitchMapUrl);
        if (!mounted) return;
        _stages = parseSongPitchMap(decoded);
      }
      if (_stages.isEmpty) {
        notices.add(
            'A pitch guide is unavailable for this song. Live microphone feedback is still active.');
      }

      if (widget.drill.instrumentalUrl.isNotEmpty) {
        try {
          await _player
              .setUrl(widget.drill.instrumentalUrl)
              .timeout(const Duration(seconds: 12));
          _hasInstrumentalAudio = true;
        } catch (_) {
          notices.add(
              'Instrumental audio could not be loaded. Mic-only practice is available.');
        }
      } else {
        notices.add(
            'Instrumental audio is unavailable. Mic-only practice is available.');
      }

      if (!mounted) return;
      _positionSub = _player.positionStream.listen((pos) {
        if (mounted) setState(() => _currentPosition = pos);
      });

      _playerStateSub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _finishSession();
        }
      });

      if (!mounted) return;
      setState(() {
        _contentNotices = notices;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'We could not load this song right now. Please return and try another song.';
        _isLoading = false;
      });
    }
  }

  void _startMicOnlyClock() {
    _micOnlyTimer?.cancel();
    _micOnlyStopwatch
      ..reset()
      ..start();
    _micOnlyTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_micOnlyStopwatch.isRunning) return;
      setState(() {
        _currentPosition = _micOnlyStopwatch.elapsed;
      });
    });
  }

  void _stopMicOnlyClock() {
    _micOnlyTimer?.cancel();
    _micOnlyTimer = null;
    _micOnlyStopwatch.stop();
  }

  TrainingRuntimeStage? _currentStage(double elapsedSec) {
    for (var stage in _stages) {
      if (elapsedSec >= stage.startSec && elapsedSec < stage.endSec) {
        return stage;
      }
    }
    return null;
  }

  TrainingAttemptMetricSummary _buildAttemptMetricSummary() {
    return _metricAccumulator.build().toTrainingAttemptMetricSummary();
  }

  Future<void> _startSinging() async {
    if (_isPlaying || _isFinishing) return;
    _stopMicOnlyClock();
    _currentPosition = Duration.zero;
    _pitchHistory.clear();
    setState(() {
      _isPlaying = true;
      _liveCoachCue = 'Listening for your voice...';
      _liveCentsError = null;
      _liveFrequencyHz = null;
    });

    _metricAccumulator.reset();
    _pitchGuidance.reset();

    try {
      await _analyzer.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _error =
            'Microphone access is unavailable. Check permission and try again.';
      });
      return;
    }
    if (!mounted) {
      await _analyzer.stop();
      return;
    }
    _audioSub = _analyzer.frames.listen((frame) {
      final elapsed = _currentPosition.inMilliseconds / 1000.0;
      final currentStage = _currentStage(elapsed);
      final targetHz = currentStage == null
          ? null
          : (currentStage.target.frequencyHz ??
              frequencyHzForPitchLabel(
                currentStage.targetLabel,
                key: currentStage.target.key,
                octave: currentStage.target.octave,
              ));
      final measuredFrequencyHz = _isUsableKaraokeFrequency(frame.frequencyHz)
          ? frame.frequencyHz
          : null;
      final frameIsVoiced = frame.voiced && measuredFrequencyHz != null;
      double? centsError;
      if (frameIsVoiced && targetHz != null) {
        centsError = centsErrorForFrequencies(measuredFrequencyHz, targetHz);
      }
      final guidance = _pitchGuidance.update(
        isAttemptRunning: true,
        hasTarget: targetHz != null,
        voiced: frameIsVoiced,
        confidence: frame.confidence,
        loudnessDb: frame.loudnessDb,
        centsError: centsError ?? 0,
        clippingRatio: frame.clippingRatio ?? 0,
      );
      final normalizedAmplitude =
          ((frame.loudnessDb + 60) / 60).clamp(0.0, 1.0);

      if (mounted) {
        setState(() {
          _liveAmplitude = normalizedAmplitude;
          _liveCentsError = centsError;
          _liveFrequencyHz =
              _pitchGuidance.lastFrameMeasurable ? measuredFrequencyHz : null;
          _liveCoachCue = guidance.message;

          final pitchToDisplay =
              _pitchGuidance.lastFrameMeasurable && measuredFrequencyHz != null
                  ? measuredFrequencyHz
                  : 0.0;
          _pitchHistory.add(PitchPoint(elapsed, pitchToDisplay));
          if (_pitchHistory.length > 250) _pitchHistory.removeAt(0);
        });
      }

      _metricAccumulator.addFrame(
        VocalMetricFrame(
          timestampMs: frame.timestampMs,
          targetId: currentStage?.stageId,
          targetLabel: currentStage?.targetLabel,
          targetFrequencyHz: targetHz,
          frequencyHz: measuredFrequencyHz,
          loudnessDb: frame.loudnessDb,
          voiced: frameIsVoiced && _pitchGuidance.lastFrameMeasurable,
          confidence: frame.confidence,
        ),
      );
    });

    if (!_hasInstrumentalAudio) {
      _startMicOnlyClock();
    }

    if (_hasInstrumentalAudio) {
      try {
        await _player.play();
      } catch (_) {
        if (mounted) {
          setState(() {
            _hasInstrumentalAudio = false;
            _contentNotices = [
              ..._contentNotices,
              'Instrumental audio stopped unexpectedly. Mic-only practice is still active.',
            ];
          });
          _startMicOnlyClock();
        }
      }
    }
  }

  Future<void> _finishSession() async {
    if (_isFinishing) return;
    _isFinishing = true;

    final elapsedSec = _currentPosition.inSeconds;
    _stopMicOnlyClock();
    setState(() {
      _isPlaying = false;
      _isLoading = true;
    });
    try {
      await _player.stop();
      await _audioSub?.cancel();
      _audioSub = null;
      await _analyzer.stop();
      if (!mounted) return;
      if (elapsedSec < 10) {
        throw const ApiException(
            statusCode: 422,
            code: 'TAKE_TOO_SHORT',
            message:
                'This take was shorter than 10 seconds. Start a new take when you feel ready.');
      }
      final summary = _buildAttemptMetricSummary();
      final totalSec = elapsedSec.clamp(10, 600);

      final result = await _review.submit(
        saveAttempt: () async {
          await widget.apiClient.saveTrainingAttempt(
              sessionId: widget.sessionId,
              attemptIndex: 1,
              difficulty: widget.drill.difficulty,
              durationSec: totalSec,
              metricSummary: summary);
        },
        finalize: () =>
            widget.apiClient.finalizeSession(sessionId: widget.sessionId),
      );
      unawaited(widget.appState.refreshAIJobs().catchError((_) {}));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (reviewContext) => result.feedback != null
              ? FeedbackPage(result: result)
              : SessionFeedbackWaitPage(
                  loadReview: () async {
                    final session = await widget.apiClient
                        .fetchSession(sessionId: widget.sessionId);
                    return FinalizeResponse(
                        sessionId: widget.sessionId,
                        status: session.status,
                        feedback: session.feedbackForDisplay);
                  },
                  onOpenQueue: () => Navigator.of(reviewContext)
                      .pushReplacement(MaterialPageRoute(
                          builder: (_) => AnalysisQueuePage(
                              apiClient: widget.apiClient,
                              appState: widget.appState))),
                )));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFinishing = false;
        _isLoading = false;
        _requiresNewTake = error is ApiException &&
            const {'TAKE_TOO_SHORT', 'INSUFFICIENT_AUDIO_EVIDENCE'}
                .contains(error.code);
        _reviewError = error is ApiException
            ? error.message
            : 'Your take is still here. Try saving the review again.';
      });
    }
  }

  @override
  void dispose() {
    _stopMicOnlyClock();
    _player.dispose();
    _analyzer.dispose();
    _audioSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    if (_ownsContentClient) _contentClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return StudioScaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return StudioScaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text(
            _error!,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StudioScaffold(
      appBar: AppBar(
          title: Text(widget.drill.title,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: VoiceStageBackground(
          child: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(widget.drill.artistName, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              SizedBox(
                  height: (constraints.maxHeight * .5).clamp(240, 420),
                  child: LyricScroller(
                      lyrics: _lyrics,
                      isPlaying: _isPlaying,
                      songDuration: Duration(seconds: widget.drill.durationSec),
                      plainLyrics: _plainLyrics,
                      currentPosition: _currentPosition,
                      emptyMessage:
                          'Synchronized lyrics are unavailable. Follow the pitch guide or practice by ear.')),
              ExpansionTile(
                  title: const Text('Pitch guide (optional)'),
                  children: [
                    SizedBox(
                        height: (constraints.maxHeight * .43).clamp(240, 420) +
                            120 *
                                (MediaQuery.textScalerOf(context).scale(1) - 1)
                                    .clamp(0, 2),
                        child: KaraokePitchVisualizer(
                            stages: _stages,
                            currentElapsedSec:
                                _currentPosition.inMilliseconds / 1000,
                            pitchHistory: _pitchHistory,
                            minHz: defaultLivePitchMinFrequencyHz.toDouble(),
                            maxHz: defaultLivePitchMaxFrequencyHz.toDouble(),
                            getTargetFrequency: frequencyHzForPitchLabel,
                            isRunning: _isPlaying,
                            targetLabel: _currentStage(
                                        _currentPosition.inMilliseconds / 1000)
                                    ?.targetLabel ??
                                'Listen and follow',
                            detectedNoteLabel: _liveFrequencyHz == null
                                ? null
                                : noteLabelForFrequency(_liveFrequencyHz!),
                            detectedFrequencyHz: _pitchGuidance.lastFrameMeasurable
                                ? _liveFrequencyHz
                                : null,
                            detectedCents: _pitchGuidance.lastFrameMeasurable
                                ? _liveCentsError
                                : null,
                            guidance:
                                _isPlaying ? _pitchGuidance.current : null))
                  ]),
              const SizedBox(height: 12),
              if (_isPlaying) _buildLiveCoachCard(),
              if (_contentNotices.isNotEmpty)
                ExpansionTile(
                    title: const Text('Song availability'),
                    children: _contentNotices
                        .map((notice) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(notice)))
                        .toList()),
              if (_reviewError != null) ...[
                Text(_reviewError!,
                    style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
                if (!_requiresNewTake)
                  FilledButton.icon(
                      onPressed: _finishSession,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry review')),
                if (!_review.hasSavedAttempt)
                  TextButton(
                      onPressed: () {
                        setState(() {
                          _reviewError = null;
                          _requiresNewTake = false;
                        });
                        _startSinging();
                      },
                      child: const Text('Start a new take')),
              ] else
                Center(
                    child: _isPlaying
                        ? _buildPlayingControls()
                        : _buildStartControls()),
            ]);
      }))),
    );
  }

  Widget _buildLiveCoachCard() {
    final cents = _liveCentsError;
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: 'Live coaching status: $_liveCoachCue',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            AudioWaveformVisualizer(
              amplitude: _liveAmplitude,
              isActive: _isPlaying,
              barCount: 16,
              barWidth: 2.5,
              barSpacing: 2,
              maxBarHeight: 32,
              minBarHeight: 3,
              glowEnabled: false,
              activeColor: theme.colorScheme.primary,
              style: WaveformStyle.mirrored,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _liveCoachCue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cents == null
                        ? 'Local microphone feedback'
                        : '${cents.abs().round()} cents from the target',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartControls() {
    final theme = Theme.of(context);
    return FilledButton.icon(
      onPressed: _startSinging,
      icon: const Icon(Icons.mic_rounded),
      label: Text(
          _hasInstrumentalAudio ? 'Start singing' : 'Start mic practice',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onPrimary)),
    );
  }

  Widget _buildPlayingControls() {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _finishSession,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stop_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'FINISH',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Testable boundary for optional third-party song content.
class SongLyrics {
  const SongLyrics({this.syncedLyrics, this.plainLyrics});

  final String? syncedLyrics;
  final String? plainLyrics;
}

class KaraokeContentClient {
  KaraokeContentClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;

  Future<SongLyrics?> fetchLyrics({
    required String title,
    required String artist,
    required int durationSec,
  }) async {
    if (durationSec <= 0) return null;
    try {
      final query = '$title $artist'.trim();
      final response = await _httpClient.get(
        Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}',
        ),
        headers: const {'User-Agent': 'Cockatiel Vocal Coach'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is! List) return null;

      SongLyrics? bestLyrics;
      var bestMatchRank = 0;
      var bestDurationDifference = double.infinity;
      for (final item in decoded) {
        if (item is! Map) continue;
        final lyrics = item['syncedLyrics'];
        final plainLyrics = item['plainLyrics'];
        final synced =
            lyrics is String && lyrics.trim().isNotEmpty ? lyrics.trim() : null;
        final plain = plainLyrics is String && plainLyrics.trim().isNotEmpty
            ? plainLyrics.trim()
            : null;
        if (synced == null && plain == null) continue;
        final duration = item['duration'];
        if (duration is! num || !duration.isFinite || duration <= 0) continue;
        final durationDifference = (duration - durationSec).abs().toDouble();
        // Catalog durations are rounded to seconds. A small tolerance covers
        // rounding/encoder padding while rejecting shorter edits and versions.
        if (durationDifference > 2) continue;

        final matchRank = _lrcLibMatchRank(
          item,
          requestedTitle: title,
          requestedArtist: artist,
        );
        if (matchRank > bestMatchRank ||
            (matchRank > 0 &&
                matchRank == bestMatchRank &&
                (durationDifference < bestDurationDifference ||
                    (durationDifference == bestDurationDifference &&
                        bestLyrics?.syncedLyrics == null &&
                        synced != null)))) {
          bestMatchRank = matchRank;
          bestDurationDifference = durationDifference;
          bestLyrics = SongLyrics(syncedLyrics: synced, plainLyrics: plain);
        }
      }
      return bestLyrics;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> fetchPitchMap(String url) async {
    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      return json.decode(response.body);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_ownsClient) _httpClient.close();
  }
}

String _normalizeLrcLibText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

int _lrcLibMatchRank(
  Map<dynamic, dynamic> item, {
  required String requestedTitle,
  required String requestedArtist,
}) {
  final trackName = item['trackName'];
  final artistName = item['artistName'];
  if (trackName is! String || artistName is! String) return 0;

  final expectedTitle = _normalizeLrcLibText(requestedTitle);
  final actualTitle = _normalizeLrcLibText(trackName);
  final expectedArtist = _normalizeLrcLibText(requestedArtist);
  final actualArtist = _normalizeLrcLibText(artistName);
  if (expectedTitle.isEmpty ||
      expectedArtist.isEmpty ||
      actualArtist != expectedArtist) {
    return 0;
  }

  if (actualTitle == expectedTitle) return 2;
  if (!actualTitle.startsWith('$expectedTitle ')) return 0;

  // A clearly labelled version is acceptable only as a fallback. Exact
  // titles always outrank Live/Acoustic variants when both are available.
  final suffix = actualTitle.substring(expectedTitle.length).trim();
  const allowedVariantWords = {
    'acoustic',
    'demo',
    'edit',
    'live',
    'mix',
    'radio',
    'remix',
    'version',
  };
  final suffixWords = suffix.split(' ');
  if (suffixWords.isEmpty ||
      suffixWords.any((word) => !allowedVariantWords.contains(word))) {
    return 0;
  }
  return 1;
}
