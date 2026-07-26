import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../../../core/audio/live_audio_analyzer.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/karaoke_models.dart';
import '../../../shared/models/session_models.dart';
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
  });

  final ApiClient apiClient;
  final AppState appState;
  final KaraokeDrill drill;
  final String sessionId;

  @override
  State<KaraokeSingingPage> createState() => _KaraokeSingingPageState();
}

class _KaraokeSingingPageState extends State<KaraokeSingingPage> {
  final AudioPlayer _player = AudioPlayer();
  late final LiveAudioAnalyzer _analyzer;
  StreamSubscription<LiveAudioFrame>? _audioSub;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isFinishing = false;
  String? _error;

  List<LyricLine> _lyrics = [];
  List<TrainingRuntimeStage> _stages = [];
  
  final List<PitchPoint> _pitchHistory = [];
  
  Duration _currentPosition = Duration.zero;

  // Metrics Window
  int _windowFrameCount = 0;
  int _windowVoicedFrameCount = 0;
  int _windowOnPitchFrameCount = 0;
  int _windowPitchTransitions = 0;
  double _windowAbsCentsTotal = 0;
  double _windowLoudnessTotal = 0;
  double _windowPitchDeltaTotal = 0;
  double? _windowPreviousFrequencyHz;

  @override
  void initState() {
    super.initState();
    _analyzer = LiveAudioAnalyzer(
      minFrequencyHz: 80,
      maxFrequencyHz: 800,
    );
    _initializeKaraoke();
  }

  Future<void> _initializeKaraoke() async {
    try {
      // 1. Fetch from LRCLIB using the song title and artist name
      final query = '${widget.drill.title} ${widget.drill.artistName}'.trim();
      final url = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {
        'User-Agent': 'Cockatiel Vocal Coach (vocalcoach@example.com)'
      });
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        // Find the first result that has syncedLyrics
        final match = results.firstWhere(
          (r) => r['syncedLyrics'] != null && r['syncedLyrics'].toString().isNotEmpty, 
          orElse: () => null
        );
        
        if (match != null) {
          _lyrics = _parseLrc(match['syncedLyrics']);
        }
      }

      // 2. Download Pitch Map (.json)
      if (widget.drill.pitchMapUrl.isNotEmpty) {
        final pitchResponse = await http.get(Uri.parse(widget.drill.pitchMapUrl));
        if (pitchResponse.statusCode == 200) {
          final decoded = json.decode(pitchResponse.body);
          
          if (decoded is List) {
            _stages = _parsePitchMapList(decoded);
          } else if (decoded is Map<String, dynamic>) {
            _stages = _parsePitchMap(decoded);
          } else {
             _stages = [];
          }
        }
      }

