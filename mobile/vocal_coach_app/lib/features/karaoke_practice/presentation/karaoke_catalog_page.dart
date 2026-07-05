import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/entrance_animation.dart';
import '../../../shared/animations/micro_interaction.dart';
import '../../../shared/models/karaoke_models.dart';
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategorySection(category, theme);
      },
    );
  }

  Widget _buildCategorySection(KaraokeCategory category, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Text(
            category.styleLabel,
            style: theme.textTheme.titleMedium,
          ),
        ),
        StaggeredEntrance(
          staggerDelay: const Duration(milliseconds: 50),
          children: category.drills
              .map((drill) => _buildDrillCard(drill, theme))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDrillCard(KaraokeDrill drill, ThemeData theme) {
    final minutes = drill.durationSec ~/ 60;
    final seconds = drill.durationSec % 60;
    final durationLabel = seconds > 0
        ? '${minutes}m ${seconds}s'
        : '${minutes}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: () => _onDrillTap(drill),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'karaoke_song_title_${drill.drillId}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            drill.title,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ),
                    _buildDifficultyBadge(drill.difficulty, theme),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      durationLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.music_note_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      drill.styleCategory,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
