import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/page_transitions.dart';
import '../../../shared/models/karaoke_models.dart';
import '../../../shared/utils/vocal_utils.dart';
import '../../../shared/widgets/difficulty_badge.dart';
import '../../../shared/widgets/scrollable_action_layout.dart';
import 'karaoke_singing_page.dart';

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
          builder: (_) => KaraokeSingingPage(
            apiClient: widget.apiClient,
            appState: widget.appState,
            drill: widget.drill,
            sessionId: created.sessionId,
          ),
        ),
      );
    } catch (_) {
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
    final durationLabel = formatDuration(drill.durationSec);
    final vocalLow = drill.vocalRange['low'] ?? '';
    final vocalHigh = drill.vocalRange['high'] ?? '';

    final formattedTitle = formatSnakeCaseTitle(drill.title);
    final formattedStyle = formatSnakeCaseTitle(drill.styleCategory);

    return Scaffold(
      appBar: AppBar(title: Text(formattedStyle)),
      body: ScrollableActionLayout(
        content: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                DifficultyBadge(difficulty: drill.difficulty),
                const SizedBox(height: 16),
                Hero(
                  tag: 'karaoke_song_title_${drill.drillId}',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      formattedTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _buildIconStat(Icons.timer_outlined, durationLabel, theme),
                    _buildIconStat(
                        Icons.speed_outlined, '${drill.tempoBpm} BPM', theme),
                  ],
                ),
                if (vocalLow.isNotEmpty && vocalHigh.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildIconStat(Icons.mic_external_on_outlined,
                      '$vocalLow – $vocalHigh', theme),
                ],
              ],
            ),
          ),
        ),
        error: _error == null
            ? null
            : Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
        action: FilledButton.icon(
          onPressed: _isStarting ? null : _startSession,
          icon: _isStarting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow_rounded),
          label: Text(
            _isStarting ? 'Loading...' : 'Start Karaoke',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildIconStat(IconData icon, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