      // 3. Load Audio
      if (widget.drill.instrumentalUrl.isNotEmpty) {
        await _player.setUrl(widget.drill.instrumentalUrl);
      }
      
      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _currentPosition = pos);
      });
      
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _finishSession();
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = "Failed to load karaoke assets: $e";
        _isLoading = false;
      });
    }
  }

  List<TrainingRuntimeStage> _parsePitchMapList(List<dynamic> jsonList) {
    final List<TrainingRuntimeStage> stages = [];
    
    for (int i = 0; i < jsonList.length; i++) {
      final item = jsonList[i];
      if (item is! Map) continue;
      
      final timeSec = (item['time'] as num).toDouble();
      final freq = (item['pitch'] as num).toDouble();
      
      if (freq <= 0) continue; // Skip silences
      
      // Determine duration (diff to next frame, or default to 0.05s)
      double durationSec = 0.05;
      if (i < jsonList.length - 1) {
         final nextItem = jsonList[i + 1];
         if (nextItem is Map) {
            final nextTimeSec = (nextItem['time'] as num).toDouble();
            final nextFreq = (nextItem['pitch'] as num).toDouble();
            
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
        solfege: freq.toStringAsFixed(1),
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
      final freq = (jsonMap[key] as num).toDouble();
      
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final min = int.parse(parts[0]);
      final startSecDouble = min * 60.0 + double.parse(parts[1]);
      
      double endSecDouble = startSecDouble + 0.1;
      if (i < keys.length - 1) {
         final nextParts = keys[i+1].split(':');
         if (nextParts.length == 2) {
            final nextMin = int.parse(nextParts[0]);
            final nextStartSec = nextMin * 60.0 + double.parse(nextParts[1]);
            if (nextStartSec - startSecDouble <= 0.5) {
                endSecDouble = nextStartSec;
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

  TrainingRuntimeStage? _currentStage(double elapsedSec) {
    for (var stage in _stages) {
      if (elapsedSec >= stage.startSec && elapsedSec <= stage.endSec) {
        return stage;
      }
    }
    return null;
  }

  TrainingAttemptMetricSummary _buildAttemptMetricSummary() {
    final frameCount = max(_windowFrameCount, 1);
    final voicedFrameCount = max(_windowVoicedFrameCount, 1);
    
    final avgAbsCents = _windowAbsCentsTotal / voicedFrameCount;
    final avgLoudnessDb = _windowLoudnessTotal / frameCount;
    final onPitchRatio = _windowOnPitchFrameCount / voicedFrameCount;
    final voicedRatio = _windowVoicedFrameCount / frameCount;
    
    final avgPitchDelta = _windowPitchTransitions > 0
        ? _windowPitchDeltaTotal / _windowPitchTransitions
        : 0;

    final pitchAccuracy = (avgAbsCents <= 50.0 ? 100.0 : (100.0 - (avgAbsCents - 50.0)))
        .clamp(0, 100)
        .toDouble() * voicedRatio;
        
    final timingAccuracy = (40 + (onPitchRatio * 60)).clamp(0, 100).toDouble() * voicedRatio;
    final loudnessPenalty = (avgLoudnessDb + 24).abs() * 2.2;
    final breathControl = ((100 - loudnessPenalty) * voicedRatio).clamp(0, 100).toDouble();
    final pitchStability = ((100 - (avgPitchDelta * 1.5)) * voicedRatio).clamp(0, 100).toDouble();
    final vibratoConsistency = (55 + (voicedRatio * 45) - (avgPitchDelta * 0.6)).clamp(0, 100).toDouble();
    final noteTransitionSmoothness = ((100 - (avgPitchDelta * 1.2)) * voicedRatio).clamp(0, 100).toDouble();

    return TrainingAttemptMetricSummary.voice(
      sampleCount: frameCount,
      pitchAccuracy: pitchAccuracy,
      timingAccuracy: timingAccuracy,
      breathControl: breathControl,
      pitchStability: pitchStability,
      vibratoConsistency: vibratoConsistency,
      noteTransitionSmoothness: noteTransitionSmoothness,
    );
  }

  Future<void> _startSinging() async {
    setState(() => _isPlaying = true);
    
    _windowFrameCount = 0;
    _windowVoicedFrameCount = 0;
    _windowOnPitchFrameCount = 0;
    _windowPitchTransitions = 0;
    _windowAbsCentsTotal = 0;
    _windowLoudnessTotal = 0;
    _windowPitchDeltaTotal = 0;
    _windowPreviousFrequencyHz = null;
    
    await _analyzer.start();
    _audioSub = _analyzer.frames.listen((frame) {
      final elapsed = _currentPosition.inMilliseconds / 1000.0;
      
      setState(() {
        if (frame.voiced && frame.frequencyHz != null) {
          _pitchHistory.add(PitchPoint(elapsed, frame.frequencyHz!));
          if (_pitchHistory.length > 250) _pitchHistory.removeAt(0);
        }
      });
      
      _windowFrameCount++;
      _windowLoudnessTotal += frame.loudnessDb;
      
      if (!frame.voiced || frame.frequencyHz == null) return;
      
      _windowVoicedFrameCount++;
      final freq = frame.frequencyHz!;
      
      final currentStage = _currentStage(elapsed);
      if (currentStage != null) {
          final targetHz = double.tryParse(currentStage.targetLabel) ?? 261.63;
          final centsError = _centsDifference(freq, targetHz);
          final absCents = centsError.abs();
          
          _windowAbsCentsTotal += absCents;
          if (absCents <= 50) { 
              _windowOnPitchFrameCount++;
          }
      }
      
      if (_windowPreviousFrequencyHz != null) {
        _windowPitchDeltaTotal += (freq - _windowPreviousFrequencyHz!).abs();
        _windowPitchTransitions++;
      }
      _windowPreviousFrequencyHz = freq;
    });
    
    await _player.play();
  }
  
  Future<void> _finishSession() async {
    if (_isFinishing) return;
    _isFinishing = true;

    await _player.stop();
    await _analyzer.stop();
    
    setState(() {
      _isPlaying = false;
      _isLoading = true;
    });

    try {
      final summary = _buildAttemptMetricSummary();
      final totalSec = (_currentPosition.inMilliseconds / 1000.0).clamp(10, 600).toInt();
      
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit score: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _analyzer.dispose();
    _audioSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E002B), Color(0xFF0F0018)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Pitch Visualizer Background Layer
              Positioned(
                top: 50, left: 0, right: 0, height: 200,
                child: KaraokePitchVisualizer(
                  stages: _stages,
                  currentElapsedSec: _currentPosition.inMilliseconds / 1000.0,
                  pitchHistory: _pitchHistory,
                  minHz: 80,
                  maxHz: 800,
                  getTargetFrequency: (label) => double.tryParse(label) ?? 261.63,
                  isRunning: _isPlaying,
                ),
              ),
              
              // Lyrics Scroller Layer
              Positioned.fill(
                top: 250,
                child: LyricScroller(
                  lyrics: _lyrics,
                  currentPosition: _currentPosition,
                ),
              ),
              
              // Bottom Controls
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: FloatingActionButton.extended(
                    onPressed: _isPlaying ? _finishSession : _startSinging,
                    icon: Icon(_isPlaying ? Icons.stop : Icons.mic),
                    label: Text(_isPlaying ? 'Finish' : 'Sing Now'),
                    backgroundColor: Colors.pinkAccent,
                  ),
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
