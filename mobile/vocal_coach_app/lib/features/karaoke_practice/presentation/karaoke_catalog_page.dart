import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/micro_interaction.dart';
import '../../../shared/models/karaoke_models.dart';
import '../../../shared/utils/vocal_utils.dart';
import '../../../shared/widgets/difficulty_badge.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import 'karaoke_song_briefing_page.dart';

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
  bool _isLoading = true;
  bool _hasError = false;
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final catalog = await widget.apiClient.fetchKaraokeCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Karaoke Catalog')),
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
        child: Column(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Catalog temporarily unavailable',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _loadCatalog,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogList(ThemeData theme) {
    final categories = _catalog?.categories ?? [];
    if (categories.isEmpty) return const SizedBox.shrink();

    final selectedCategory = categories[_selectedCategoryIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter Chips
        SizedBox(
          height: 60,
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
        
        // Grid View
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: selectedCategory.drills.length,
            itemBuilder: (context, index) {
              final drill = selectedCategory.drills[index];
              return _buildDrillCard(drill, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDrillCard(KaraokeDrill drill, ThemeData theme) {
    final durationLabel = formatDuration(drill.durationSec);
    final formattedTitle = formatSnakeCaseTitle(drill.title);

    return Pressable(
      onTap: () => _onDrillTap(drill),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DifficultyBadge(difficulty: drill.difficulty),
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ],
              ),
              const Spacer(),
              Hero(
                tag: 'karaoke_song_title_${drill.drillId}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    formattedTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    durationLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
