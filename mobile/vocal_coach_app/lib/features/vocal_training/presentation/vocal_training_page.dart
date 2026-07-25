import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/entrance_animation.dart';
import '../../../shared/animations/micro_interaction.dart';
import '../../../shared/models/training_models.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../domain/vocal_coach_catalog.dart';
import 'exercise_briefing_page.dart';

class VocalTrainingPage extends StatefulWidget {
  const VocalTrainingPage({
    super.key,
    required this.apiClient,
    required this.appState,
  });

  final ApiClient apiClient;
  final AppState appState;

  @override
  State<VocalTrainingPage> createState() => _VocalTrainingPageState();
}

class _VocalTrainingPageState extends State<VocalTrainingPage> {
  static bool _hasShownCoachIntroThisLaunch = false;
  static const _coachIntroDismissedKey = 'vocal_coach_intro_dismissed';

  bool _isLoading = true;
  bool _hasResolvedCoachIntroPreference = false;
  bool _hasDismissedCoachIntro = false;
  String _moduleTitle = 'Vocal Coach';
  String _moduleDescription =
      'A guided training studio for technique, pitch accuracy, and breath control.';
  String? _catalogError;
  List<VocalCoachCategory> _categories = const [];
  Map<String, TrainingExerciseProgress> _progressByExercise = const {};
  Map<String, TrainingRecommendation> _recommendationByExercise = const {};
  List<TrainingRecommendation> _recommendations = const [];

  @override
  void initState() {
    super.initState();
    _loadCoachIntroPreference();
    _loadCatalog();
  }

