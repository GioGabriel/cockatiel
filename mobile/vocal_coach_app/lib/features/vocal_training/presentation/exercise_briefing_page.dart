// ignore_for_file: unused_field, unused_element, unused_local_variable

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../core/audio/live_audio_analyzer.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/page_transitions.dart';
import '../../../shared/models/training_models.dart';
import '../domain/vocal_coach_catalog.dart';
import 'training_session_page.dart';

class ExerciseBriefingPage extends StatefulWidget {
  const ExerciseBriefingPage({
    super.key,
    required this.categoryTitle,
    required this.exercise,
    required this.apiClient,
    required this.appState,
    this.progress,
    this.recommendation,
  });

  final String categoryTitle;
  final VocalExercise exercise;
  final ApiClient apiClient;
  final AppState appState;
  final TrainingExerciseProgress? progress;
  final TrainingRecommendation? recommendation;

  @override
  State<ExerciseBriefingPage> createState() => _ExerciseBriefingPageState();
}

class _ExerciseBriefingPageState extends State<ExerciseBriefingPage> {
  static const _durationsByDifficulty = {
    'beginner': 30,
    'intermediate': 45,
    'advanced': 60,
  };
  static const _keyOptions = [
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

  static const _vocalRanges = {
    'Soprano': {'key': 'C', 'octave': 5},
    'Alto': {'key': 'F', 'octave': 4},
    'Tenor': {'key': 'C', 'octave': 4},
    'Baritone': {'key': 'G', 'octave': 3},
    'Bass': {'key': 'E', 'octave': 3},
  };

  late String _selectedDifficulty;
  String _selectedKey = 'C';
  int _selectedOctave = 4;
  String _selectedRange = 'Tenor';
  bool _isStarting = false;
  bool _isLoadingPreview = true;
  String? _error;
  String? _previewNotice;
  TrainingExercise? _catalogExercise;

  LiveAudioAnalyzer? _audioAnalyzer;
  double _currentAmplitude = 0.0;
  bool _isMicTesting = false;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.exercise.difficulty.toLowerCase();
    
    final prefs = widget.appState.currentUser?.vocalPreferences;
    if (prefs != null) {
      final rangeStr = prefs.vocalRange.name.toLowerCase();
      for (final key in _vocalRanges.keys) {
        if (rangeStr.contains(key.toLowerCase())) {
          _selectedRange = key;
          _selectedKey = _vocalRanges[key]!['key'] as String;
          _selectedOctave = _vocalRanges[key]!['octave'] as int;
          break;
        }
      }
    }
    
    _loadExercisePreview();
  }

  @override
  void dispose() {
    _audioAnalyzer?.dispose();
    super.dispose();
  }

  Future<void> _toggleMicTest() async {
    if (_isMicTesting) {
      await _audioAnalyzer?.stop();
      if (mounted) {
        setState(() {
          _isMicTesting = false;
          _currentAmplitude = 0.0;
        });
      }
    } else {
      _audioAnalyzer ??= LiveAudioAnalyzer();
      await _audioAnalyzer!.start();
      _audioAnalyzer!.frames.listen((frame) {
        if (mounted && _isMicTesting) {
          setState(() {
            _currentAmplitude = ((frame.loudnessDb + 60) / 60).clamp(0.0, 1.0);
          });
        }
      });
      if (mounted) {
        setState(() {
          _isMicTesting = true;
        });
      }
    }
  }

  bool get _requiresMicrophone =>
      _catalogExercise?.requiresMicrophone ??
      widget.exercise.requiresMicrophone;

  bool get _isBreathingExercise =>
      (_catalogExercise?.exerciseMode ?? widget.exercise.exerciseMode) ==
      'breathing_timer';

  String get _sessionNoun => _isBreathingExercise ? 'cycle' : 'take';

  int get _selectedDurationSec =>
      _durationsByDifficulty[_selectedDifficulty] ?? 30;

  String get _exerciseName => _catalogExercise?.name ?? widget.exercise.name;

  String get _exerciseObjective =>
      _catalogExercise?.objective ?? widget.exercise.objective;

  String get _exerciseDescription =>
      _catalogExercise?.description ?? widget.exercise.description;

  String get _whatYouDo =>
      _catalogExercise?.whatYouDo ?? widget.exercise.whatYouDo;

  String get _aiFocus => _catalogExercise?.aiFocus ?? widget.exercise.aiFocus;

  List<String> get _focusMetrics =>
      _catalogExercise?.focusMetrics.map(_displayMetricLabel).toList() ??
      widget.exercise.focusMetrics;

