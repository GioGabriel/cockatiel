import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vocal_coach_app/shared/animations/metric_animator.dart';
import 'package:vocal_coach_app/shared/animations/page_transitions.dart';
import 'package:vocal_coach_app/shared/widgets/shimmer_skeleton.dart';

import '../../../app/shell/main_shell_page.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/analytics_models.dart';
import '../../../shared/models/training_models.dart';
import '../../ai_feedback_display/presentation/analysis_queue_page.dart';
import '../../analytics_dashboard/presentation/analytics_dashboard_page.dart';
import '../../history/presentation/practice_history_page.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> with RouteAware {
  AnalyticsDashboard? _dashboard;
  TrainingRecommendations? _recommendations;
  bool _loadingDashboard = true;
  bool _loadingRecommendations = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh analytics every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadDataSilently();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Silent refresh — doesn't show loading spinners
  Future<void> _loadDataSilently() async {
    try {
      final result = await widget.apiClient.fetchAnalyticsDashboard();
      if (!mounted) return;
      setState(() => _dashboard = result);
    } catch (_) {}
    try {
      final result = await widget.apiClient.fetchTrainingRecommendations();
      if (!mounted) return;
      setState(() => _recommendations = result);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    _fetchDashboard();
    _fetchRecommendations();
  }

  Future<void> _fetchDashboard() async {
    try {
      final result = await widget.apiClient.fetchAnalyticsDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = result;
        _loadingDashboard = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDashboard = false);
    }
  }

  Future<void> _fetchRecommendations() async {
    try {
      final result = await widget.apiClient.fetchTrainingRecommendations();
      if (!mounted) return;
      setState(() {
        _recommendations = result;
        _loadingRecommendations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRecommendations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocal Coach'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                slideForwardRoute(
                  builder: (_) => PracticeHistoryPage(
                    appState: widget.appState,
                    apiClient: widget.apiClient,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Practice History',
          ),
          // AI Queue badge
          AnimatedBuilder(
            animation: widget.appState,
            builder: (_, __) {
              final pending = widget.appState.pendingAIJobsCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        slideForwardRoute(
                          builder: (_) => AnalysisQueuePage(
                            appState: widget.appState,
                            apiClient: widget.apiClient,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    tooltip: 'AI Analysis',
                  ),
                  if (pending > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pending',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadingDashboard = true;
            _loadingRecommendations = true;
          });
          await _loadData();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Welcome greeting
            _buildWelcomeSection(user, theme),
            const SizedBox(height: 24),

            // Progress summary
            _buildProgressSection(theme),
            const SizedBox(height: 24),

            // Recommendations
            _buildRecommendations(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(
    dynamic user,
    ThemeData theme,
  ) {
    final name = user?.name ?? 'Singer';
    final greeting = _getGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildProgressSection(ThemeData theme) {
    if (_loadingDashboard) {
      return ShimmerSkeleton(
        child: SkeletonShapes.dashboardCard(theme: theme),
      );
    }

    final dashboard = _dashboard;
    if (dashboard == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Start your first session',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Your vocal journey starts here. Complete a session to unlock your analytics.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Progress', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: dashboard.totalCompletedSessions.toDouble(),
                    label: 'Sessions',
                    icon: Icons.headphones_rounded,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    value: dashboard.streakDays.toDouble(),
                    label: 'Day Streak',
                    icon: Icons.local_fire_department_rounded,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    value: dashboard.avgScore7d,
                    label: 'Avg Score',
                    icon: Icons.star_rounded,
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Practice history and analytics links
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      slideForwardRoute(
                        builder: (_) => PracticeHistoryPage(
                          appState: widget.appState,
                          apiClient: widget.apiClient,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Practice History'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      slideForwardRoute(
                        builder: (_) => AnalyticsDashboardPage(
                          apiClient: widget.apiClient,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.trending_up_rounded, size: 18),
                  label: const Text('View Analytics'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _switchToTab(int index) {
    // Find the nearest NavigationBar ancestor and switch tabs.
    // The MainShellPage uses IndexedStack, so we need to communicate
    // the desired tab. Use a simple approach: pop to root and let user tap.
    // For a seamless experience, we'll use a callback if available.
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState != null) {
      // Navigate via notification pattern
      TabSwitchNotification(index).dispatch(context);
    }
  }

  Widget _buildRecommendations(ThemeData theme) {
    if (_loadingRecommendations) {
      return const SizedBox.shrink();
    }

    final recs = _recommendations;
    if (recs == null || recs.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = recs.items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recommended for You', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        ...displayItems.map(
          (rec) => Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _switchToTab(1), // Switch to Training tab
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: theme.colorScheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.exerciseName,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rec.reason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.theme,
  });

  final double value;
  final String label;
  final IconData icon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(height: 8),
          CountUpText(
            value: value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


