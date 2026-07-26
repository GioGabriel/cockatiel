import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../../../core/audio/live_audio_analyzer.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/karaoke_models.dart';
import '../../vocal_training/presentation/widgets/karaoke_pitch_visualizer.dart';
import 'widgets/lyric_scroller.dart';

class KaraokeSingingPage extends StatefulWidget {
  const KaraokeSingingPage({
    super.key,
    required this.apiClient,
    required this.drill,
    required this.sessionId,
  });

  final ApiClient apiClient;
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
  String? _error;

  List<LyricLine> _lyrics = [];
  
  final List<PitchPoint> _pitchHistory = [];
  
  Duration _currentPosition = Duration.zero;

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
        // We will re-add parsing logic here when we rebuild the live scoring engine
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

  Future<void> _startSinging() async {
    setState(() => _isPlaying = true);
    await _analyzer.start();
    _audioSub = _analyzer.frames.listen((frame) {
      if (!frame.voiced || frame.frequencyHz == null) return;
      
      setState(() {
        _pitchHistory.add(PitchPoint(_currentPosition.inMilliseconds / 1000.0, frame.frequencyHz!));
        if (_pitchHistory.length > 200) _pitchHistory.removeAt(0); // keep window small
      });
      
      // Removed scoring logic temporarily
    });
    
    await _player.play();
  }
  
  Future<void> _finishSession() async {
    await _player.stop();
    await _analyzer.stop();
    // Navigate to evaluation/feedback page
    if (mounted) Navigator.pop(context);
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
                  stages: const [], // TODO: convert pitch map to stages for rendering
                  currentElapsedSec: _currentPosition.inMilliseconds / 1000.0,
                  pitchHistory: _pitchHistory,
                  minHz: 80,
                  maxHz: 800,
                  getTargetFrequency: (label) => 261.63,
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