  Future<void> _loadCoachIntroPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final hasDismissed = preferences.getBool(_coachIntroDismissedKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _hasResolvedCoachIntroPreference = true;
      _hasDismissedCoachIntro = hasDismissed;
    });
    _maybeShowCoachIntro();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _catalogError = null;
    });

    final catalogFuture = widget.apiClient.fetchTrainingCatalog();
    final progressFuture = widget.apiClient.fetchTrainingProgress();
    final recommendationFuture =
        widget.apiClient.fetchTrainingRecommendations();

    TrainingCatalog? catalog;
    TrainingProgress? progress;
    TrainingRecommendations? recommendations;
    String? catalogError;

    try {
      catalog = await catalogFuture;
    } catch (_) {
      catalogError =
          'Unable to load the latest training catalog. Showing local backup.';
    }

    try {
      progress = await progressFuture;
    } catch (_) {
      progress = null;
    }

    try {
      recommendations = await recommendationFuture;
    } catch (_) {
      recommendations = null;
    }

    final categories = catalog == null
        ? vocalCoachCatalog
        : catalog.categories.map(_mapCategory).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _moduleTitle = catalog?.title ?? 'Vocal Coach';
      _moduleDescription = catalog?.description ?? _moduleDescription;
      _categories = categories;
      _catalogError = catalogError;
      _progressByExercise = {
        for (final item
            in progress?.items ?? const <TrainingExerciseProgress>[])
          item.exerciseId: item,
      };
      _recommendationByExercise = {
        for (final item
            in recommendations?.items ?? const <TrainingRecommendation>[])
          item.exerciseId: item,
      };
      _recommendations = recommendations?.items ?? const [];
      _isLoading = false;
    });

    _maybeShowCoachIntro();
  }

  void _maybeShowCoachIntro() {
    if (_hasShownCoachIntroThisLaunch ||
        !_hasResolvedCoachIntroPreference ||
        _hasDismissedCoachIntro ||
        !mounted ||
        _categories.isEmpty) {
      return;
    }
    _hasShownCoachIntroThisLaunch = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => const _CoachIntroSheet(),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_coachIntroDismissedKey, true);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasDismissedCoachIntro = true;
      });
    });
  }

  VocalCoachCategory _mapCategory(TrainingCategory category) {
    return VocalCoachCategory(
      id: category.categoryId,
      title: category.title,
      subtitle: category.subtitle,
      description: category.description,
      icon: _iconForCategory(category.categoryId),
      exercises: category.exercises
          .map(
            (exercise) => VocalExercise(
              id: exercise.exerciseId,
              name: exercise.name,
              description: exercise.description,
              objective: exercise.objective,
              whatYouDo: exercise.whatYouDo,
              requiresMicrophone: exercise.requiresMicrophone,
              exerciseMode: exercise.exerciseMode,
              instructions: exercise.instructions,
              aiFocus: exercise.aiFocus,
              difficulty: _titleCase(exercise.defaultDifficulty),
              focusMetrics: exercise.focusMetrics
                  .map(
                    (metric) => _displayMetricLabel(
                      metric,
                      exercise.exerciseMode,
                    ),
                  )
                  .toList(),
              recommendedOrder: exercise.recommendedOrder,
            ),
          )
          .toList()
        ..sort((a, b) => a.recommendedOrder.compareTo(b.recommendedOrder)),
    );
  }

  TrainingRecommendation? get _topRecommendation {
    if (_recommendations.isEmpty) {
      return null;
    }
    return _recommendations.firstWhere(
      (item) => _findExercise(item.exerciseId) != null,
      orElse: () => _recommendations.first,
    );
  }

  VocalCoachCategory? _findCategoryByExerciseId(String exerciseId) {
    for (final category in _categories) {
      for (final exercise in category.exercises) {
        if (exercise.id == exerciseId) {
          return category;
        }
      }
    }
    return null;
  }

  VocalExercise? _findExercise(String exerciseId) {
    for (final category in _categories) {
      for (final exercise in category.exercises) {
        if (exercise.id == exerciseId) {
          return exercise;
        }
      }
    }
    return null;
  }

  void _openRecommendedExercise() {
    final recommendation = _topRecommendation;
    if (recommendation == null) {
      return;
    }
    final category = _findCategoryByExerciseId(recommendation.exerciseId);
    final exercise = _findExercise(recommendation.exerciseId);
    if (category == null || exercise == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseBriefingPage(
          categoryTitle: category.title,
          exercise: exercise,
          recommendation: recommendation,
          progress: _progressByExercise[exercise.id],
          apiClient: widget.apiClient,
          appState: widget.appState,
        ),
      ),
    );
  }

  Widget _buildShimmerSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ShimmerSkeleton(child: SkeletonShapes.dashboardCard(theme: theme)),
        const SizedBox(height: 18),
        ShimmerSkeleton(child: SkeletonShapes.listItem(theme: theme)),
        const SizedBox(height: 12),
        ShimmerSkeleton(child: SkeletonShapes.listItem(theme: theme)),
        const SizedBox(height: 12),
        ShimmerSkeleton(child: SkeletonShapes.listItem(theme: theme)),
        const SizedBox(height: 18),
        ShimmerSkeleton(child: SkeletonShapes.dashboardCard(theme: theme)),
        const SizedBox(height: 14),
        ShimmerSkeleton(child: SkeletonShapes.dashboardCard(theme: theme)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSessions = _progressByExercise.values.fold<int>(
      0,
      (total, item) => total + item.sessionsCompleted,
    );
    final bestRecentScore = _progressByExercise.values.isEmpty
        ? 0.0
        : _progressByExercise.values
            .map((item) => item.bestScore)
            .reduce((a, b) => a > b ? a : b);
    final trackedExercises = _progressByExercise.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocal Coach'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadCatalog,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerSkeleton(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _HeroPanel(
                  title: _moduleTitle,
                  description: _moduleDescription,
                  recommendation: _topRecommendation,
                  totalSessions: totalSessions,
                  trackedExercises: trackedExercises,
                  bestRecentScore: bestRecentScore,
                  onOpenRecommendation: _topRecommendation == null
                      ? null
                      : _openRecommendedExercise,
                ),
                if (_catalogError != null) ...[
                  const SizedBox(height: 12),
                  _InlineNotice(message: _catalogError!),
                ],
                if (_recommendations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Recommended Next',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  StaggeredEntrance(
                    staggerDelay: const Duration(milliseconds: 50),
                    children: [
                      for (final item in _recommendations.take(3))
                        _RecommendationCard(
                          recommendation: item,
                          exercise: _findExercise(item.exerciseId),
                          onTap: () {
                            final category =
                                _findCategoryByExerciseId(item.exerciseId);
                            final exercise = _findExercise(item.exerciseId);
                            if (category == null || exercise == null) {
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ExerciseBriefingPage(
                                  categoryTitle: category.title,
                                  exercise: exercise,
                                  recommendation: item,
                                  progress:
                                      _progressByExercise[exercise.id],
                                  apiClient: widget.apiClient,
                                  appState: widget.appState,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Training Tracks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StaggeredEntrance(
                  staggerDelay: const Duration(milliseconds: 50),
                  children: [
                    for (final category in _categories)
                      _TrackCard(
                        category: category,
                        completedExercises: category.exercises
                            .where((exercise) =>
                                _progressByExercise
                                    .containsKey(exercise.id))
                            .length,
                        recommendedCount: category.exercises
                            .where((exercise) =>
                                _recommendationByExercise
                                    .containsKey(exercise.id))
                            .length,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ExerciseCategoryPage(
                                category: category,
                                apiClient: widget.apiClient,
                                appState: widget.appState,
                                progressByExercise: _progressByExercise,
                                recommendationByExercise:
                                    _recommendationByExercise,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  IconData _iconForCategory(String categoryId) {
    switch (categoryId) {
      case 'vocal_training':
        return Icons.mic_external_on_outlined;
      case 'do_re_mi':
        return Icons.tune_rounded;
      case 'breathing':
        return Icons.air_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _displayMetricLabel(String value, String exerciseMode) {
    final normalized = value.replaceAll('_', ' ').trim().toLowerCase();
    if (exerciseMode == 'breathing_timer') {
      switch (normalized) {
        case 'phase completion rate':
        case 'phase completion':
          return 'Phase completion';
        case 'pace adherence':
          return 'Pace adherence';
        case 'breath control':
          return 'Breath control';
        case 'cycle consistency':
          return 'Cycle consistency';
        case 'completion rate':
          return 'Completion rate';
        case 'interruptions':
        case 'interruption count':
          return 'Interruptions';
        case 'timing accuracy':
          return 'Pace adherence';
        case 'pitch stability':
          return 'Breath steadiness';
        case 'note transition smoothness':
          return 'Phase transitions';
        default:
          return _titleCase(normalized);
      }
    }
    return _titleCase(normalized);
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.title,
    required this.description,
    required this.recommendation,
    required this.totalSessions,
    required this.trackedExercises,
    required this.bestRecentScore,
    required this.onOpenRecommendation,
  });

  final String title;
  final String description;
  final TrainingRecommendation? recommendation;
  final int totalSessions;
  final int trackedExercises;
  final double bestRecentScore;
  final VoidCallback? onOpenRecommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF282828),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Premium guided studio',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroStatChip(label: 'Sessions', value: '$totalSessions'),
                _HeroStatChip(label: 'Tracked', value: '$trackedExercises'),
                _HeroStatChip(
                  label: 'Best score',
                  value: bestRecentScore <= 0
                      ? '--'
                      : bestRecentScore.toStringAsFixed(1),
                ),
              ],
            ),
            if (recommendation != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Focus',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recommendation!.exerciseName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recommendation!.reason,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: onOpenRecommendation,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: const Text('Open Recommended Drill'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.exercise,
    required this.onTap,
  });

  final TrainingRecommendation recommendation;
  final VocalExercise? exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.exerciseName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(recommendation.reason),
                    if (exercise != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TagChip(
                            label: exercise!.requiresMicrophone
                                ? 'Uses microphone'
                                : 'No microphone needed',
                          ),
                          _TagChip(label: exercise!.difficulty),
                          for (final metric in exercise!.focusMetrics.take(2))
                            _TagChip(label: metric),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.category,
    required this.completedExercises,
    required this.recommendedCount,
    required this.onTap,
  });

  final VocalCoachCategory category;
  final int completedExercises;
  final int recommendedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      category.icon,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(category.subtitle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(category.description),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TagChip(label: '${category.exercises.length} exercises'),
                  _TagChip(label: '$completedExercises completed'),
                  _TagChip(
                    label: category.id == 'breathing'
                        ? 'No microphone needed'
                        : 'Uses microphone',
                  ),
                  if (recommendedCount > 0)
                    _TagChip(label: '$recommendedCount recommended'),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onTap,
                child: const Text('Open Track'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

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

class _ExerciseCategoryPage extends StatelessWidget {
  const _ExerciseCategoryPage({
    required this.category,
    required this.apiClient,
    required this.appState,
    required this.progressByExercise,
    required this.recommendationByExercise,
  });

  final VocalCoachCategory category;
  final ApiClient apiClient;
  final AppState appState;
  final Map<String, TrainingExerciseProgress> progressByExercise;
  final Map<String, TrainingRecommendation> recommendationByExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            staggerDelay: const Duration(milliseconds: 50),
            children: [
              for (final exercise in category.exercises)
                Pressable(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExerciseBriefingPage(
                          categoryTitle: category.title,
                          exercise: exercise,
                          progress: progressByExercise[exercise.id],
                          recommendation:
                              recommendationByExercise[exercise.id],
                          apiClient: apiClient,
                          appState: appState,
                        ),
                      ),
                    );
                  },
                  child: _ExerciseCard(
                    exercise: exercise,
                    progress: progressByExercise[exercise.id],
                    recommendation: recommendationByExercise[exercise.id],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciseBriefingPage(
                            categoryTitle: category.title,
                            exercise: exercise,
                            progress: progressByExercise[exercise.id],
                            recommendation:
                                recommendationByExercise[exercise.id],
                            apiClient: apiClient,
                            appState: appState,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.progress,
    required this.recommendation,
    required this.onTap,
  });

  final VocalExercise exercise;
  final TrainingExerciseProgress? progress;
  final TrainingRecommendation? recommendation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (recommendation != null)
                    const _TagChip(label: 'Recommended next'),
                  _TagChip(
                    label: exercise.requiresMicrophone
                        ? 'Uses microphone'
                        : 'No microphone needed',
                  ),
                  _TagChip(label: exercise.difficulty),
                  if (progress != null)
                    _TagChip(
                      label: 'Best ${progress!.bestScore.toStringAsFixed(1)}',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(exercise.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(exercise.objective),
              const SizedBox(height: 8),
              Text(
                'What you do',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(exercise.whatYouDo),
              const SizedBox(height: 8),
              Text(exercise.description),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in exercise.focusMetrics)
                    _TagChip(label: metric),
                ],
              ),
              const SizedBox(height: 12),
              if (recommendation != null)
                Text(
                  recommendation!.reason,
                  style: theme.textTheme.bodyMedium,
                ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Completed ${progress!.sessionsCompleted} session(s) • Last ${progress!.lastScore.toStringAsFixed(1)} • Avg ${progress!.avgScore.toStringAsFixed(1)}',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onTap,
                child: const Text('Open Briefing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachIntroSheet extends StatelessWidget {
  const _CoachIntroSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How Vocal Coach Works',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a track, open a drill, follow the guided session, then review the best result instead of guessing what comes next.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const _CoachIntroStep(
              number: '1',
              title: 'Choose a track',
              detail: 'Voice drills use a microphone. Breathing drills do not.',
            ),
            const SizedBox(height: 8),
            const _CoachIntroStep(
              number: '2',
              title: 'Open the briefing',
              detail:
                  'Check the guided pattern first so you know the exact flow.',
            ),
            const SizedBox(height: 8),
            const _CoachIntroStep(
              number: '3',
              title: 'Follow the live coach',
              detail:
                  'The session keeps the current note or phase visible while you train.',
            ),
            const SizedBox(height: 8),
            const _CoachIntroStep(
              number: '4',
              title: 'Review the best result',
              detail:
                  'Save up to 3 takes or cycles and finish with the strongest one.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Start Training'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachIntroStep extends StatelessWidget {
  const _CoachIntroStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
      ],
    );
  }
}


