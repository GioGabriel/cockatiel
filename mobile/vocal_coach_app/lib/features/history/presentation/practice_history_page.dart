import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/session_models.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../ai_feedback_display/presentation/feedback_page.dart';
import '../../vocal_training/presentation/training_session_page.dart';

class PracticeHistoryPage extends StatefulWidget {
  const PracticeHistoryPage({
    super.key,
    required this.apiClient,
    required this.appState,
  });

  final ApiClient apiClient;
  final AppState appState;

  @override
  State<PracticeHistoryPage> createState() => _PracticeHistoryPageState();
}

class _PracticeHistoryPageState extends State<PracticeHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SessionDetailsResponse> _sessions = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _fetchHistory();
    // Auto refresh periodically in case jobs are processing
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _sessions.any((s) => s.status == 'processing' || s.status == 'queued')) {
        _fetchHistory(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final list = await widget.apiClient.listSessions();
      // Sort newest first
      list.sort((a, b) {
        final aTime = a.completedAt ?? a.createdAt ?? 0;
        final bTime = b.completedAt ?? b.createdAt ?? 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _sessions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = 'Could not load practice history: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<SessionDetailsResponse> get _filteredSessions {
    if (_tabController.index == 1) {
      return _sessions.where((s) => s.mode == 'training').toList();
    } else if (_tabController.index == 2) {
      return _sessions.where((s) => s.mode == 'karaoke').toList();
    }
    return _sessions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Practice History',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchHistory();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh logs',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: colorScheme.onPrimary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'All Sessions'),
                  Tab(text: 'Vocal Coach'),
                  Tab(text: 'Karaoke'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading && _sessions.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => ShimmerSkeleton(
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }

    if (_error != null && _sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load activity logs',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _fetchHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredSessions;

    if (filtered.isEmpty) {
      final tabName = _tabController.index == 1
          ? 'Vocal Coach'
          : _tabController.index == 2
              ? 'Karaoke'
              : 'Practice';
      return EmptyStateView(
        headline: 'No $tabName logs yet',
        body: 'Start your vocal exercises or karaoke songs to build your training logs and receive AI evaluation!',
        ctaLabel: 'Refresh',
        onCtaTap: _fetchHistory,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchHistory(),
      color: colorScheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final session = filtered[index];
          return _SessionLogCard(
            session: session,
            apiClient: widget.apiClient,
            appState: widget.appState,
            onChanged: () => _fetchHistory(silent: true),
          );
        },
      ),
    );
  }
}

class _SessionLogCard extends StatefulWidget {
  const _SessionLogCard({
    required this.session,
    required this.apiClient,
    required this.appState,
    required this.onChanged,
  });

  final SessionDetailsResponse session;
  final ApiClient apiClient;
  final AppState appState;
  final VoidCallback onChanged;

  @override
  State<_SessionLogCard> createState() => _SessionLogCardState();
}

class _SessionLogCardState extends State<_SessionLogCard> {
  bool _isActionLoading = false;

  String _formatExerciseTitle(String raw) {
    if (raw.isEmpty) return 'Training Session';
    return raw
        .split('_')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _formatDate(int? timestampMs) {
    if (timestampMs == null || timestampMs <= 0) return 'Recent';
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _reviewFeedback() async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    HapticFeedback.lightImpact();

    try {
      CoachingFeedback? feedback = widget.session.feedback;
      if (feedback == null) {
        final fullSession = await widget.apiClient.fetchSession(
          sessionId: widget.session.sessionId,
        );
        feedback = fullSession.feedback;
        if (feedback == null && fullSession.status == 'completed') {
          feedback = await widget.apiClient.fetchFeedback(
            sessionId: widget.session.sessionId,
          );
        }
      }

      if (!mounted) return;

      if (feedback != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FeedbackPage(
              result: FinalizeResponse(
                sessionId: widget.session.sessionId,
                status: 'completed',
                feedback: feedback!,
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI feedback is not yet available for this session.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load AI feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _resumeSession() async {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingSessionPage(
          apiClient: widget.apiClient,
          appState: widget.appState,
          mode: widget.session.mode,
          exerciseType: widget.session.exerciseType,
          sessionId: widget.session.sessionId,
        ),
      ),
    ).then((_) => widget.onChanged());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isKaraoke = widget.session.mode == 'karaoke';

    final modeColor = isKaraoke ? colorScheme.tertiary : colorScheme.primary;
    final modeLabel = isKaraoke ? 'Karaoke' : 'Vocal Coach';
    final title = _formatExerciseTitle(widget.session.exerciseType);
    final dateStr = _formatDate(widget.session.completedAt ?? widget.session.createdAt);
    final attemptsCount = widget.session.attempts?.length ?? 0;

    final score = widget.session.overallScore ?? widget.session.bestAttemptScore;
    final isCompleted = widget.session.status == 'completed' || (score != null && score > 0);
    final isProcessing = widget.session.status == 'processing' || widget.session.status == 'queued';
    final isFailed = widget.session.status == 'failed';

    Color statusColor = colorScheme.outline;
    String statusLabel = 'Incomplete';
    if (isCompleted) {
      statusColor = Colors.greenAccent.shade400;
      statusLabel = 'Completed';
    } else if (isProcessing) {
      statusColor = colorScheme.primary;
      statusLabel = 'Analyzing AI...';
    } else if (isFailed) {
      statusColor = colorScheme.error;
      statusLabel = 'Failed';
    }

    return GlassCard.dark(
      borderRadius: 20,
      borderOpacity: 0.25,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Mode badge + Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: modeColor.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isKaraoke ? Icons.mic_external_on_rounded : Icons.graphic_eq_rounded,
                        size: 14,
                        color: modeColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        modeLabel,
                        style: TextStyle(
                          color: modeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main info: Title + Score Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        attemptsCount == 1 ? '1 take recorded' : '$attemptsCount takes recorded',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (score != null && score > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getScoreColor(score).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getScoreColor(score).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: _getScoreColor(score),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'SCORE',
                          style: TextStyle(
                            color: _getScoreColor(score).withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Status bar and Action button
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.session.failureReason != null && widget.session.failureReason!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '(${widget.session.failureReason})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (isCompleted)
                  FilledButton.tonalIcon(
                    onPressed: _isActionLoading ? null : _reviewFeedback,
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_rounded, size: 16),
                    label: const Text(
                      'Review Take',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else if (isProcessing)
                  OutlinedButton.icon(
                    onPressed: widget.onChanged,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Check Progress',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else if (!isFailed)
                  OutlinedButton.icon(
                    onPressed: _resumeSession,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text(
                      'Resume',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.greenAccent.shade400;
    if (score >= 65) return Colors.amberAccent.shade400;
    return Colors.redAccent.shade200;
  }
}
