import 'package:vocal_coach_app/shared/widgets/studio_recovery_view.dart';
import 'package:vocal_coach_app/shared/widgets/song_artwork.dart';
import 'package:vocal_coach_app/shared/widgets/studio_scaffold.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/karaoke_models.dart';
import '../../../shared/models/training_models.dart';
import '../../../shared/utils/vocal_utils.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import 'karaoke_song_briefing_page.dart';
import '../domain/song_library.dart';

class KaraokeCatalogPage extends StatefulWidget {
  const KaraokeCatalogPage({
    super.key,
    required this.apiClient,
    required this.appState,
  });

  final ApiClient apiClient;
  final AppState appState;

  @override
  State<KaraokeCatalogPage> createState() => _KaraokeCatalogPageState();
}

class _KaraokeCatalogPageState extends State<KaraokeCatalogPage> {
  KaraokeCatalog? _catalog;
  Map<String, TrainingExerciseProgress> _progressByDrill = {};
  bool _isLoading = true;
  bool _hasError = false;
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final library = await loadSongLibrary(
          fetchCatalog: widget.apiClient.fetchKaraokeCatalog,
          fetchProgress: widget.apiClient.fetchKaraokeProgress);
      final catalog = library.catalog;
      final progress = library.progress;

      final Map<String, TrainingExerciseProgress> progressMap = {};
      for (final item in progress?.items ?? <TrainingExerciseProgress>[]) {
        progressMap[item.exerciseId] = item;
      }

      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _progressByDrill = progressMap;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _onDrillTap(KaraokeDrill drill) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KaraokeSongBriefingPage(
          drill: drill,
          apiClient: widget.apiClient,
          appState: widget.appState,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StudioScaffold(
      appBar: AppBar(title: const Text('Song Practice')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return _buildShimmerLoading(theme);
    }

    if (_hasError) {
      return _buildErrorState(theme);
    }

    return _buildCatalogList(theme);
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ShimmerSkeleton(
        child: ListView(
          children: List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonShapes.listItem(theme: theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return StudioRecoveryView(
        title: 'Your songs could not load.',
        message: 'Check your connection, then try opening the library again.',
        onRetry: _loadData);
  }

  Widget _buildCatalogList(ThemeData theme) {
    final originalCategories = _catalog?.categories ?? [];
    if (originalCategories.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.library_music_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                    'No songs are available yet. Pull the latest church-song catalog when it is ready.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: _loadData, child: const Text('Refresh songs')),
              ])));
    }

    final Map<String, KaraokeDrill> uniqueDrills = {};
    for (var c in originalCategories) {
      for (var d in c.drills) {
        uniqueDrills[d.drillId] = d;
      }
    }

    final allCategory = KaraokeCategory(
      categoryId: 'all',
      styleLabel: 'all',
      description: 'All Songs',
      drills: uniqueDrills.values.toList(),
    );

    final categories = [allCategory, ...originalCategories];
    final selectedCategory =
        categories[_selectedCategoryIndex.clamp(0, categories.length - 1)];

    final filteredDrills = selectedCategory.drills.where((drill) {
      if (_searchQuery.isEmpty) return true;
      return drill.title.toLowerCase().contains(_searchQuery) ||
          drill.artistName.toLowerCase().contains(_searchQuery);
    }).toList();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: StudioHeading(
                eyebrow: 'YOUR SONG LIBRARY',
                title: 'Sing what you love.',
                description:
                    'Choose a song. Find your rhythm. Enjoy the take.')),
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search Song or Artist',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),

        // Filter Chips
        SizedBox(
          height: 64 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = index == _selectedCategoryIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(formatSnakeCaseTitle(category.styleLabel)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategoryIndex = index);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ])),
      if (filteredDrills.isEmpty)
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    _searchQuery.isEmpty
                        ? 'No songs are available in this category yet.'
                        : 'No songs match your search. Try another title or artist.',
                    textAlign: TextAlign.center)))
      else
        SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
              final drill = filteredDrills[index];
              return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDrillCard(
                      drill, _progressByDrill[drill.drillId], theme));
            }, childCount: filteredDrills.length))),
    ]);
  }

  Widget _buildDrillCard(
      KaraokeDrill drill, TrainingExerciseProgress? progress, ThemeData theme) {
    final durationLabel = formatDuration(drill.durationSec);
    final formattedTitle = formatSnakeCaseTitle(drill.title);
    final vocalLow = drill.vocalRange['low'] ?? drill.vocalRange['min'] ?? '';
    final vocalHigh = drill.vocalRange['high'] ?? drill.vocalRange['max'] ?? '';
    final vocalRangeLabel = vocalLow.isNotEmpty && vocalHigh.isNotEmpty
        ? '$vocalLow–$vocalHigh'
        : '';

    return Semantics(
        button: true,
        label: 'Practice $formattedTitle by ${drill.artistName}',
        child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: () => _onDrillTap(drill),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 64,
                            height: 76,
                            child: SongArtwork(
                                title: formattedTitle,
                                coverUrl: drill.coverUrl)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Hero(
                                  tag: 'karaoke_song_title_${drill.drillId}',
                                  child: Material(
                                      color: Colors.transparent,
                                      child: Text(formattedTitle,
                                          style: theme.textTheme.titleMedium))),
                              const SizedBox(height: 5),
                              Text(drill.artistName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 10),
                              Wrap(spacing: 10, runSpacing: 4, children: [
                                Text(durationLabel,
                                    style: theme.textTheme.labelSmall),
                                Text(drill.difficulty,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary)),
                                if (vocalRangeLabel.isNotEmpty)
                                  Text(vocalRangeLabel,
                                      style: theme.textTheme.labelSmall),
                              ]),
                              if (progress != null &&
                                  progress.sessionsCompleted > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                    'Best ${progress.bestScore.round()}% · ${progress.sessionsCompleted} takes',
                                    style: theme.textTheme.labelSmall),
                              ],
                            ])),
                        const SizedBox(width: 6),
                        Icon(Icons.play_circle_outline_rounded,
                            size: 28, color: theme.colorScheme.primary),
                      ]),
                ))));
  }
}
