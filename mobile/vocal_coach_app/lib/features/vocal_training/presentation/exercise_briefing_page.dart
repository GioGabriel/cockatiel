import 'package:flutter/material.dart';

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

  late String _selectedDifficulty;
  String _selectedKey = 'C';
  int _selectedOctave = 4;
  bool _isStarting = false;
  bool _isLoadingPreview = true;
  String? _error;
  String? _previewNotice;
  TrainingExercise? _catalogExercise;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.exercise.difficulty.toLowerCase();
    _loadExercisePreview();
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
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      final created = await widget.apiClient.createSession(
        mode: 'training',
        exerciseType: widget.exercise.id,
        trainingConfig: {
          'difficulty': _selectedDifficulty,
          if (_requiresMicrophone) 'key': _selectedKey,
          if (_requiresMicrophone) 'octave': _selectedOctave,
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        slideUpRoute(
          builder: (_) => TrainingSessionPage(
            apiClient: widget.apiClient,
            appState: widget.appState,
            mode: 'training',
            exerciseType: widget.exercise.id,
            sessionId: created.sessionId,
            exerciseName: widget.exercise.name,
            exerciseInstructions: widget.exercise.instructions,
            defaultDifficulty: _selectedDifficulty,
          ),
        ),
      );
    } catch (error) {
      setState(() {
        _error = error.toString();
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
    final pattern = _selectedPattern;
    final stageCount = pattern?.stages.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(_exerciseName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF113A63), Color(0xFF0E7C86)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22113A63),
                  blurRadius: 28,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.categoryTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Hero(
                    tag: 'exercise_title_${widget.exercise.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        _exerciseName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _exerciseObjective,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroInfoChip(
                        label: _requiresMicrophone
                            ? 'Voice drill'
                            : 'Breath drill',
                      ),
                      _HeroInfoChip(
                        label:
                            '${_difficultyLabel(_selectedDifficulty)} · $_selectedDurationSec sec',
                      ),
                      _HeroInfoChip(
                        label: stageCount > 0
                            ? '$stageCount guided steps'
                            : 'Guided $_sessionNoun flow',
                      ),
                    ],
                  ),
                  if (widget.recommendation != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        widget.recommendation!.reason,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ],
                  if (widget.progress != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Best score ${widget.progress!.bestScore.toStringAsFixed(1)} across ${widget.progress!.sessionsCompleted} completed session(s).',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Quick Start', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      pattern != null
                          ? 'See the whole flow first, then move into the guided session without guessing what comes next.'
                          : 'Get the setup right first, then let the live coach carry the flow inside the session.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _FlowStepCard(
                        number: '1',
                        title: 'Set your range',
                        description: _requiresMicrophone
                            ? 'Pick difficulty, key, and octave. The app builds the drill around those targets.'
                            : 'Pick difficulty. The drill turns into a timed breathing cycle automatically.',
                      ),
                      _FlowStepCard(
                        number: '2',
                        title: 'Follow the guided $_sessionNoun',
                        description: pattern != null
                            ? 'Move through ${pattern.stages.length} clear steps instead of guessing what comes next.'
                            : 'The live coach will keep the next action visible while you practice.',
                      ),
                      _FlowStepCard(
                        number: '3',
                        title:
                            'Review the best ${_isBreathingExercise ? 'Cycle' : 'Take'}',
                        description:
                            'You can save up to 3 ${_sessionNoun}s and finish with AI guidance based on the strongest one.',
                      ),
                    ],
                  ),
                  if (_previewNotice != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _previewNotice!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session Setup', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    'Choose the session range first. Everything below updates to match that selection.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Text('Difficulty', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final option in const [
                        ('beginner', 'Beginner', '30 sec'),
                        ('intermediate', 'Intermediate', '45 sec'),
                        ('advanced', 'Advanced', '60 sec'),
                      ])
                        ChoiceChip(
                          label: Text('${option.$2} · ${option.$3}'),
                          selected: _selectedDifficulty == option.$1,
                          onSelected: _isStarting
                              ? null
                              : (selected) {
                                  if (!selected) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedDifficulty = option.$1;
                                  });
                                },
                        ),
                    ],
                  ),
                  if (_requiresMicrophone) ...[
                    const SizedBox(height: 16),
                    Text('Reference range', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedKey,
                            decoration: const InputDecoration(labelText: 'Key'),
                            items: _keyOptions
                                .map(
                                  (key) => DropdownMenuItem<String>(
                                    value: key,
                                    child: Text(key),
                                  ),
                                )
                                .toList(),
                            onChanged: _isStarting
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedKey = value;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedOctave,
                            decoration:
                                const InputDecoration(labelText: 'Octave'),
                            items: const [2, 3, 4, 5, 6]
                                .map(
                                  (octave) => DropdownMenuItem<int>(
                                    value: octave,
                                    child: Text('O$octave'),
                                  ),
                                )
                                .toList(),
                            onChanged: _isStarting
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedOctave = value;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SetupChip(
                        label:
                            'Up to 3 guided ${_isBreathingExercise ? 'cycles' : 'takes'}',
                      ),
                      _SetupChip(
                        label: '$_selectedDurationSec sec per $_sessionNoun',
                      ),
                      _SetupChip(
                        label: _requiresMicrophone
                            ? 'Reference key $_selectedKey$_selectedOctave'
                            : 'Guided timer pacing',
                      ),
                      _SetupChip(
                        label: _isBreathingExercise
                            ? 'Timer-guided breathing'
                            : 'AI feedback after review',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Guided Pattern',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  if (_isLoadingPreview)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 6),
                    )
                  else if (pattern != null) ...[
                    Text(
                      pattern.summary,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < pattern.stages.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PatternStageCard(
                          index: index + 1,
                          title: pattern.stages[index].title,
                          targetLabel: pattern.stages[index].targetLabel,
                          detail: pattern.stages[index].instruction,
                          trailingLabel:
                              '${pattern.stages[index].beats} beat${pattern.stages[index].beats == 1 ? '' : 's'}',
                        ),
                      ),
                  ] else ...[
                    Text(
                      'The detailed drill map is not available right now, so the live coach will guide you step by step inside the session.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What To Focus On', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(_whatYouDo),
                  const SizedBox(height: 14),
                  Text('Coach listens for', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final metric in _focusMetrics)
                        _SetupChip(label: metric),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(_exerciseDescription),
                  const SizedBox(height: 12),
                  Text(
                    'AI focus: $_aiFocus',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Before you start', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _instructions.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_instructions[index])),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isStarting ? null : _beginSession,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              _isStarting
                  ? 'Preparing Guided ${_isBreathingExercise ? 'Cycle' : 'Take'}...'
                  : 'Start Guided ${_isBreathingExercise ? 'Cycle' : 'Take'}',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FlowStepCard extends StatelessWidget {
  const _FlowStepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                number,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternStageCard extends StatelessWidget {
  const _PatternStageCard({
    required this.index,
    required this.title,
    required this.targetLabel,
    required this.detail,
    required this.trailingLabel,
  });

  final int index;
  final String title;
  final String targetLabel;
  final String detail;
  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  targetLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trailingLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupChip extends StatelessWidget {
  const _SetupChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
