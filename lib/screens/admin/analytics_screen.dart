import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/analytics.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _background = Color(0xFFF6F8FB);
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE7EBF1);
  static const _green = Color(0xFF12B76A);
  static const _amber = Color(0xFFF79009);
  static const _red = Color(0xFFF04438);
  static const _purple = Color(0xFF7A5AF8);
  static const _teal = Color(0xFF078A83);
  static const _cardShadow = BoxShadow(
    color: Color(0x0A172033),
    blurRadius: 18,
    offset: Offset(0, 5),
  );

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AnalyticsSummary? _analytics;
  List<Report>? _reports;
  int? _unreadCount;
  String? _analyticsError;
  String? _reportsError;
  bool _analyticsLoading = true;
  bool _reportsLoading = true;
  bool _notificationsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAnalytics(), _loadReports(), _loadUnreadCount()]);
  }

  Future<void> _loadAnalytics() async {
    if (mounted) {
      setState(() {
        _analyticsLoading = true;
        _analyticsError = null;
      });
    }
    try {
      final result = await AnalyticsService(
        context.read<AuthProvider>().apiService,
      ).getAnalytics();
      if (mounted) {
        setState(() {
          _analytics = result;
          _analyticsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _analytics = null;
          _analyticsLoading = false;
          _analyticsError = 'Analytics could not be loaded. Please try again.';
        });
      }
    }
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _reportsLoading = true;
        _reportsError = null;
      });
    }
    try {
      final result = await ReportService(
        context.read<AuthProvider>().apiService,
      ).getAllReports();
      if (mounted) {
        setState(() {
          _reports = result;
          _reportsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports = null;
          _reportsLoading = false;
          _reportsError = 'Report records could not be loaded.';
        });
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final notifications = await NotificationService(
        context.read<AuthProvider>().apiService,
      ).getMyNotifications();
      if (mounted) {
        setState(() {
          _unreadCount = notifications.where((item) => !item.isRead).length;
          _notificationsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unreadCount = null;
          _notificationsLoading = false;
        });
      }
    }
  }

  Future<void> _navigate(String route) async {
    _closeDrawer();
    await Navigator.pushNamed(context, route);
    if (route == '/notifications') _loadUnreadCount();
  }

  void _closeDrawer() {
    if (MediaQuery.sizeOf(context).width < 1100) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _showProfile(String adminName) {
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                adminName,
                style: const TextStyle(
                  color: _text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: _blue),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Map<String, int> _departmentCounts() {
    final counts = <String, int>{};
    for (final report in _reports ?? const <Report>[]) {
      final department = report.serviceDepartment?.trim();
      if (department != null && department.isNotEmpty) {
        counts.update(department, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Map<String, int> _severityCounts() {
    final counts = <String, int>{};
    for (final report in _reports ?? const <Report>[]) {
      final severity = report.severity?.trim();
      if (severity != null && severity.isNotEmpty) {
        final label = _displayName(severity);
        counts.update(label, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  List<MapEntry<DateTime, int>> _dailyTrend() {
    final counts = <DateTime, int>{};
    for (final report in _reports ?? const <Report>[]) {
      final created = report.createdAt.toLocal();
      final date = DateTime(created.year, created.month, created.day);
      counts.update(date, (count) => count + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.length <= 14
        ? entries
        : entries.sublist(entries.length - 14);
  }

  List<MapEntry<String, int>> _sortedEntries(Map<String, int> values) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<MapEntry<String, int>> _areaEntries() {
    final counts = <String, int>{};
    for (final entry
        in _analytics?.topAreas.entries ?? const <MapEntry<String, int>>[]) {
      final rawName = entry.key.trim();
      final name = rawName.isEmpty || rawName.toLowerCase() == 'null'
          ? 'Area unavailable'
          : rawName;
      counts.update(
        name,
        (count) => count + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return _sortedEntries(counts);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1100;
    final user = context.watch<AuthProvider>().user;
    final adminName = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!.trim()
        : 'Administrator';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: desktop ? null : Drawer(child: _buildSidebar()),
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  SizedBox(width: 228, child: _buildSidebar()),
                  Expanded(child: _buildMainArea(adminName, desktop: true)),
                ],
              )
            : _buildMainArea(adminName, desktop: false),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: _navy,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/civisense_logo.svg',
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.public_rounded, color: _blue),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CiviSense AI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Admin Portal',
                        style: TextStyle(
                          color: Color(0xFFAAB7C9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sidebarItem(
            Icons.home_outlined,
            'Dashboard',
            onTap: () => _navigate('/admin'),
          ),
          _sidebarItem(
            Icons.assignment_outlined,
            'Reports Management',
            onTap: () => _navigate('/admin/reports'),
          ),
          _sidebarItem(
            Icons.analytics_outlined,
            'GIS & Analytics',
            selected: true,
            onTap: _closeDrawer,
          ),
          _sidebarItem(
            Icons.people_outline_rounded,
            'Officers Management',
            onTap: () => _navigate('/admin/officers'),
          ),
          _sidebarItem(
            Icons.notifications_none_rounded,
            'Notifications',
            onTap: () => _navigate('/notifications'),
            badge: _unreadCount,
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Color(0x263C4C62), height: 1),
          ),
          const SizedBox(height: 12),
          _sidebarItem(Icons.logout_rounded, 'Logout', onTap: _logout),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool selected = false,
    int? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Material(
        color: selected ? _blue : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 43,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge != null && badge > 0) _badge(badge, compact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea(String adminName, {required bool desktop}) {
    return Column(
      children: [
        _buildHeader(adminName, desktop: desktop),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            color: _blue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                desktop ? 20 : 16,
                20,
                desktop ? 20 : 16,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeading(),
                      const SizedBox(height: 20),
                      _buildKpis(),
                      const SizedBox(height: 16),
                      _buildChartRows(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String adminName, {required bool desktop}) {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 22 : 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (!desktop)
            IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
              color: _navy,
              tooltip: 'Open navigation',
            )
          else
            const Icon(Icons.menu_rounded, color: _muted, size: 21),
          const SizedBox(width: 18),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFE9EDF3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: _muted, size: 18),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Search reports, locations, departments, or users...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _navigate('/notifications'),
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: _navy,
                  size: 22,
                ),
                if (_unreadCount != null && _unreadCount! > 0)
                  Positioned(top: -5, right: -7, child: _badge(_unreadCount!)),
                if (_notificationsLoading)
                  const Positioned(
                    top: -4,
                    right: -4,
                    child: SizedBox(
                      width: 9,
                      height: 9,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: () => _showProfile(adminName),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: _blue,
                    child: Text(
                      adminName.isEmpty ? 'A' : adminName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >= 650) ...[
                    const SizedBox(width: 9),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'System Admin',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(int count, {bool compact = false}) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 17 : 18),
      height: compact ? 17 : 18,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPageHeading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                color: _text,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Insights into civic reports, status, issue types and reported areas.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        );
        final dataScope = Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dataset_outlined, color: _blue, size: 16),
              SizedBox(width: 7),
              Text(
                'All available data',
                style: TextStyle(
                  color: _text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 12), dataScope],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            dataScope,
          ],
        );
      },
    );
  }

  Widget _buildKpis() {
    final analytics = _analytics;
    final kpis = [
      _KpiData(
        title: 'Total Reports',
        value: analytics?.totalReports,
        icon: Icons.description_outlined,
        color: _blue,
        loading: _analyticsLoading,
      ),
      _KpiData(
        title: 'Pending Reports',
        value: analytics?.pendingCount,
        icon: Icons.schedule_rounded,
        color: _amber,
        loading: _analyticsLoading,
      ),
      _KpiData(
        title: 'Resolved Reports',
        value: analytics?.resolvedCount,
        icon: Icons.check_circle_outline_rounded,
        color: _green,
        loading: _analyticsLoading,
      ),
      _KpiData(
        title: 'Issue Types',
        value: analytics?.topIssuesGlobally.length,
        icon: Icons.category_outlined,
        color: _purple,
        loading: _analyticsLoading,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in kpis)
              SizedBox(width: width, child: _kpiCard(item)),
          ],
        );
      },
    );
  }

  Widget _kpiCard(_KpiData item) {
    return Container(
      height: 94,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                if (item.loading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _blue,
                    ),
                  )
                else
                  Text(
                    item.value?.toString() ?? '—',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartRows() {
    final chartCards = [
      _trendCard(),
      _statusCard(),
      _derivedDistributionCard(
        title: 'Severity Distribution',
        subtitle: 'From severity labels present on reports',
        icon: Icons.priority_high_rounded,
        color: _red,
        values: _severityCounts(),
      ),
      _distributionCard(
        title: 'Reports by Issue Type',
        subtitle: 'Counts returned by analytics',
        icon: Icons.category_outlined,
        color: _blue,
        values: _analytics?.topIssuesGlobally ?? const {},
      ),
      _derivedDistributionCard(
        title: 'Reports by Department',
        subtitle: 'Based on assigned service department',
        icon: Icons.apartment_rounded,
        color: _purple,
        values: _departmentCounts(),
      ),
      _distributionCard(
        title: 'Reports by Location',
        subtitle: 'Top areas from analytics; not hotspot analysis',
        icon: Icons.place_outlined,
        color: _teal,
        values: Map<String, int>.fromEntries(_areaEntries()),
      ),
      _distributionCard(
        title: 'Reports by Time of Day',
        subtitle: 'Created-report time buckets returned by analytics',
        icon: Icons.access_time_rounded,
        color: _amber,
        values: _analytics?.timeOfDayDistribution ?? const {},
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 950 ? 2 : 1;
        if (columns == 1) {
          return Column(
            children: [
              for (var index = 0; index < chartCards.length; index++) ...[
                chartCards[index],
                if (index != chartCards.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var index = 0; index < chartCards.length; index += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: chartCards[index]),
                const SizedBox(width: 14),
                Expanded(
                  child: index + 1 < chartCards.length
                      ? chartCards[index + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
          if (index + 2 < chartCards.length) {
            rows.add(const SizedBox(height: 14));
          }
        }
        return Column(children: rows);
      },
    );
  }

  Widget _trendCard() {
    if (_reportsLoading) {
      return _chartCard(
        title: 'Reports Trend',
        subtitle: 'Daily totals from the latest dates with submissions',
        icon: Icons.show_chart_rounded,
        child: const _PanelLoading(),
      );
    }
    if (_reportsError != null || _reports == null) {
      return _chartCard(
        title: 'Reports Trend',
        subtitle: 'Daily totals from loaded report records',
        icon: Icons.show_chart_rounded,
        child: _panelMessage(
          _reportsError ?? 'Report records are unavailable.',
        ),
      );
    }
    final entries = _dailyTrend();
    if (entries.isEmpty) {
      return _chartCard(
        title: 'Reports Trend',
        subtitle: 'Daily totals from the latest dates with submissions',
        icon: Icons.show_chart_rounded,
        child: _panelMessage('No report timestamps are available to chart.'),
      );
    }
    if (entries.length == 1) {
      return _chartCard(
        title: 'Reports Trend',
        subtitle: 'Daily totals from the latest dates with submissions',
        icon: Icons.show_chart_rounded,
        child: _panelMessage(
          'A trend needs reports on at least two different dates.',
        ),
      );
    }

    final maxValue = entries
        .map((entry) => entry.value)
        .reduce(math.max)
        .toDouble();
    final dateFormat = DateFormat('MMM d');
    final spots = entries
        .asMap()
        .entries
        .map(
          (entry) => FlSpot(entry.key.toDouble(), entry.value.value.toDouble()),
        )
        .toList();
    return _chartCard(
      title: 'Reports Trend',
      subtitle: 'Daily totals from the latest dates with submissions',
      icon: Icons.show_chart_rounded,
      child: SizedBox(
        height: 230,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (entries.length - 1).toDouble(),
            minY: 0,
            maxY: maxValue == 0 ? 1 : maxValue * 1.18,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) => touchedSpots
                    .map(
                      (spot) => LineTooltipItem(
                        '${dateFormat.format(entries[spot.x.toInt()].key)}\n${spot.y.toInt()} reports',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0xFFEFF2F6), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: math.max(1, (entries.length / 5).ceil()).toDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dateFormat.format(entries[index].key),
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: _blue,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeColor: _blue,
                        strokeWidth: 2,
                      ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: _blue.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final analytics = _analytics;
    if (_analyticsLoading) {
      return _chartCard(
        title: 'Status Distribution',
        subtitle: 'Counts by supported report status',
        icon: Icons.donut_small_rounded,
        child: const _PanelLoading(),
      );
    }
    if (analytics == null) {
      return _chartCard(
        title: 'Status Distribution',
        subtitle: 'Counts by supported report status',
        icon: Icons.donut_small_rounded,
        child: _panelMessage(
          _analyticsError ?? 'Status analytics are unavailable.',
          onRetry: _loadAnalytics,
        ),
      );
    }
    final pending = analytics.pendingCount;
    final resolved = analytics.resolvedCount;
    final total = pending + resolved;
    if (total <= 0) {
      return _chartCard(
        title: 'Status Distribution',
        subtitle: 'Counts by supported report status',
        icon: Icons.donut_small_rounded,
        child: _panelMessage('No reports are available for this breakdown.'),
      );
    }

    final slices = <_StatusSlice>[
      if (pending > 0) _StatusSlice('Pending', pending, _amber),
      if (resolved > 0) _StatusSlice('Resolved', resolved, _green),
    ];
    return _chartCard(
      title: 'Status Distribution',
      subtitle: 'Counts by supported report status',
      icon: Icons.donut_small_rounded,
      child: SizedBox(
        height: 230,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 48,
                  sections: slices
                      .map(
                        (slice) => PieChartSectionData(
                          value: slice.count.toDouble(),
                          color: slice.color,
                          title: '${(slice.count / total * 100).round()}%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          radius: 42,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final slice in slices)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: _distributionLegend(
                        slice.label,
                        slice.count,
                        slice.color,
                        total,
                      ),
                    ),
                  const Divider(height: 20, color: _border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: _text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _distributionLegend(String label, int value, Color color, int total) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$value (${(value / total * 100).round()}%)',
          style: const TextStyle(
            color: _text,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _derivedDistributionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Map<String, int> values,
  }) {
    if (_reportsLoading) {
      return _chartCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        child: const _PanelLoading(),
      );
    }
    if (_reportsError != null || _reports == null) {
      return _chartCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        child: _panelMessage(
          _reportsError ?? 'Report records are unavailable.',
        ),
      );
    }
    return _distributionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      values: values,
    );
  }

  Widget _distributionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Map<String, int> values,
  }) {
    if (_analyticsLoading &&
        (title == 'Reports by Issue Type' ||
            title == 'Reports by Location' ||
            title == 'Reports by Time of Day')) {
      return _chartCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        child: const _PanelLoading(),
      );
    }
    if (_analyticsError != null &&
        (title == 'Reports by Issue Type' ||
            title == 'Reports by Location' ||
            title == 'Reports by Time of Day')) {
      return _chartCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        child: _panelMessage(_analyticsError!, onRetry: _loadAnalytics),
      );
    }
    final entries = _sortedEntries(
      values,
    ).where((entry) => entry.value >= 0).take(8).toList();
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    if (entries.isEmpty || total == 0) {
      return _chartCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        child: _panelMessage('No data available for this breakdown.'),
      );
    }
    final maxValue = entries
        .map((entry) => entry.value)
        .reduce(math.max)
        .toDouble();
    return _chartCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _distributionRow(
              entry: entries[index],
              total: total,
              maxValue: maxValue,
              color: color,
            ),
            if (index != entries.length - 1) const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }

  Widget _distributionRow({
    required MapEntry<String, int> entry,
    required int total,
    required double maxValue,
    required Color color,
  }) {
    final fraction = maxValue <= 0
        ? 0.0
        : (entry.value / maxValue).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            _displayName(entry.key),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _text, fontSize: 11),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  const ColoredBox(color: Color(0xFFF0F3F7)),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 64,
          child: Text(
            '${entry.value}  ${(entry.value / total * 100).round()}%',
            textAlign: TextAlign.right,
            maxLines: 1,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 27),
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }

  Widget _panelMessage(String message, {VoidCallback? onRetry}) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                onRetry == null
                    ? Icons.bar_chart_rounded
                    : Icons.cloud_off_outlined,
                color: const Color(0xFF98A2B3),
                size: 24,
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 10),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
      boxShadow: const [_cardShadow],
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.loading,
  });

  final String title;
  final int? value;
  final IconData icon;
  final Color color;
  final bool loading;
}

class _StatusSlice {
  const _StatusSlice(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(
        child: CircularProgressIndicator(
          color: _AnalyticsScreenState._blue,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
