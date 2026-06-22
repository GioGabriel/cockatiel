class AnalyticsPrimaryMetric {
  AnalyticsPrimaryMetric({
    required this.metricKey,
    required this.label,
    required this.avgValue,
    required this.sessionCount,
  });

  final String metricKey;
  final String label;
  final double avgValue;
  final int sessionCount;

  factory AnalyticsPrimaryMetric.fromJson(Map<String, dynamic> json) {
    return AnalyticsPrimaryMetric(
      metricKey: json['metric_key'] as String,
      label: json['label'] as String,
      avgValue: (json['avg_value'] as num).toDouble(),
      sessionCount: (json['session_count'] as num).toInt(),
    );
  }
}

class AnalyticsRange {
  AnalyticsRange({
    required this.sessionCount,
    required this.avgScore,
    required this.avgPitchAccuracy,
    required this.avgTimingAccuracy,
    required this.avgBreathControl,
    required this.primaryMetrics,
    this.primaryMetricMode,
  });

  final int sessionCount;
  final double avgScore;
  final double avgPitchAccuracy;
  final double avgTimingAccuracy;
  final double avgBreathControl;
  final String? primaryMetricMode;
  final List<AnalyticsPrimaryMetric> primaryMetrics;

  factory AnalyticsRange.fromJson(Map<String, dynamic> json) {
    return AnalyticsRange(
      sessionCount: json['session_count'] as int,
      avgScore: (json['avg_score'] as num).toDouble(),
      avgPitchAccuracy: (json['avg_pitch_accuracy'] as num).toDouble(),
      avgTimingAccuracy: (json['avg_timing_accuracy'] as num).toDouble(),
      avgBreathControl: (json['avg_breath_control'] as num).toDouble(),
      primaryMetricMode: json['primary_metric_mode'] as String?,
      primaryMetrics:
          (json['primary_metrics'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => AnalyticsPrimaryMetric.fromJson(
                    item as Map<String, dynamic>,
                  ))
              .toList(),
    );
  }
}

class AnalyticsDashboard {
  AnalyticsDashboard({
    required this.userId,
    required this.totalCompletedSessions,
    required this.streakDays,
    required this.avgScore7d,
    required this.generatedAt,
    this.lastSessionAt,
    required this.ranges,
  });

  final String userId;
  final int totalCompletedSessions;
  final int streakDays;
  final double avgScore7d;
  final int? lastSessionAt;
  final int generatedAt;
  final Map<String, AnalyticsRange> ranges;

  factory AnalyticsDashboard.fromJson(Map<String, dynamic> json) {
    final rawRanges = json['ranges'] as Map<String, dynamic>? ?? {};
    final ranges = rawRanges.map(
      (key, value) => MapEntry(
        key,
        AnalyticsRange.fromJson(value as Map<String, dynamic>),
      ),
    );

    return AnalyticsDashboard(
      userId: json['user_id'] as String,
      totalCompletedSessions: json['total_completed_sessions'] as int,
      streakDays: json['streak_days'] as int,
      avgScore7d: (json['avg_score_7d'] as num).toDouble(),
      lastSessionAt: (json['last_session_at'] as num?)?.toInt(),
      ranges: ranges,
      generatedAt: (json['generated_at'] as num).toInt(),
    );
  }
}

class AnalyticsTrendPoint {
  AnalyticsTrendPoint({
    required this.date,
    required this.sessionCount,
    required this.avgScore,
    required this.avgPitchAccuracy,
    required this.avgTimingAccuracy,
    required this.avgBreathControl,
    required this.primaryMetrics,
    this.primaryMetricMode,
  });

  final String date;
  final int sessionCount;
  final double avgScore;
  final double avgPitchAccuracy;
  final double avgTimingAccuracy;
  final double avgBreathControl;
  final String? primaryMetricMode;
  final List<AnalyticsPrimaryMetric> primaryMetrics;

  factory AnalyticsTrendPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsTrendPoint(
      date: json['date'] as String,
      sessionCount: json['session_count'] as int,
      avgScore: (json['avg_score'] as num).toDouble(),
      avgPitchAccuracy: (json['avg_pitch_accuracy'] as num).toDouble(),
      avgTimingAccuracy: (json['avg_timing_accuracy'] as num).toDouble(),
      avgBreathControl: (json['avg_breath_control'] as num).toDouble(),
      primaryMetricMode: json['primary_metric_mode'] as String?,
      primaryMetrics:
          (json['primary_metrics'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => AnalyticsPrimaryMetric.fromJson(
                    item as Map<String, dynamic>,
                  ))
              .toList(),
    );
  }
}

class AnalyticsTrends {
  AnalyticsTrends({
    required this.userId,
    required this.range,
    required this.points,
    required this.generatedAt,
  });

  final String userId;
  final String range;
  final List<AnalyticsTrendPoint> points;
  final int generatedAt;

  factory AnalyticsTrends.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>)
        .map((item) =>
            AnalyticsTrendPoint.fromJson(item as Map<String, dynamic>))
        .toList();

    return AnalyticsTrends(
      userId: json['user_id'] as String,
      range: json['range'] as String,
      points: points,
      generatedAt: (json['generated_at'] as num).toInt(),
    );
  }
}
