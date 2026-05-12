class AnalyticsSummary {
  final int totalReports;
  final int pendingCount;
  final int resolvedCount;
  final Map<String, int> topAreas;
  final Map<String, int> topIssuesGlobally;
  final Map<String, int> timeOfDayDistribution;

  AnalyticsSummary({
    required this.totalReports,
    required this.pendingCount,
    required this.resolvedCount,
    required this.topAreas,
    required this.topIssuesGlobally,
    required this.timeOfDayDistribution,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalReports: json['total_reports'],
      pendingCount: json['pending_count'],
      resolvedCount: json['resolved_count'],
      topAreas: Map<String, int>.from(
        (json['top_areas'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      ),
      topIssuesGlobally: Map<String, int>.from(
        (json['top_issues_globally'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      ),
      timeOfDayDistribution: Map<String, int>.from(
        (json['time_of_day_distribution'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      ),
    );
  }
}
