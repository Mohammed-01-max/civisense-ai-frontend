import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
import '../../services/admin_service.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _background = Color(0xFFF6F8FB);
  static const _surface = Colors.white;
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE7EBF1);
  static const _amber = Color(0xFFF79009);
  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFF04438);
  static const _purple = Color(0xFF7A5AF8);

  static const _departmentColors = [
    Color(0xFF12B76A),
    Color(0xFF1769E0),
    Color(0xFFF79009),
    Color(0xFFF04438),
    Color(0xFF7A5AF8),
    Color(0xFF00A6A6),
    Color(0xFFB54708),
    Color(0xFF6172F3),
  ];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _mapController = MapController();

  AnalyticsSummary? _analytics;
  List<Report>? _reports;
  int? _unreadCount;
  String? _analyticsError;
  String? _reportsError;
  bool _analyticsLoading = true;
  bool _reportsLoading = true;
  bool _notificationsLoading = true;
  int? _totalUsers;
  bool _totalUsersLoading = true;
  String? _totalUsersError;
  String _appliedSearch = '';
  String? _departmentFilter;
  String? _statusFilter;
  String? _priorityFilter;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    await Future.wait([
      _loadAnalytics(),
      _loadReports(),
      _loadUnreadCount(),
      _loadTotalUsers(),
    ]);
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
          _analyticsError = 'Dashboard analytics could not be loaded.';
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
      final reports = await ReportService(
        context.read<AuthProvider>().apiService,
      ).getAllReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _reportsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports = null;
          _reportsLoading = false;
          _reportsError = 'Recent reports could not be loaded.';
        });
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    if (mounted) setState(() => _notificationsLoading = true);
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

  Future<void> _loadTotalUsers() async {
    if (mounted) {
      setState(() {
        _totalUsersLoading = true;
        _totalUsersError = null;
      });
    }
    try {
      final total = await AdminService(
        context.read<AuthProvider>().apiService,
      ).getTotalUsersCount();
      if (mounted) {
        setState(() {
          _totalUsers = total;
          _totalUsersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _totalUsers = null;
          _totalUsersLoading = false;
          _totalUsersError = 'User count unavailable';
        });
      }
    }
  }

  String _formatLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _category(Report report) {
    if (report.detections.isNotEmpty) {
      return _formatLabel(report.detections.first.issueType);
    }
    final triageCategory = report.triageCategory?.trim();
    return triageCategory?.isNotEmpty == true
        ? _formatLabel(triageCategory!)
        : 'Category unavailable';
  }

  String _issueTitle(Report report) {
    final description = report.description?.trim() ?? '';
    if (description.isEmpty) return _category(report);
    return description.split(RegExp(r'(?<=[.!?])\s+')).first;
  }

  String _location(Report report) {
    final parts = [
      if (report.areaZone?.trim().isNotEmpty == true) report.areaZone!.trim(),
      if (report.jurisdiction?.trim().isNotEmpty == true)
        report.jurisdiction!.trim(),
    ];
    return parts.isEmpty ? 'Location unavailable' : parts.join(', ');
  }

  String? _department(Report report) {
    final department = report.serviceDepartment?.trim();
    return department == null || department.isEmpty ? null : department;
  }

  String? _priority(Report report) {
    final priority = report.priorityAdvisory?.level.trim();
    return priority == null || priority.isEmpty ? null : priority.toUpperCase();
  }

  Color _priorityColor(String? priority) {
    switch (priority?.toUpperCase()) {
      case 'HIGH':
        return _red;
      case 'MEDIUM':
        return _amber;
      case 'LOW':
        return _green;
      default:
        return _muted;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return _green;
      case 'pending':
        return _amber;
      default:
        return _muted;
    }
  }

  List<String> get _departments {
    final values =
        (_reports ?? <Report>[])
            .map(_department)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _statuses {
    final values =
        (_reports ?? <Report>[]).map((report) => report.status).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _priorities {
    final values =
        (_reports ?? <Report>[])
            .map(_priority)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<Report> get _filteredReports {
    final reports = List<Report>.of(_reports ?? <Report>[]);
    final query = _appliedSearch.trim().toLowerCase();
    final filtered = reports.where((report) {
      final matchesQuery =
          query.isEmpty ||
          report.issueNumber.toLowerCase().contains(query) ||
          (report.description ?? '').toLowerCase().contains(query) ||
          _location(report).toLowerCase().contains(query) ||
          (_department(report) ?? '').toLowerCase().contains(query) ||
          (report.assignedOfficer?.name ?? '').toLowerCase().contains(query);
      final matchesDepartment =
          _departmentFilter == null || _department(report) == _departmentFilter;
      final matchesStatus =
          _statusFilter == null || report.status == _statusFilter;
      final matchesPriority =
          _priorityFilter == null || _priority(report) == _priorityFilter;
      return matchesQuery &&
          matchesDepartment &&
          matchesStatus &&
          matchesPriority;
    }).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  List<Report> get _recentReports => _filteredReports.take(8).toList();

  Map<String, int> get _departmentCounts {
    final counts = <String, int>{};
    for (final report in _reports ?? <Report>[]) {
      final department = _department(report);
      if (department != null) {
        counts.update(department, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Map<DateTime, int> get _recentDailyCounts {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 29));
    final counts = <DateTime, int>{};
    for (var day = 0; day < 30; day++) {
      counts[start.add(Duration(days: day))] = 0;
    }
    for (final report in _reports ?? <Report>[]) {
      final created = report.createdAt.toLocal();
      final day = DateTime(created.year, created.month, created.day);
      if (!day.isBefore(start) && !day.isAfter(today)) {
        counts.update(day, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  List<Report> get _mapReports => (_reports ?? <Report>[]).where((report) {
    return report.latitude.isFinite &&
        report.longitude.isFinite &&
        report.latitude >= -90 &&
        report.latitude <= 90 &&
        report.longitude >= -180 &&
        report.longitude <= 180 &&
        (report.latitude != 0 || report.longitude != 0);
  }).toList();

  LatLng get _mapCenter {
    final points = _mapReports;
    if (points.isEmpty) return const LatLng(0, 0);
    final lats = points.map((report) => report.latitude).toList()..sort();
    final lons = points.map((report) => report.longitude).toList()..sort();
    final latitude = lats[lats.length ~/ 2];
    final longitude = lons[lons.length ~/ 2];
    return LatLng(latitude, longitude);
  }

  Future<void> _navigate(String route) async {
    _closeDrawer();
    await Navigator.pushNamed(context, route);
    if (route == '/notifications') _loadUnreadCount();
  }

  void _closeDrawer() {
    if (MediaQuery.sizeOf(context).width < 1000) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _showProfile(String name) {
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
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
                name,
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
              if (user?.jurisdiction?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  user!.jurisdiction!.trim(),
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
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
      drawer: desktop ? null : Drawer(child: _buildSidebar(adminName)),
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  SizedBox(width: 228, child: _buildSidebar(adminName)),
                  Expanded(child: _buildMainArea(adminName, desktop: true)),
                ],
              )
            : _buildMainArea(adminName, desktop: false),
      ),
    );
  }

  Widget _buildSidebar(String adminName) {
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
            selected: true,
            onTap: _closeDrawer,
          ),
          _sidebarItem(
            Icons.assignment_outlined,
            'Reports Management',
            onTap: () => _navigate('/admin/reports'),
          ),
          _sidebarItem(
            Icons.analytics_outlined,
            'GIS & Analytics',
            onTap: () => _navigate('/admin/gis'),
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
            child: Row(
              children: [
                const SizedBox(width: 13),
                Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : const Color(0xFFB6C1D0),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFB6C1D0),
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null && badge > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _badge(badge),
                  ),
              ],
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
            onRefresh: _loadDashboard,
            color: _blue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                desktop ? 22 : 12,
                desktop ? 20 : 14,
                desktop ? 22 : 12,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1700),
                  child: _buildDashboard(desktop: desktop),
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
      padding: EdgeInsets.symmetric(horizontal: desktop ? 22 : 8),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (!desktop)
            IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: _text, size: 20),
            )
          else
            const Icon(Icons.menu_rounded, color: _text, size: 20),
          const SizedBox(width: 18),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 570),
                child: _searchField(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _notificationBell(),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: _blue,
            child: Text(
              adminName.isEmpty ? 'A' : adminName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (desktop) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 175),
              child: Column(
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
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Profile options',
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF536176),
                size: 19,
              ),
              onSelected: (value) {
                if (value == 'profile') _showProfile(adminName);
                if (value == 'logout') _logout();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'profile', child: Text('Profile')),
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) => setState(() => _appliedSearch = value),
        style: const TextStyle(color: _text, fontSize: 11),
        decoration: InputDecoration(
          hintText: 'Search reports, officers, departments, or locations...',
          hintStyle: const TextStyle(color: _muted, fontSize: 10),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF8190A4),
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          filled: true,
          fillColor: const Color(0xFFF4F6F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _blue),
          ),
        ),
      ),
    );
  }

  Widget _notificationBell() {
    return InkWell(
      onTap: () => _navigate('/notifications'),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF536176),
              size: 22,
            ),
            if ((_unreadCount ?? 0) > 0)
              Positioned(right: -7, top: -7, child: _badge(_unreadCount!))
            else if (_unreadCount == null && !_notificationsLoading)
              const Positioned(
                right: -4,
                top: -3,
                child: Icon(Icons.error_outline, color: _amber, size: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
      alignment: Alignment.center,
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

  Widget _buildDashboard({required bool desktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: _text,
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Complete overview of civic issue management, system usage and municipal operations.',
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
            if (desktop) ...[
              const SizedBox(width: 12),
              _buildDateRangeWidget(),
            ],
          ],
        ),
        if (!desktop) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildDateRangeWidget(),
          ),
        ],
        const SizedBox(height: 18),
        _buildKpis(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1200) {
              return Column(
                children: [
                  _buildTrendCard(),
                  const SizedBox(height: 14),
                  _buildDepartmentCard(),
                  const SizedBox(height: 14),
                  _buildHotspotsCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 42, child: _buildTrendCard()),
                const SizedBox(width: 14),
                Expanded(flex: 35, child: _buildDepartmentCard()),
                const SizedBox(width: 14),
                Expanded(flex: 33, child: _buildHotspotsCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _buildRecentReports(),
      ],
    );
  }

  Widget _buildDateRangeWidget() {
    final reports = _reports;
    String label;
    String tooltipMessage;

    if (_reportsLoading) {
      label = 'Loading dates...';
      tooltipMessage = 'Loading report date range';
    } else if (_reportsError != null || reports == null) {
      label = 'Date range unavailable';
      tooltipMessage = _reportsError ?? 'Could not load report dates';
    } else if (reports.isEmpty) {
      label = 'No reports yet';
      tooltipMessage = 'No reports have been submitted yet';
    } else {
      final dates = reports.map((r) => r.createdAt).toList()..sort();
      final earliest = dates.first;
      final latest = dates.last;
      final sameYear = earliest.year == latest.year;
      final sameDay =
          earliest.year == latest.year &&
          earliest.month == latest.month &&
          earliest.day == latest.day;

      if (sameDay) {
        label = DateFormat('MMM d, yyyy').format(earliest);
      } else if (sameYear) {
        label =
            '${DateFormat('MMM d').format(earliest)} – ${DateFormat('MMM d').format(latest)}';
      } else {
        label =
            '${DateFormat('MMM d, yyyy').format(earliest)} – ${DateFormat('MMM d, yyyy').format(latest)}';
      }
      tooltipMessage =
          'Report dates: ${DateFormat('yyyy-MM-dd').format(earliest)} to ${DateFormat('yyyy-MM-dd').format(latest)}';
    }

    return Tooltip(
      message: tooltipMessage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, color: _muted, size: 15),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: _text,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpis() {
    final reports = _reports ?? <Report>[];
    final highPriorityCount = reports
        .where((report) => _priority(report)?.toUpperCase() == 'HIGH')
        .length;
    final cards = [
      _KpiData(
        label: 'Total Reports',
        value: _analyticsLoading
            ? 'Loading'
            : _analytics?.totalReports.toString() ?? 'Unavailable',
        helper: _analyticsError,
        icon: Icons.description_rounded,
        color: _blue,
      ),
      _KpiData(
        label: 'Pending Reports',
        value: _analyticsLoading
            ? 'Loading'
            : _analytics?.pendingCount.toString() ?? 'Unavailable',
        helper: _analyticsError,
        icon: Icons.schedule_rounded,
        color: _amber,
      ),
      _KpiData(
        label: 'High Priority',
        value: _reportsLoading
            ? 'Loading'
            : _reportsError != null
            ? 'Unavailable'
            : '$highPriorityCount',
        helper: _reportsError ?? 'Reports with a high priority advisory',
        icon: Icons.priority_high_rounded,
        color: _red,
      ),
      _KpiData(
        label: 'Resolved Reports',
        value: _analyticsLoading
            ? 'Loading'
            : _analytics?.resolvedCount.toString() ?? 'Unavailable',
        helper: _analyticsError,
        icon: Icons.check_circle_rounded,
        color: _green,
      ),
      _KpiData(
        label: 'Registered Users',
        value: _totalUsersLoading
            ? 'Loading'
            : _totalUsers != null
            ? '$_totalUsers'
            : 'Unavailable',
        helper: _totalUsersError,
        icon: Icons.people_alt_rounded,
        color: _purple,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1320
            ? 5
            : constraints.maxWidth >= 850
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _kpiCard(card)),
          ],
        );
      },
    );
  }

  Widget _kpiCard(_KpiData item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 89),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
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
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.value == 'Unavailable' ? _muted : _text,
                    fontSize: item.value == 'Unavailable' ? 14 : 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.helper != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.helper!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    double? minHeight,
  }) {
    return Container(
      width: double.infinity,
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    return _dashboardCard(
      title: 'Reports Trend',
      icon: Icons.bar_chart_rounded,
      minHeight: 224,
      trailing: const _SmallDisabledControl(label: 'Date filter unavailable'),
      child: _reportsLoading
          ? const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
              ),
            )
          : _reportsError != null
          ? _chartUnavailable(_reportsError!)
          : _buildTrendChart(),
    );
  }

  Widget _buildTrendChart() {
    final counts = _recentDailyCounts;
    final hasReports = counts.values.any((count) => count > 0);
    if (!hasReports) {
      return _chartUnavailable(
        'No reports were submitted during the last 30 days.',
      );
    }
    final values = counts.values.toList();
    final maxValue = values.reduce(math.max).toDouble();
    final maxY = maxValue < 4 ? 4.0 : maxValue * 1.2;
    final spots = [
      for (var index = 0; index < values.length; index++)
        FlSpot(index.toDouble(), values[index].toDouble()),
    ];
    final dates = counts.keys.toList();
    return SizedBox(
      height: 154,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFE9EEF4),
              strokeWidth: 1,
              dashArray: [3, 4],
            ),
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
                reservedSize: 25,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) => Text(
                  value.round().toString(),
                  style: const TextStyle(color: _muted, fontSize: 8),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= dates.length) {
                    return const SizedBox.shrink();
                  }
                  if (index % 7 != 0 && index != dates.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('MMM d').format(dates[index]),
                      style: const TextStyle(color: _muted, fontSize: 8),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (items) => items.map((item) {
                final index = item.x.round();
                final date = dates[index];
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n${item.y.round()} reports',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: _blue,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) =>
                    spot.y > 0 && spot.x.round() % 5 == 0,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 2.5,
                      color: Colors.white,
                      strokeWidth: 1.5,
                      strokeColor: _blue,
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
    );
  }

  Widget _buildDepartmentCard() {
    return _dashboardCard(
      title: 'Reports by Department',
      icon: Icons.format_list_bulleted_rounded,
      minHeight: 224,
      child: _reportsLoading
          ? const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
              ),
            )
          : _reportsError != null
          ? _chartUnavailable(_reportsError!)
          : _buildDepartmentChart(),
    );
  }

  Widget _buildDepartmentChart() {
    final entries = _departmentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, item) => sum + item.value);
    if (entries.isEmpty || total == 0) {
      return _chartUnavailable(
        'Department values are not available on the loaded reports.',
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: Row(
            children: [
              Expanded(
                flex: 11,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 34,
                        sections: [
                          for (var index = 0; index < entries.length; index++)
                            PieChartSectionData(
                              value: entries[index].value.toDouble(),
                              color:
                                  _departmentColors[index %
                                      _departmentColors.length],
                              title: '',
                              radius: 23,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Known',
                          style: TextStyle(color: _muted, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 13,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final color =
                        _departmentColors[index % _departmentColors.length];
                    final percent = entry.value / total * 100;
                    return Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.value} (${percent.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Derived from actual reports with a department value.',
            style: TextStyle(color: _muted, fontSize: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildHotspotsCard() {
    final reports = _mapReports;
    return _dashboardCard(
      title: 'Issue Locations',
      icon: Icons.location_searching_rounded,
      minHeight: 224,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6F9),
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _reportsLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _blue,
                      strokeWidth: 2,
                    ),
                  )
                : reports.isEmpty
                ? _chartUnavailable(
                    _reportsError ?? 'No valid report coordinates available.',
                  )
                : FlutterMap(
                    key: ValueKey(
                      'admin_map_${reports.length}_${_mapCenter.latitude}_${_mapCenter.longitude}',
                    ),
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: reports.length == 1 ? 12 : 10,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.civisense.app',
                      ),
                      MarkerLayer(
                        markers: reports.map((report) {
                          return Marker(
                            point: LatLng(report.latitude, report.longitude),
                            width: 24,
                            height: 28,
                            child: Tooltip(
                              message: report.issueNumber,
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: _blue,
                                size: 25,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 7),
          Text(
            _reportsError != null
                ? 'Data unavailable'
                : '${reports.length} report locations shown from submitted reports',
            style: const TextStyle(color: _muted, fontSize: 8, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _chartUnavailable(String message) {
    return SizedBox(
      height: 142,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_chart_outlined_rounded,
                color: Color(0xFF98A2B3),
                size: 29,
              ),
              const SizedBox(height: 7),
              const Text(
                'Data unavailable',
                style: TextStyle(
                  color: _text,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 8, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentReports() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: _blue, size: 19),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Recent Reports',
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _navigate('/admin/reports'),
                style: TextButton.styleFrom(
                  foregroundColor: _blue,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _buildFilters(),
          const SizedBox(height: 10),
          if (_reportsLoading)
            const SizedBox(
              height: 190,
              child: Center(
                child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
              ),
            )
          else if (_reportsError != null)
            _reportsFailure()
          else if (_recentReports.isEmpty)
            _noReports()
          else
            _buildReportTable(_recentReports),
          if (!_reportsLoading &&
              _reportsError == null &&
              _filteredReports.isNotEmpty) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Showing ${_recentReports.length} of ${_filteredReports.length} matching reports',
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 750;
        final firstRow = narrow
            ? <Widget>[
                SizedBox(width: constraints.maxWidth, child: _searchInput()),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _filterDropdown(
                    label: 'All Departments',
                    value: _departmentFilter,
                    items: _departments,
                    onChanged: (value) =>
                        setState(() => _departmentFilter = value),
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _filterDropdown(
                    label: 'All Status',
                    value: _statusFilter,
                    items: _statuses,
                    itemLabel: _formatLabel,
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _filterDropdown(
                    label: 'All Priority',
                    value: _priorityFilter,
                    items: _priorities,
                    itemLabel: _formatLabel,
                    onChanged: (value) =>
                        setState(() => _priorityFilter = value),
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _searchButton(),
                ),
              ]
            : <Widget>[
                SizedBox(
                  width: constraints.maxWidth * 0.31,
                  child: _searchInput(),
                ),
                SizedBox(
                  width: constraints.maxWidth * 0.20,
                  child: _filterDropdown(
                    label: 'All Departments',
                    value: _departmentFilter,
                    items: _departments,
                    onChanged: (value) =>
                        setState(() => _departmentFilter = value),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth * 0.16,
                  child: _filterDropdown(
                    label: 'All Status',
                    value: _statusFilter,
                    items: _statuses,
                    itemLabel: _formatLabel,
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth * 0.16,
                  child: _filterDropdown(
                    label: 'All Priority',
                    value: _priorityFilter,
                    items: _priorities,
                    itemLabel: _formatLabel,
                    onChanged: (value) =>
                        setState(() => _priorityFilter = value),
                  ),
                ),
                SizedBox(
                  width: math
                      .max(90.0, constraints.maxWidth * 0.17 - 32)
                      .toDouble(),
                  child: _searchButton(),
                ),
              ];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: firstRow,
        );
      },
    );
  }

  Widget _searchInput() {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) => setState(() => _appliedSearch = value),
        style: const TextStyle(color: _text, fontSize: 9),
        decoration: InputDecoration(
          hintText: 'Search by ID, description, location...',
          hintStyle: const TextStyle(color: _muted, fontSize: 9),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 17),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: _blue),
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? itemLabel,
  }) {
    final selectedValue = items.contains(value) ? value : null;
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        initialValue: selectedValue,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _muted,
          size: 17,
        ),
        style: const TextStyle(color: _text, fontSize: 9),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: _blue),
          ),
        ),
        hint: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 9),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          for (final item in items)
            DropdownMenuItem<String>(
              value: item,
              child: Text(
                itemLabel?.call(item) ?? item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _searchButton() {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: () =>
            setState(() => _appliedSearch = _searchController.text.trim()),
        icon: const Icon(Icons.search_rounded, size: 15),
        label: const Text('Search'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    );
  }

  Widget _buildReportTable(List<Report> reports) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [for (final report in reports) _reportCard(report)],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(constraints.maxWidth, 1160),
            child: Column(
              children: [
                _tableHeader(),
                for (var index = 0; index < reports.length; index++)
                  _tableRow(reports[index], last: index == reports.length - 1),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 90, child: _ColumnHeading('#')),
          SizedBox(width: 68, child: _ColumnHeading('Image')),
          Expanded(flex: 17, child: _ColumnHeading('Issue Details')),
          Expanded(flex: 14, child: _ColumnHeading('Location')),
          Expanded(flex: 14, child: _ColumnHeading('Department')),
          Expanded(flex: 10, child: _ColumnHeading('Priority')),
          Expanded(flex: 10, child: _ColumnHeading('Status')),
          Expanded(flex: 12, child: _ColumnHeading('Assigned To')),
          Expanded(flex: 12, child: _ColumnHeading('Submitted On')),
          SizedBox(width: 74, child: _ColumnHeading('Actions')),
        ],
      ),
    );
  }

  Widget _tableRow(Report report, {required bool last}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 59),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEBEFF4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '#${report.issueNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 68, child: _reportThumbnail(report, 45, 40)),
          Expanded(
            flex: 17,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _issueTitle(report),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _smallTag(_category(report), _blue),
                ],
              ),
            ),
          ),
          Expanded(flex: 14, child: _cellText(_location(report))),
          Expanded(
            flex: 14,
            child: _cellText(_department(report) ?? 'Not available'),
          ),
          Expanded(
            flex: 10,
            child: _compactTag(
              _priority(report) == null
                  ? 'Not set'
                  : _formatLabel(_priority(report)!),
              _priorityColor(_priority(report)),
            ),
          ),
          Expanded(
            flex: 10,
            child: _compactTag(
              _formatLabel(report.status),
              _statusColor(report.status),
            ),
          ),
          Expanded(
            flex: 12,
            child: _cellText(
              report.assignedOfficer?.name?.trim().isNotEmpty == true
                  ? report.assignedOfficer!.name!.trim()
                  : 'Unassigned',
            ),
          ),
          Expanded(
            flex: 12,
            child: _cellText(
              DateFormat(
                'MMM d, yyyy\nh:mm a',
              ).format(report.createdAt.toLocal()),
            ),
          ),
          SizedBox(
            width: 74,
            child: TextButton(
              onPressed: () => _showReportDetails(report),
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: const Color(0xFFEEF4FF),
                textStyle: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(Report report) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reportThumbnail(report, 58, 54),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${report.issueNumber}',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _issueTitle(report),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _smallTag(_category(report), _blue),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showReportDetails(report),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _compactTag(
                _formatLabel(report.status),
                _statusColor(report.status),
              ),
              _compactTag(
                _priority(report) == null
                    ? 'Priority not set'
                    : _formatLabel(_priority(report)!),
                _priorityColor(_priority(report)),
              ),
              _compactTag(
                _department(report) ?? 'Department unavailable',
                _muted,
              ),
            ],
          ),
          const SizedBox(height: 7),
          _mobileCell(Icons.location_on_outlined, _location(report)),
          _mobileCell(
            Icons.person_outline_rounded,
            report.assignedOfficer?.name?.trim().isNotEmpty == true
                ? report.assignedOfficer!.name!.trim()
                : 'Unassigned',
          ),
          _mobileCell(
            Icons.calendar_today_outlined,
            DateFormat(
              'MMM d, yyyy · h:mm a',
            ).format(report.createdAt.toLocal()),
          ),
        ],
      ),
    );
  }

  Widget _reportThumbnail(Report report, double width, double height) {
    final imageUrl = report.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _thumbnailPlaceholder(width, height);
    }
    final token = context.read<AuthProvider>().apiService.token;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
        errorBuilder: (context, error, stackTrace) =>
            _thumbnailPlaceholder(width, height),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _thumbnailPlaceholder(
            width,
            height,
            child: const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(color: _blue, strokeWidth: 1.5),
            ),
          );
        },
      ),
    );
  }

  Widget _thumbnailPlaceholder(double width, double height, {Widget? child}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F7),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child:
            child ??
            const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF98A2B3),
              size: 17,
            ),
      ),
    );
  }

  Widget _cellText(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF475467),
          fontSize: 8,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _smallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _compactTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _mobileCell(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: _muted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportsFailure() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: _red, size: 30),
          const SizedBox(height: 8),
          Text(
            _reportsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _loadReports,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _noReports() {
    final hasFilters =
        _appliedSearch.isNotEmpty ||
        _departmentFilter != null ||
        _statusFilter != null ||
        _priorityFilter != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF98A2B3), size: 30),
          const SizedBox(height: 8),
          Text(
            hasFilters ? 'No matching reports' : 'No reports found',
            style: const TextStyle(
              color: _text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 7),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _appliedSearch = '';
                  _departmentFilter = null;
                  _statusFilter = null;
                  _priorityFilter = null;
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  void _showReportDetails(Report report) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: _surface,
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 14, 9, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Report Details',
                        style: TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (report.imageUrl?.trim().isNotEmpty == true) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _reportThumbnail(report, 500, 280),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        '#${report.issueNumber}',
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _issueTitle(report),
                        style: const TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _smallTag(_category(report), _blue),
                          _compactTag(
                            _formatLabel(report.status),
                            _statusColor(report.status),
                          ),
                          _compactTag(
                            _priority(report) == null
                                ? 'Priority not set'
                                : _formatLabel(_priority(report)!),
                            _priorityColor(_priority(report)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _detailInfo('Location', _location(report)),
                      _detailInfo(
                        'Coordinates',
                        '${report.latitude.toStringAsFixed(5)}, '
                            '${report.longitude.toStringAsFixed(5)}',
                      ),
                      _detailInfo(
                        'Department',
                        _department(report) ?? 'Not available',
                      ),
                      _detailInfo(
                        'Assigned To',
                        report.assignedOfficer?.name?.trim().isNotEmpty == true
                            ? report.assignedOfficer!.name!.trim()
                            : 'Unassigned',
                      ),
                      _detailInfo(
                        'Submitted',
                        DateFormat(
                          'MMM d, yyyy · h:mm a',
                        ).format(report.createdAt.toLocal()),
                      ),
                      _detailInfo(
                        'Description',
                        report.description?.trim().isNotEmpty == true
                            ? report.description!.trim()
                            : 'Not provided',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _text, fontSize: 10, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _navy.withValues(alpha: 0.025),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final String? helper;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });
}

class _SmallDisabledControl extends StatelessWidget {
  final String label;

  const _SmallDisabledControl({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: _AdminHomeState._border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(color: _AdminHomeState._muted, fontSize: 8),
      ),
    );
  }
}

class _ColumnHeading extends StatelessWidget {
  final String label;

  const _ColumnHeading(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _AdminHomeState._muted,
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
