import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/analytics_models.dart';
import '../../../shared/models/training_models.dart';

class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  static const _rangeOptions = ['7d', '30d', '90d'];
  static const _liveRefreshInterval = Duration(seconds: 15);

  bool _isLoading = true;
  String? _error;
  String _selectedRange = '30d';
  AnalyticsDashboard? _dashboard;
  AnalyticsTrends? _trends;
  TrainingProgress? _trainingProgress;
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _liveRefreshTimer = Timer.periodic(
      _liveRefreshInterval,
      (_) => _loadDashboard(showLoading: false),
    );
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard({bool showLoading = true}) async {
    if (_isLoading && !showLoading) {
      return;
    }

    setState(() {
      if (showLoading) {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final dashboardFuture = widget.apiClient.fetchAnalyticsDashboard();
      final trendsFuture =
          widget.apiClient.fetchAnalyticsTrends(range: _selectedRange);
      final trainingProgressFuture = widget.apiClient.fetchTrainingProgress();

      final dashboard = await dashboardFuture;
      final trends = await trendsFuture;
      final trainingProgress = await trainingProgressFuture;

      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = dashboard;
        _trends = trends;
        _trainingProgress = trainingProgress;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTrends(String range, {bool showLoading = true}) async {
    if (_isLoading && !showLoading) {
      return;
    }

    setState(() {
      _selectedRange = range;
      if (showLoading) {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final trends = await widget.apiClient.fetchAnalyticsTrends(range: range);
      if (!mounted) {
        return;
      }
      setState(() {
        _trends = trends;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final trends = _trends;
    final trainingProgress = _trainingProgress;

    final selectedRangeSummary = dashboard?.ranges[_selectedRange];
    final primaryMetrics = selectedRangeSummary?.primaryMetrics ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadDashboard(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading && dashboard == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && dashboard == null
                ? Center(
                    child: Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  )
                : ListView(
                    children: [
                      _KpiRow(
                        totalSessions: dashboard?.totalCompletedSessions ?? 0,
                        streakDays: dashboard?.streakDays ?? 0,
                        avgScore7d: dashboard?.avgScore7d ?? 0,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Trend Range: '),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedRange,
                            items: _rangeOptions
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    if (value == null ||
                                        value == _selectedRange) {
                                      return;
                                    }
                                    _loadTrends(value);
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedRangeSummary != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Summary $_selectedRange',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                    'Sessions: ${selectedRangeSummary.sessionCount}'),
                                Text(
                                    'Avg score: ${selectedRangeSummary.avgScore.toStringAsFixed(1)}'),
                                const SizedBox(height: 8),
                                Text(
                                  selectedRangeSummary.primaryMetricMode ==
                                          'breathing'
                                      ? 'Primary breathing metrics'
                                      : (selectedRangeSummary
                                                  .primaryMetricMode ==
                                              'voice'
                                          ? 'Primary voice metrics'
                                          : 'Primary metrics'),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                if (primaryMetrics.isNotEmpty)
                                  for (final metric in primaryMetrics)
                                    Text(
                                      '${metric.label}: ${metric.avgValue.toStringAsFixed(1)}',
                                    )
                                else ...[
                                  Text(
                                      'Pitch: ${selectedRangeSummary.avgPitchAccuracy.toStringAsFixed(1)}'),
                                  Text(
                                      'Timing: ${selectedRangeSummary.avgTimingAccuracy.toStringAsFixed(1)}'),
                                  Text(
                                      'Breath: ${selectedRangeSummary.avgBreathControl.toStringAsFixed(1)}'),
                                ],
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text('Vocal Training Progress',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (trainingProgress == null)
                        const Text('No training progress loaded yet.')
                      else if (trainingProgress.items.isEmpty)
                        const Text('No completed training sessions yet.')
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final item
                                    in trainingProgress.items.take(5))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${item.exerciseName}: best ${item.bestScore.toStringAsFixed(1)} | avg ${item.avgScore.toStringAsFixed(1)} | sessions ${item.sessionsCompleted}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text('Score Trend',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      if (trends != null)
                        ...trends.points
                            .map((point) => _TrendRow(point: point)),
                    ],
                  ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalSessions,
    required this.streakDays,
    required this.avgScore7d,
  });

  final int totalSessions;
  final int streakDays;
  final double avgScore7d;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _KpiCard(label: 'Completed', value: '$totalSessions')),
        const SizedBox(width: 8),
        Expanded(child: _KpiCard(label: 'Streak', value: '$streakDays d')),
        const SizedBox(width: 8),
        Expanded(
            child: _KpiCard(
                label: 'Avg 7d', value: avgScore7d.toStringAsFixed(1))),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.point});

  final AnalyticsTrendPoint point;

  @override
  Widget build(BuildContext context) {
    final chartValue =
        point.avgScore <= 0 ? 0.01 : (point.avgScore / 100).clamp(0.0, 1.0);
    final dateLabel =
        point.date.length >= 10 ? point.date.substring(5) : point.date;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(dateLabel)),
          Expanded(
            child: LinearProgressIndicator(value: chartValue),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              '${point.avgScore.toStringAsFixed(1)} (${point.sessionCount})',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