  List<String> get _instructions =>
      _catalogExercise?.instructions.isNotEmpty == true
          ? _catalogExercise!.instructions
          : widget.exercise.instructions;

  TrainingPatternTemplate? get _selectedPattern {
    final exercise = _catalogExercise;
    if (exercise == null || exercise.patternsByDifficulty.isEmpty) {
      return null;
    }
    return exercise.patternsByDifficulty[_selectedDifficulty] ??
        exercise.patternsByDifficulty[exercise.defaultDifficulty] ??
        exercise.patternsByDifficulty.values.first;
  }

  Future<void> _loadExercisePreview() async {
    setState(() {
      _isLoadingPreview = true;
      _previewNotice = null;
    });

    try {
      final catalog = await widget.apiClient.fetchTrainingCatalog();
      TrainingExercise? matchedExercise;

      for (final category in catalog.categories) {
        for (final exercise in category.exercises) {
          if (exercise.exerciseId == widget.exercise.id) {
            matchedExercise = exercise;
            break;
          }
        }
        if (matchedExercise != null) {
          break;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _catalogExercise = matchedExercise;
        _isLoadingPreview = false;
        if (matchedExercise == null) {
          _previewNotice =
              'Showing the local drill summary while the detailed guided pattern is unavailable.';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPreview = false;
        _previewNotice =
            'Showing the local drill summary while the detailed guided pattern is unavailable.';
      });
    }
  }

  String _difficultyLabel(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _displayMetricLabel(String value) {
    final normalized = value.replaceAll('_', ' ').trim().toLowerCase();
    if (_isBreathingExercise) {
      switch (normalized) {
        case 'phase completion rate':
        case 'phase completion':
          return 'Phase completion';
        case 'pace adherence':
        case 'timing accuracy':
          return 'Pace adherence';
        case 'cycle consistency':
          return 'Cycle consistency';
        case 'completion rate':
          return 'Completion rate';
        case 'interruptions':
        case 'interruption count':
          return 'Interruptions';
        case 'pitch stability':
          return 'Breath steadiness';
        case 'note transition smoothness':
          return 'Phase transitions';
      }
    }
    return _difficultyLabel(normalized);
  }

  Future<void> _beginSession() async {
    if (_isStarting) return;

    if (_requiresMicrophone) {
      final record = AudioRecorder();
      if (!await record.hasPermission()) {
        if (!mounted) return;
        setState(() {
          _error = 'Microphone permission is required to start the session.';
        });
        return;
      }
    }

    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      final session = await widget.apiClient.createSession(
        mode: 'training',
        exerciseType: widget.exercise.id,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        slideUpRoute(
          builder: (_) => TrainingSessionPage(
            apiClient: widget.apiClient,
            appState: widget.appState,
            mode: _catalogExercise?.exerciseMode ?? widget.exercise.exerciseMode,
            exerciseType: widget.exercise.id,
            sessionId: session.sessionId,
            initialKey: _selectedKey,
            initialOctave: _selectedOctave,
            defaultDifficulty: _selectedDifficulty,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to start session. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: Text(_exerciseName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categoryTitle.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Hero(
                          tag: 'exercise_title_${widget.exercise.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              _exerciseName,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _exerciseObjective,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Difficulty', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in const [
                              ('beginner', 'Beginner', '30s'),
                              ('intermediate', 'Intermediate', '45s'),
                              ('advanced', 'Advanced', '60s'),
                            ])
                              ChoiceChip(
                                label: Text('${option.$2} · ${option.$3}'),
                                selected: _selectedDifficulty == option.$1,
                                onSelected: _isStarting ? null : (selected) {
                                  if (selected) setState(() => _selectedDifficulty = option.$1);
                                },
                              ),
                          ],
                        ),
                        
                        if (_requiresMicrophone) ...[
                          const SizedBox(height: 24),
                          Text('Vocal Range', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _vocalRanges.keys.map((range) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(range),
                                    selected: _selectedRange == range,
                                    onSelected: _isStarting ? null : (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedRange = range;
                                          _selectedKey = _vocalRanges[range]!['key'] as String;
                                          _selectedOctave = _vocalRanges[range]!['octave'] as int;
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (widget.recommendation != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.recommendation!.reason,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Start button
              FilledButton.icon(
                onPressed: _isStarting ? null : _beginSession,
                icon: _isStarting 
                    ? const SizedBox(
                        width: 20, height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _isStarting ? 'Starting...' : 'Start Session',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


