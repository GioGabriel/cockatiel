import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../ai_feedback_display/presentation/analysis_queue_page.dart';
import '../../analytics_dashboard/presentation/analytics_dashboard_page.dart';
import '../../karaoke_practice/presentation/karaoke_practice_page.dart';
import '../../user_profile/presentation/user_profile_page.dart';
import '../../vocal_training/presentation/vocal_training_page.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocal Coach'),
        actions: [
          AnimatedBuilder(
            animation: appState,
            builder: (_, __) {
              final pending = appState.pendingAIJobsCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnalysisQueuePage(
                            appState: appState,
                            apiClient: apiClient,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_motion_outlined),
                    tooltip: 'AI Queue',
                  ),
                  if (pending > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(appState: appState),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0C6A73), Color(0xFF1596A3)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x290C6A73),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user?.name ?? 'Singer'}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick your next session and keep building consistency with guided feedback.',
                  style: TextStyle(color: Color(0xFFE7FCFF), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Practice Modules', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          _ModuleCard(
            icon: Icons.mic_none_rounded,
            title: 'Vocal Coach',
            subtitle:
                'Vocal training, Do Re Mi pitch drills, and breathing exercises.',
            cta: 'Open Vocal Coach',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VocalTrainingPage(
                    apiClient: apiClient,
                    appState: appState,
                  ),
                ),
              );
            },
          ),
          _ModuleCard(
            icon: Icons.graphic_eq_rounded,
            title: 'Karaoke Practice',
            subtitle: 'Practice timing and expression in song-style drills.',
            cta: 'Start Karaoke',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KaraokePracticePage(
                    apiClient: apiClient,
                    appState: appState,
                  ),
                ),
              );
            },
          ),
          _ModuleCard(
            icon: Icons.trending_up_rounded,
            title: 'Analytics Dashboard',
            subtitle: 'Track streaks, trends, and score improvement over time.',
            cta: 'Open Analytics',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalyticsDashboardPage(apiClient: apiClient),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(icon, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(subtitle),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onTap,
              child: Text(cta),
            ),
          ],
        ),
      ),
    );
  }
}
