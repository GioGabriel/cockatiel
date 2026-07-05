import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/page_transitions.dart';
import '../../../shared/models/karaoke_models.dart';
import '../../vocal_training/presentation/training_session_page.dart';

class KaraokeSongBriefingPage extends StatefulWidget {
  const KaraokeSongBriefingPage({
    super.key,
    required this.drill,
    required this.apiClient,
    required this.appState,
  });

  final KaraokeDrill drill;
  final ApiClient apiClient;
  final AppState appState;

  @override
  State<KaraokeSongBriefingPage> createState() =>
      _KaraokeSongBriefingPageState();
}

class _KaraokeSongBriefingPageState extends State<KaraokeSongBriefingPage> {
  bool _isStarting = false;
  String? _error;

  Future<void> _startSession() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      final created = await widget.apiClient.createSession(
        mode: 'karaoke',
        exerciseType: widget.drill.drillId,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        slideUpRoute(
          builder: (_) => TrainingSessionPage(
            apiClient: widget.apiClient,
            appState: widget.appState,
            mode: 'karaoke',
            exerciseType: widget.drill.drillId,
            sessionId: created.sessionId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not start session. Please try again.';
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
    final drill = widget.drill;
    final minutes = drill.durationSec ~/ 60;
    final seconds = drill.durationSec % 60;
    final durationLabel =
        seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    final vocalLow = drill.vocalRange['low'] ?? '';
    final vocalHigh = drill.vocalRange['high'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(drill.title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header card
          Card(
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
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      ),
                      _buildDifficultyBadge(drill.difficulty, theme),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.category_outlined,
                    'Style',
                    drill.styleCategory,
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.timer_outlined,
                    'Duration',
                    durationLabel,
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.speed_outlined,
                    'Tempo',
                    '${drill.tempoBpm} BPM',
                    theme,
                  ),
                  if (vocalLow.isNotEmpty && vocalHigh.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.music_note_outlined,
                      'Vocal Range',
                      '$vocalLow – $vocalHigh',
                      theme,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Objective
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Objective', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(drill.objective, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Performance tips
          if (drill.performanceTips.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Tips',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...drill.performanceTips.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Error message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),

          // Start Session button
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isStarting ? null : _startSession,
              child: Text(
                _isStarting ? 'Starting...' : 'Start Session',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildDifficultyBadge(String difficulty, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
