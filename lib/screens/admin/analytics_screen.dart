import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../models/analytics.dart';
import '../../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsSummary? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = context.read<AuthProvider>().apiService;
      final data = await AnalyticsService(api).getAnalytics();
      setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics'), backgroundColor: AppTheme.surface.withValues(alpha: 0.8)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: AppTheme.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ]))
                : _data == null
                    ? const Center(child: Text('No data', style: TextStyle(color: AppTheme.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _buildStatusPie(),
                            const SizedBox(height: 28),
                            _buildBarChart('Top Areas', _data!.topAreas, AppTheme.primary),
                            const SizedBox(height: 28),
                            _buildBarChart('Issue Types', _data!.topIssuesGlobally, AppTheme.accent),
                            const SizedBox(height: 28),
                            _buildBarChart('Time of Day', _data!.timeOfDayDistribution, AppTheme.warning),
                            const SizedBox(height: 20),
                          ]),
                        ),
                      ),
      ),
    );
  }

  Widget _buildStatusPie() {
    final pending = _data!.pendingCount.toDouble();
    final resolved = _data!.resolvedCount.toDouble();
    final total = pending + resolved;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCard,
        child: const Center(child: Text('No reports yet', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Report Status', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 50,
            sections: [
              PieChartSectionData(value: pending, color: AppTheme.pending, title: '${(pending / total * 100).round()}%', titleStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), radius: 50),
              PieChartSectionData(value: resolved, color: AppTheme.resolved, title: '${(resolved / total * 100).round()}%', titleStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), radius: 50),
            ],
          )),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(AppTheme.pending, 'Pending (${ _data!.pendingCount})'),
          const SizedBox(width: 24),
          _legend(AppTheme.resolved, 'Resolved (${_data!.resolvedCount})'),
        ]),
      ]),
    );
  }

  Widget _legend(Color c, String l) {
    return Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), Text(l, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))]);
  }

  Widget _buildBarChart(String title, Map<String, int> data, Color color) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCard,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Center(child: Text('No data available', style: TextStyle(color: AppTheme.textSecondary))),
        ]),
      );
    }
    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        SizedBox(
          height: entries.length * 50.0 + 20,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, gIdx, rod, rIdx) {
                  final label = entries[group.x].key;
                  return BarTooltipItem('$label\n${rod.toY.round()}', const TextStyle(color: Colors.white, fontSize: 12));
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  final label = entries[idx].key;
                  final short = label.length > 12 ? '${label.substring(0, 10)}...' : label;
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(short, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), overflow: TextOverflow.ellipsis));
                },
                reservedSize: 32,
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (val, meta) => Text('${val.round()}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
            barGroups: entries.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: color, width: 20, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)))])).toList(),
          )),
        ),
      ]),
    );
  }
}
