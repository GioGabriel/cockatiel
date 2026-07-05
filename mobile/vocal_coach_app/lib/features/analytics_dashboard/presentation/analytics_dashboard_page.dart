import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:vocal_coach_app/shared/animations/metric_animator.dart';
import 'package:vocal_coach_app/shared/widgets/empty_state_view.dart';
import 'package:vocal_coach_app/shared/widgets/shimmer_skeleton.dart';

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
  static const _rangeLabels = {'7d': 'Weekly', '30d': 'Monthly', '90d': '90 Days'};

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
    _loadAll();
    _liveRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadAll(showLoading: false),
    );
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll({bool showLoading = true}) async {
    if (_isLoading && !showLoading) return;

    setState(() {
      if (showLoading) _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.apiClient.fetchAnalyticsDashboard(),
        widget.apiClient.fetchAnalyticsTrends(range: _selectedRange),
        widget.apiClient.fetchTrainingProgress(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as AnalyticsDashboard;
        _trends = results[1] as AnalyticsTrends;
        _trainingProgress = results[2] as TrainingProgress;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _switchRange(String range) async {
    if (range == _selectedRange) return;
    setState(() => _selectedRange = range);
    try {
      final trends = await widget.apiClient.fetchAnalyticsTrends(range: range);
      if (!mounted) return;
      setState(() => _trends = trends);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFB),
        title: const Text('Analytics'),
      ),
      body: _isLoading && _dashboard == null
          ? _buildShimmer(theme)
          : _error != null && _dashboard == null
              ? _buildError(theme)
              : _hasNoData()
                  ? EmptyStateView(
                      headline: 'No analytics yet',
                      body: 'Complete your first session to see stats here.',
                      ctaLabel: 'Start Training',
                      onCtaTap: () => Navigator.of(context).pop(),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadAll(),
                      child: _buildContent(theme),
                    ),
    );
  }

  bool _hasNoData() {
    return (_dashboard?.totalCompletedSessions ?? 0) == 0 &&
        (_trends?.points.isEmpty ?? true) &&
        (_trainingProgress?.items.isEmpty ?? true);
  }

  Widget _buildShimmer(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ShimmerSkeleton(
        child: Column(
          children: [
            SkeletonShapes.statRow(theme: theme),
            const SizedBox(height: 16),
            SkeletonShapes.chartBlock(theme: theme),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('Could not load analytics.'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _loadAll(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final dashboard = _dashboard!;
    final rangeSummary = dashboard.ranges[_selectedRange];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ─── KPI CARDS ───────────────────────────────────────────
        _buildKpiSection(theme, dashboard),
        const SizedBox(height: 24),

        // ─── PERIOD TOGGLE ───────────────────────────────────────
        _buildPeriodToggle(theme),
        const SizedBox(height: 20),

        // ─── SCORE TREND CHART ───────────────────────────────────
        if (_trends != null && _trends!.points.isNotEmpty)
          _buildTrendChart(theme),
        const SizedBox(height: 24),

        // ─── METRICS BREAKDOWN ───────────────────────────────────
        if (rangeSummary != null) _buildMetricsBreakdown(theme, rangeSummary),
        const SizedBox(height: 24),

        // ─── TRAINING PROGRESS ───────────────────────────────────
        if (_trainingProgress != null &&
            _trainingProgress!.items.isNotEmpty)
          _buildTrainingProgress(theme),
      ],
    );
  }

  Widget _buildKpiSection(ThemeData theme, AnalyticsDashboard dashboard) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Total Sessions',
            value: dashboard.totalCompletedSessions.toString(),
            icon: Icons.headphones_rounded,
            iconColor: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'Day Streak',
            value: dashboard.streakDays.toString(),
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF6B35),
            subtitle: dashboard.streakDays > 0 ? 'Keep it up!' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'Avg Score',
            value: dashboard.avgScore7d.toStringAsFixed(1),
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFE1B261),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _rangeOptions.map((range) {
          final isSelected = range == _selectedRange;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchRange(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _rangeLabels[range] ?? range,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendChart(ThemeData theme) {
    final points = _trends!.points;
    final scores = points.map((p) => p.avgScore).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Score Trend', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (scores.length >= 2)
                _ChangeIndicator(
                  current: scores.last,
                  previous: scores[scores.length - 2],
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                values: scores,
                lineColor: theme.colorScheme.primary,
                fillColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(points.first.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _formatDate(points.last.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBreakdown(ThemeData theme, AnalyticsRange range) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Metrics', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Pitch Accuracy',
            value: range.avgPitchAccuracy,
            color: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 14),
          _MetricRow(
            label: 'Timing Accuracy',
            value: range.avgTimingAccuracy,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          _MetricRow(
            label: 'Breath Control',
            value: range.avgBreathControl,
            color: const Color(0xFF4CAF50),
          ),
          if (range.primaryMetrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            for (final metric in range.primaryMetrics.take(3)) ...[
              _MetricRow(
                label: metric.label,
                value: metric.avgValue,
                color: const Color(0xFFFF6B35),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTrainingProgress(ThemeData theme) {
    final items = _trainingProgress!.items.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Exercise Progress', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.exerciseName,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.sessionsCompleted} sessions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.bestScore.toStringAsFixed(1),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'best score',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: AnimatedProgressRing(
                      progress: (item.bestScore / 100).clamp(0.0, 1.0),
                      size: 36,
                      strokeWidth: 4,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.length < 10) return isoDate;
    final parts = isoDate.substring(5).split('-');
    if (parts.length == 2) return '${parts[1]}/${parts[0]}';
    return isoDate.substring(5);
  }
}

// ─── SUPPORTING WIDGETS ──────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF4CAF50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeIndicator extends StatelessWidget {
  const _ChangeIndicator({required this.current, required this.previous});

  final double current;
  final double previous;

  @override
  Widget build(BuildContext context) {
    if (previous <= 0) return const SizedBox.shrink();
    final change = ((current - previous) / previous * 100);
    final isPositive = change >= 0;
    final color = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${change.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (value / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height -
          ((values[i] - minVal) / effectiveRange) * size.height;
      points.add(Offset(x, y));
    }

    // Fill
    final fillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // End dot
    canvas.drawCircle(
      points.last,
      4,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
