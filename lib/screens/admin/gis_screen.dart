import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/analytics.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';
import '../citizen/report_detail_screen.dart';

class GisScreen extends StatefulWidget {
  const GisScreen({super.key});

  @override
  State<GisScreen> createState() => _GisScreenState();
}

class _GisScreenState extends State<GisScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _background = Color(0xFFF6F8FB);
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE7EBF1);
  static const _red = Color(0xFFF04438);
  static const _amber = Color(0xFFF79009);
  static const _green = Color(0xFF12B76A);
  static const _neutral = Color(0xFF667085);
  static const _allFilter = '__all__';
  static const _cardShadow = BoxShadow(
    color: Color(0x0A172033),
    blurRadius: 18,
    offset: Offset(0, 5),
  );

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapController = MapController();

  AnalyticsSummary? _analytics;
  List<Report>? _reports;
  int? _unreadCount;
  String? _reportsError;
  bool _reportsLoading = true;
  bool _analyticsLoading = true;
  bool _notificationsLoading = true;
  bool _mapReady = false;

  String? _departmentFilter;
  String? _categoryFilter;
  String? _statusFilter;
  String? _priorityFilter;
  String? _severityFilter;
  DateTimeRange? _dateRange;
  int? _selectedReportId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadReports(), _loadAnalytics(), _loadUnreadCount()]);
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _reportsLoading = true;
        _reportsError = null;
      });
    }
    try {
      final reports = await ReportService(
        context.read<AuthProvider>().apiService,
      ).getAllReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _reportsLoading = false;
          if (_selectedReportId != null &&
              !reports.any((report) => report.id == _selectedReportId)) {
            _selectedReportId = null;
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports = null;
          _reportsLoading = false;
          _reportsError = 'Reports could not be loaded. Please try again.';
        });
      }
    }
  }

  Future<void> _loadAnalytics() async {
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
      if (mounted) setState(() => _analyticsLoading = false);
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

  String _formatLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String? _category(Report report) {
    if (report.detections.isNotEmpty) {
      final value = report.detections.first.issueType.trim();
      if (value.isNotEmpty) return _formatLabel(value);
    }
    final value = report.triageCategory?.trim();
    return value == null || value.isEmpty ? null : _formatLabel(value);
  }

  String? _department(Report report) {
    final value = report.serviceDepartment?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _priority(Report report) {
    final value = report.priorityAdvisory?.level.trim();
    return value == null || value.isEmpty ? null : value.toUpperCase();
  }

  String? _severity(Report report) {
    final value = report.severity?.trim();
    return value == null || value.isEmpty ? null : _formatLabel(value);
  }

  bool _hasValidCoordinates(Report report) {
    return report.latitude.isFinite &&
        report.longitude.isFinite &&
        report.latitude >= -90 &&
        report.latitude <= 90 &&
        report.longitude >= -180 &&
        report.longitude <= 180;
  }

  List<Report> get _validReports =>
      (_reports ?? const <Report>[]).where(_hasValidCoordinates).toList();

  List<Report> get _filteredReports {
    final reports = List<Report>.of(_reports ?? const <Report>[]);
    final filtered = reports.where((report) {
      final matchesDepartment =
          _departmentFilter == null || _department(report) == _departmentFilter;
      final matchesCategory =
          _categoryFilter == null || _category(report) == _categoryFilter;
      final matchesStatus =
          _statusFilter == null ||
          report.status.toLowerCase() == _statusFilter!.toLowerCase();
      final matchesPriority =
          _priorityFilter == null || _priority(report) == _priorityFilter;
      final matchesSeverity =
          _severityFilter == null || _severity(report) == _severityFilter;
      final createdAt = report.createdAt.toLocal();
      final matchesDate =
          _dateRange == null ||
          (!createdAt.isBefore(_dateRange!.start) &&
              !createdAt.isAfter(
                DateTime(
                  _dateRange!.end.year,
                  _dateRange!.end.month,
                  _dateRange!.end.day,
                  23,
                  59,
                  59,
                  999,
                ),
              ));
      return matchesDepartment &&
          matchesCategory &&
          matchesStatus &&
          matchesPriority &&
          matchesSeverity &&
          matchesDate;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  List<Report> get _mappedFilteredReports =>
      _filteredReports.where(_hasValidCoordinates).toList();

  List<Report> get _recentMappedReports =>
      _mappedFilteredReports.take(8).toList();

  List<String> _distinctValues(String? Function(Report) getter) {
    final values =
        (_reports ?? const <Report>[])
            .map(getter)
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _departments => _distinctValues(_department);
  List<String> get _categories => _distinctValues(_category);
  List<String> get _statuses => _distinctValues((report) => report.status);
  List<String> get _priorities => _distinctValues(_priority);
  List<String> get _severities => _distinctValues(_severity);
  bool get _hasFilters =>
      _departmentFilter != null ||
      _categoryFilter != null ||
      _statusFilter != null ||
      _priorityFilter != null ||
      _severityFilter != null ||
      _dateRange != null;

  int get _highPriorityCount => (_reports ?? const <Report>[])
      .where((report) => _priority(report) == 'HIGH')
      .length;

  LatLng get _mapCenter {
    final reports = _mappedFilteredReports;
    if (reports.isEmpty) return const LatLng(0, 0);
    final lat =
        reports
            .map((report) => report.latitude)
            .reduce((sum, value) => sum + value) /
        reports.length;
    final lon =
        reports
            .map((report) => report.longitude)
            .reduce((sum, value) => sum + value) /
        reports.length;
    return LatLng(lat, lon);
  }

  Color _priorityColor(Report report) {
    switch (_priority(report)) {
      case 'HIGH':
        return _red;
      case 'MEDIUM':
        return _amber;
      case 'LOW':
        return _green;
      default:
        return _neutral;
    }
  }

  void _selectReport(Report report) {
    setState(() => _selectedReportId = report.id);
    if (_mapReady) {
      _mapController.move(
        LatLng(report.latitude, report.longitude),
        math.max(_mapController.camera.zoom, 13),
      );
    }
  }

  void _openReport(Report report) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report),
      ),
    );
  }

  Future<void> _chooseDateRange() async {
    final reports = _reports ?? const <Report>[];
    if (reports.isEmpty) return;
    final createdDates = reports
        .map((report) => report.createdAt.toLocal())
        .toList();
    final earliest = createdDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = createdDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final firstDate = DateTime(earliest.year, earliest.month, earliest.day);
    final lastDate = DateTime(latest.year, latest.month, latest.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate.isBefore(firstDate) ? firstDate : lastDate,
      initialDateRange: _dateRange == null
          ? null
          : DateTimeRange(
              start: _dateRange!.start.isBefore(firstDate)
                  ? firstDate
                  : _dateRange!.start,
              end: _dateRange!.end.isAfter(lastDate)
                  ? lastDate
                  : _dateRange!.end,
            ),
      helpText: 'Filter by report submission date',
      saveText: 'Apply',
    );
    if (!mounted) return;
    if (range != null) {
      setState(() => _dateRange = range);
      WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
    }
  }

  void _refitMap() {
    if (!_mapReady) return;
    final visible = _mappedFilteredReports;
    if (visible.isEmpty) return;

    if (visible.length == 1) {
      _mapController.move(
        LatLng(visible.first.latitude, visible.first.longitude),
        14.0,
      );
      return;
    }

    double minLat = visible.first.latitude;
    double maxLat = visible.first.latitude;
    double minLon = visible.first.longitude;
    double maxLon = visible.first.longitude;

    for (final r in visible) {
      if (r.latitude < minLat) minLat = r.latitude;
      if (r.latitude > maxLat) maxLat = r.latitude;
      if (r.longitude < minLon) minLon = r.longitude;
      if (r.longitude > maxLon) maxLon = r.longitude;
    }

    // Handle multiple reports with identical coordinates (degenerate bounds)
    if ((maxLat - minLat).abs() < 0.0001 && (maxLon - minLon).abs() < 0.0001) {
      _mapController.move(LatLng(minLat, minLon), 14.0);
      return;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
          maxZoom: 15.0,
        ),
      );
    } catch (_) {
      final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
      _mapController.move(center, 11.0);
    }
  }

  void _clearFilters() {
    setState(() {
      _departmentFilter = null;
      _categoryFilter = null;
      _statusFilter = null;
      _priorityFilter = null;
      _severityFilter = null;
      _dateRange = null;
      _selectedReportId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
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
                desktop ? 20 : 14,
                18,
                desktop ? 20 : 14,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeading(),
                      const SizedBox(height: 16),
                      _buildSummaryCards(),
                      const SizedBox(height: 14),
                      _buildFilters(),
                      const SizedBox(height: 14),
                      _buildMapAndRecent(desktop: desktop),
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
      padding: EdgeInsets.symmetric(horizontal: desktop ? 22 : 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (!desktop)
            IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: _navy),
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
                        'Search reports, locations, departments, or citizens...',
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
          const SizedBox(width: 9),
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
          InkWell(
            onTap: () => _showProfile(adminName),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
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
        count > 99 ? '99+' : '$count',
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
        final narrow = constraints.maxWidth < 620;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GIS & Incident Map',
              style: TextStyle(
                color: _text,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Explore the geographic distribution of reported civic issues.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        );
        final analyticsLink = OutlinedButton.icon(
          onPressed: () => _navigate('/admin/analytics'),
          icon: const Icon(Icons.analytics_outlined, size: 16),
          label: const Text('Analytics'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _blue,
            side: const BorderSide(color: Color(0xFFD7E3F8)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            textStyle: const TextStyle(fontSize: 11),
          ),
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 10), analyticsLink],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            analyticsLink,
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards() {
    final data = _analytics;
    final cards = [
      _Kpi(
        title: 'Total Reports',
        value: data?.totalReports,
        icon: Icons.description_outlined,
        color: _blue,
        loading: _analyticsLoading,
      ),
      _Kpi(
        title: 'High Priority',
        value: _reports == null ? null : _highPriorityCount,
        icon: Icons.location_on_outlined,
        color: _red,
        loading: _reportsLoading,
      ),
      _Kpi(
        title: 'Pending Reports',
        value: data?.pendingCount,
        icon: Icons.schedule_rounded,
        color: _amber,
        loading: _analyticsLoading,
      ),
      _Kpi(
        title: 'Resolved Reports',
        value: data?.resolvedCount,
        icon: Icons.check_circle_outline_rounded,
        color: _green,
        loading: _analyticsLoading,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in cards)
              SizedBox(width: width, child: _kpiCard(item)),
          ],
        );
      },
    );
  }

  Widget _kpiCard(_Kpi item) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 5),
                if (item.loading)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: _blue,
                      strokeWidth: 2,
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

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final columns = constraints.maxWidth >= 1120
              ? 6
              : constraints.maxWidth >= 650
              ? 3
              : constraints.maxWidth >= 400
              ? 2
              : 1;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(
                spacing: gap,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: _filterDropdown(
                      label: 'All Departments',
                      options: _departments,
                      value: _departmentFilter,
                      onChanged: (value) {
                        setState(() => _departmentFilter = value);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filterDropdown(
                      label: 'All Categories',
                      options: _categories,
                      value: _categoryFilter,
                      onChanged: (value) {
                        setState(() => _categoryFilter = value);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filterDropdown(
                      label: 'All Status',
                      options: _statuses,
                      value: _statusFilter,
                      onChanged: (value) {
                        setState(() => _statusFilter = value);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filterDropdown(
                      label: 'All Priority',
                      options: _priorities,
                      value: _priorityFilter,
                      onChanged: (value) {
                        setState(() => _priorityFilter = value);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filterDropdown(
                      label: 'All Severity',
                      options: _severities,
                      value: _severityFilter,
                      onChanged: (value) {
                        setState(() => _severityFilter = value);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
                      },
                    ),
                  ),
                  SizedBox(width: width, child: _dateFilterButton()),
                ],
              ),
              if (_hasFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all_rounded, size: 15),
                  label: const Text('Clear filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    textStyle: const TextStyle(fontSize: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final selectedValue = value != null && options.contains(value)
        ? value
        : _allFilter;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$selectedValue'),
      initialValue: selectedValue,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _blue),
        ),
      ),
      style: const TextStyle(color: _text, fontSize: 10),
      items: [
        DropdownMenuItem(value: _allFilter, child: Text(label)),
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (selected) => onChanged(
        selected == null || selected == _allFilter ? null : selected,
      ),
    );
  }

  Widget _dateFilterButton() {
    final enabled = (_reports?.isNotEmpty ?? false) && !_reportsLoading;
    final label = _dateRange == null
        ? 'All dates'
        : '${DateFormat('MMM d, yy').format(_dateRange!.start)} - '
              '${DateFormat('MMM d, yy').format(_dateRange!.end)}';
    return OutlinedButton.icon(
      onPressed: enabled ? _chooseDateRange : null,
      icon: const Icon(Icons.calendar_today_outlined, size: 15),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: _text,
        disabledForegroundColor: _muted,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(fontSize: 10),
      ),
    );
  }

  Widget _buildMapAndRecent({required bool desktop}) {
    if (_reportsLoading) {
      return _loadingPanel();
    }
    if (_reportsError != null || _reports == null) {
      return _messagePanel(
        _reportsError ?? 'Reports could not be loaded. Please try again.',
        icon: Icons.cloud_off_outlined,
        action: TextButton.icon(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      );
    }
    final filteredReports = _filteredReports;
    final mappedReports = _mappedFilteredReports;
    if (filteredReports.isEmpty) {
      return _messagePanel(
        'No reports available for the selected filters.',
        icon: Icons.filter_alt_off_outlined,
      );
    }
    if (mappedReports.isEmpty) {
      final hasAnyLocations = _validReports.isNotEmpty;
      return _messagePanel(
        hasAnyLocations
            ? 'No mapped reports available for the selected filters.'
            : 'No report locations are available for mapping.',
        icon: Icons.location_off_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = desktop && constraints.maxWidth >= 1080;
        if (!sideBySide) {
          return Column(
            children: [
              _mapCard(mappedReports),
              const SizedBox(height: 14),
              _recentReportsCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _mapCard(mappedReports)),
            const SizedBox(width: 14),
            Expanded(flex: 3, child: _recentReportsCard()),
          ],
        );
      },
    );
  }

  Widget _mapCard(List<Report> reports) {
    final selectedReport = reports.where((report) {
      return report.id == _selectedReportId;
    }).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, color: _blue, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Reported Issue Locations',
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Showing ${reports.length} of ${_reports?.length ?? 0} reports with valid locations',
                style: const TextStyle(color: _muted, fontSize: 9),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 510,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: reports.length == 1 ? 13 : 10,
                      onMapReady: () {
                        if (mounted) {
                          setState(() => _mapReady = true);
                          WidgetsBinding.instance.addPostFrameCallback((_) => _refitMap());
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.civisense.app',
                      ),
                      MarkerLayer(markers: reports.map(_reportMarker).toList()),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                  Positioned(top: 10, left: 10, child: _mapControls()),
                  if (selectedReport != null)
                    Positioned(
                      left: 12,
                      right: 62,
                      bottom: 12,
                      child: _selectedReportCard(selectedReport),
                    ),
                  Positioned(
                    left: 10,
                    bottom: selectedReport == null ? 10 : 100,
                    child: _priorityLegend(reports),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Tooltip(
                      message:
                          'Map markers show individual reports, not calculated hotspots.',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [_cardShadow],
                        ),
                        child: const Text(
                          'Individual report points',
                          style: TextStyle(
                            color: _text,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Markers represent individual reports. No hotspot clustering or heatmap is provided.',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Marker _reportMarker(Report report) {
    final color = _priorityColor(report);
    final selected = report.id == _selectedReportId;
    return Marker(
      point: LatLng(report.latitude, report.longitude),
      width: selected ? 42 : 32,
      height: selected ? 46 : 36,
      child: Tooltip(
        message:
            '${report.issueNumber} · ${_priority(report) ?? 'Priority unavailable'}',
        child: GestureDetector(
          onTap: () => _selectReport(report),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
              Icon(
                Icons.location_on_rounded,
                color: color,
                size: selected ? 31 : 27,
                shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapControls() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      elevation: 2,
      child: Column(
        children: [
          IconButton(
            tooltip: 'Zoom in',
            visualDensity: VisualDensity.compact,
            onPressed: _mapReady
                ? () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  )
                : null,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
          const Divider(height: 1, color: _border),
          IconButton(
            tooltip: 'Zoom out',
            visualDensity: VisualDensity.compact,
            onPressed: _mapReady
                ? () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  )
                : null,
            icon: const Icon(Icons.remove_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _priorityLegend(List<Report> reports) {
    final available = <String>{
      for (final report in reports)
        if (_priority(report) != null) _priority(report)!,
    };
    if (available.isEmpty) return const SizedBox.shrink();
    final labels = [
      if (available.contains('HIGH')) ('High Priority', _red),
      if (available.contains('MEDIUM')) ('Medium Priority', _amber),
      if (available.contains('LOW')) ('Low Priority', _green),
      if (available.any((value) => !{'HIGH', 'MEDIUM', 'LOW'}.contains(value)))
        ('Other priority', _neutral),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [_cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in labels)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$1,
                    style: const TextStyle(color: _text, fontSize: 9),
                  ),
                ],
              ),
            ),
          if (reports.any((report) => _priority(report) == null))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: _neutral, size: 8),
                  SizedBox(width: 6),
                  Text(
                    'Priority unavailable',
                    style: TextStyle(color: _text, fontSize: 9),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectedReportCard(Report report) {
    final location = [
      if (report.areaZone?.trim().isNotEmpty == true) report.areaZone!.trim(),
      if (report.jurisdiction?.trim().isNotEmpty == true)
        report.jurisdiction!.trim(),
    ].join(', ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 7, 10),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              color: _priorityColor(report),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.issueNumber,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      _category(report) ?? 'Category unavailable',
                      if (_priority(report) != null) _priority(report)!,
                      _formatLabel(report.status),
                      if (location.isNotEmpty) location,
                      DateFormat(
                        'MMM d, yyyy',
                      ).format(report.createdAt.toLocal()),
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openReport(report),
              child: const Text('View'),
            ),
            IconButton(
              tooltip: 'Close selected report',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _selectedReportId = null),
              icon: const Icon(Icons.close_rounded, size: 17),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentReportsCard() {
    final reports = _recentMappedReports;
    return Container(
      constraints: const BoxConstraints(minHeight: 440),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_list_rounded, color: _blue, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Recent Reports on Map',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _navigate('/admin/reports'),
                style: TextButton.styleFrom(
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  minimumSize: const Size(48, 30),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const Divider(color: _border, height: 18),
          if (reports.isEmpty)
            const SizedBox(
              height: 350,
              child: Center(
                child: Text(
                  'No reports available for the selected filters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            )
          else
            ...reports.map(_recentReportRow),
        ],
      ),
    );
  }

  Widget _recentReportRow(Report report) {
    final selected = report.id == _selectedReportId;
    final location = [
      if (report.areaZone?.trim().isNotEmpty == true) report.areaZone!.trim(),
      if (report.jurisdiction?.trim().isNotEmpty == true)
        report.jurisdiction!.trim(),
    ].join(', ');
    return InkWell(
      onTap: () => _selectReport(report),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2F7FF) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            _reportThumbnail(report),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _category(report) ?? report.issueNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _priorityChip(report),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      report.issueNumber,
                      if (location.isNotEmpty) location,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat(
                      'MMM d, yyyy · h:mm a',
                    ).format(report.createdAt.toLocal()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'View report',
              onPressed: () => _openReport(report),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: _muted,
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportThumbnail(Report report) {
    final imageUrl = report.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _thumbnailPlaceholder();
    }
    final token = context.read<AuthProvider>().apiService.token;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        imageUrl,
        width: 50,
        height: 48,
        fit: BoxFit.cover,
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
        errorBuilder: (context, error, stackTrace) => _thumbnailPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _thumbnailPlaceholder(
            child: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(color: _blue, strokeWidth: 1.5),
            ),
          );
        },
      ),
    );
  }

  Widget _thumbnailPlaceholder({Widget? child}) {
    return Container(
      width: 50,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child:
          child ??
          const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF98A2B3),
            size: 18,
          ),
    );
  }

  Widget _priorityChip(Report report) {
    final priority = _priority(report);
    final color = _priorityColor(report);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        priority == null ? 'Unknown' : _formatLabel(priority),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _loadingPanel() {
    return Container(
      height: 500,
      decoration: _cardDecoration(),
      child: const Center(
        child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
      ),
    );
  }

  Widget _messagePanel(
    String message, {
    required IconData icon,
    Widget? action,
  }) {
    return Container(
      height: 500,
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF98A2B3), size: 36),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              if (action != null) ...[const SizedBox(height: 8), action],
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

class _Kpi {
  const _Kpi({
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
