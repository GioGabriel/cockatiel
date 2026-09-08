import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
import '../../../shared/widgets/audio_waveform_visualizer.dart';
import '../../ai_feedback_display/presentation/analysis_queue_page.dart';
import '../../vocal_training/presentation/widgets/karaoke_pitch_visualizer.dart';
import 'widgets/lyric_scroller.dart';

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
  String? _error;
  List<String> _contentNotices = const [];
  bool _hasInstrumentalAudio = false;

  List<LyricLine> _lyrics = [];
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
      minFrequencyHz: 80,
      maxFrequencyHz: 800,
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

      final syncedLyrics = await _contentClient.fetchSyncedLyrics(
        title: widget.drill.title,
        artist: widget.drill.artistName,
      );
      if (syncedLyrics != null) {
        _lyrics = _parseLrc(syncedLyrics);
      }
      if (_lyrics.isEmpty) {
        notices.add(
            'Synchronized lyrics are unavailable. You can still follow the pitch guide.');
      }

      if (widget.drill.pitchMapUrl.isNotEmpty) {
        final decoded =
            await _contentClient.fetchPitchMap(widget.drill.pitchMapUrl);
        if (decoded is List) {
          _stages = _parsePitchMapList(decoded);
        } else if (decoded is Map<String, dynamic>) {
          _stages = _parsePitchMap(decoded);
        }
      }
      if (_stages.isEmpty) {
        notices.add(
            'A pitch guide is unavailable for this song. Live microphone feedback is still active.');
      }

      if (widget.drill.instrumentalUrl.isNotEmpty) {
        try {
          await _player.setUrl(widget.drill.instrumentalUrl);
          _hasInstrumentalAudio = true;
        } catch (_) {
          notices.add(
              'Instrumental audio could not be loaded. Mic-only practice is available.');
        }
      } else {
        notices.add(
            'Instrumental audio is unavailable. Mic-only practice is available.');
      }

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

  List<TrainingRuntimeStage> _parsePitchMapList(List<dynamic> jsonList) {
    final List<TrainingRuntimeStage> stages = [];

    for (int i = 0; i < jsonList.length; i++) {
      final item = jsonList[i];
      if (item is! Map) continue;

      final timeValue = item['time'];
      final pitchValue = item['pitch'];
      if (timeValue is! num || pitchValue is! num) continue;
      final timeSec = timeValue.toDouble();
      final freq = pitchValue.toDouble();

      if (freq <= 0) continue; // Skip silences

      // Determine duration (diff to next frame, or default to 0.05s)
      double durationSec = 0.05;
      if (i < jsonList.length - 1) {
        final nextItem = jsonList[i + 1];
        if (nextItem is Map) {
          final nextTimeValue = nextItem['time'];
          if (nextTimeValue is! num) continue;
          final nextTimeSec = nextTimeValue.toDouble();

          // If the next note is the exact same pitch and continuous, we could merge them.
          // For now, just generate discrete tiny stages or rely on the visualizer to merge them.
          // Actually, we should just emit the exact frame as a tiny 0.05s stage so the visualizer draws a continuous line!
          durationSec = (nextTimeSec - timeSec).clamp(0.01, 0.5);
        }
      }

      stages.add(TrainingRuntimeStage(
        stageId: 'pitch_$i',
        title: freq.toStringAsFixed(1),
        targetLabel: freq.toStringAsFixed(1),
        instruction: 'Match pitch',
        durationSec: durationSec,
        startSec: timeSec,
        endSec: timeSec + durationSec,
      ));
    }
    return stages;
  }

  List<TrainingRuntimeStage> _parsePitchMap(Map<String, dynamic> jsonMap) {
    final List<TrainingRuntimeStage> stages = [];
    int index = 0;

    final keys = jsonMap.keys.toList()..sort();

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final frequencyValue = jsonMap[key];
      if (frequencyValue is! num) continue;
      final freq = frequencyValue.toDouble();

      final parts = key.split(':');
      if (parts.length != 2) continue;
      final min = int.tryParse(parts[0]);
      final seconds = double.tryParse(parts[1]);
      if (min == null || seconds == null) continue;
      final startSecDouble = min * 60.0 + seconds;

      double endSecDouble = startSecDouble + 0.1;
      if (i < keys.length - 1) {
        final nextParts = keys[i + 1].split(':');
        if (nextParts.length == 2) {
          final nextMin = int.tryParse(nextParts[0]);
          final nextSeconds = double.tryParse(nextParts[1]);
          if (nextMin != null && nextSeconds != null) {
            final nextStartSec = nextMin * 60.0 + nextSeconds;
            if (nextStartSec - startSecDouble <= 0.5) {
              endSecDouble = nextStartSec;
            }
          }
        }
      }

      stages.add(TrainingRuntimeStage(
        stageId: 'stage_$index',
        title: 'Note $index',
        targetLabel: freq.toString(),
        instruction: '',
        durationSec: endSecDouble - startSecDouble,
        startSec: startSecDouble,
        endSec: endSecDouble,
      ));
      index++;
    }
    return stages;
  }

  List<LyricLine> _parseLrc(String lrc) {
    final List<LyricLine> lines = [];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (var line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();

        final duration = Duration(minutes: min, seconds: sec, milliseconds: ms);
        lines.add(LyricLine(time: duration, text: text));
      }
    }
    return lines;
  }

  double _centsDifference(double frequencyHz, double targetHz) {
    if (frequencyHz <= 0 || targetHz <= 0) return 0;
    return 1200 * (log(frequencyHz / targetHz) / ln2);
  }

  String _noteLabelForFrequency(double frequencyHz) {
    if (frequencyHz <= 0 || !frequencyHz.isFinite) return 'unknown';
    const names = <String>[
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final midi = (69 + 12 * (log(frequencyHz / 440) / ln2)).round();
    final octave = (midi ~/ 12) - 1;
    return '${names[midi % 12]}$octave';
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
      if (elapsedSec >= stage.startSec && elapsedSec <= stage.endSec) {
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
    _audioSub = _analyzer.frames.listen((frame) {
      final elapsed = _currentPosition.inMilliseconds / 1000.0;
      final currentStage = _currentStage(elapsed);
      final targetHz = currentStage == null
          ? null
          : double.tryParse(currentStage.targetLabel);
      double? centsError;
      if (frame.voiced && frame.frequencyHz != null && currentStage != null) {
        centsError = _centsDifference(frame.frequencyHz!, targetHz ?? 261.63);
      }
      final guidance = _pitchGuidance.update(
        isAttemptRunning: true,
        hasTarget: targetHz != null,
        voiced: frame.voiced && frame.frequencyHz != null,
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
              _pitchGuidance.lastFrameMeasurable ? frame.frequencyHz : null;
          _liveCoachCue = guidance.message;

          if (_pitchGuidance.lastFrameMeasurable && frame.frequencyHz != null) {
            _pitchHistory.add(PitchPoint(elapsed, frame.frequencyHz!));
            if (_pitchHistory.length > 250) _pitchHistory.removeAt(0);
          } else {
            _pitchHistory.add(PitchPoint(elapsed, 0));
            if (_pitchHistory.length > 250) _pitchHistory.removeAt(0);
          }
        });
      }

      _metricAccumulator.addFrame(
        VocalMetricFrame(
          timestampMs: frame.timestampMs,
          targetId: currentStage?.stageId,
          targetLabel: currentStage?.targetLabel,
          targetFrequencyHz: targetHz,
          frequencyHz: frame.frequencyHz,
          loudnessDb: frame.loudnessDb,
          voiced: frame.voiced && _pitchGuidance.lastFrameMeasurable,
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

    _stopMicOnlyClock();
    await _player.stop();
    await _audioSub?.cancel();
    _audioSub = null;
    await _analyzer.stop();

    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _isLoading = true;
    });

    try {
      final summary = _buildAttemptMetricSummary();
      final totalSec =
          (_currentPosition.inMilliseconds / 1000.0).clamp(10, 600).toInt();

      await widget.apiClient.saveTrainingAttempt(
        sessionId: widget.sessionId,
        attemptIndex: 1,
        difficulty: widget.drill.difficulty,
        durationSec: totalSec,
        metricSummary: summary,
      );

      await widget.apiClient.finalizeSession(sessionId: widget.sessionId);
      await widget.appState.refreshAIJobs();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AnalysisQueuePage(
              apiClient: widget.apiClient,
              appState: widget.appState,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this session. Please try again.'),
          ),
        );
        Navigator.pop(context);
      }
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
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          image: widget.drill.coverUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(widget.drill.coverUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.scrim.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Container(
          color: theme.colorScheme.scrim.withValues(alpha: 0.82),
          child: SafeArea(
            child: Stack(
              children: [
                // Pitch Visualizer Background Layer
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  height: 200,
                  child: KaraokePitchVisualizer(
                    stages: _stages,
                    currentElapsedSec: _currentPosition.inMilliseconds / 1000.0,
                    pitchHistory: _pitchHistory,
                    minHz: 80,
                    maxHz: 800,
                    getTargetFrequency: (label) =>
                        double.tryParse(label) ?? 261.63,
                    isRunning: _isPlaying,
                    targetLabel: _currentStage(
                          _currentPosition.inMilliseconds / 1000.0,
                        )?.targetLabel ??
                        'No target',
                    detectedNoteLabel: _liveFrequencyHz == null
                        ? null
                        : _noteLabelForFrequency(_liveFrequencyHz!),
                    detectedFrequencyHz: _pitchGuidance.lastFrameMeasurable
                        ? _liveFrequencyHz
                        : null,
                    detectedCents: _pitchGuidance.lastFrameMeasurable
                        ? _liveCentsError
                        : null,
                    guidance: _pitchGuidance.current,
                  ),
                ),

                Positioned(
                  top: 258,
                  left: 16,
                  right: 16,
                  child: _buildLiveCoachCard(),
                ),

                // Lyrics Scroller Layer
                Positioned.fill(
                  top: 338,
                  child: LyricScroller(
                    lyrics: _lyrics,
                    currentPosition: _currentPosition,
                    emptyMessage:
                        'Lyrics are unavailable for this song yet. Follow the pitch guide or practice by ear.',
                  ),
                ),

                if (_contentNotices.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 16,
                    right: 16,
                    child: _buildContentNotice(),
                  ),

                // Bottom Controls
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 60.0),
                    child: _isPlaying
                        ? _buildPlayingControls()
                        : _buildStartControls(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildContentNotice() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        _contentNotices.first,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildStartControls() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startSinging,
          borderRadius: BorderRadius.circular(40),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Text(
                  _hasInstrumentalAudio
                      ? 'START SINGING'
                      : 'START MIC PRACTICE',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class LyricLine {
  final Duration time;
  final String text;
  LyricLine({required this.time, required this.text});
}

/// Testable boundary for optional third-party song content.
class KaraokeContentClient {
  KaraokeContentClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;

  Future<String?> fetchSyncedLyrics({
    required String title,
    required String artist,
  }) async {
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
      for (final item in decoded) {
        if (item is! Map) continue;
        final lyrics = item['syncedLyrics'];
        if (lyrics is String && lyrics.trim().isNotEmpty) return lyrics;
      }
    } catch (_) {
      return null;
    }
    return null;
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
