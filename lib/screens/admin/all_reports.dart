import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';
import '../citizen/report_detail_screen.dart';

class AllReportsScreen extends StatefulWidget {
  const AllReportsScreen({super.key});

  @override
  State<AllReportsScreen> createState() => _AllReportsScreenState();
}

class _AllReportsScreenState extends State<AllReportsScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _background = Color(0xFFF6F8FB);
  static const _surface = Colors.white;
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE7EBF1);
  static const _green = Color(0xFF12B76A);
  static const _amber = Color(0xFFF79009);
  static const _red = Color(0xFFF04438);
  static const _pageSize = 7;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  List<Report>? _reports;
  String? _error;
  int? _unreadCount;
  bool _isLoading = true;
  bool _loadingNotifications = true;
  String _appliedSearch = '';
  String? _departmentFilter;
  String? _statusFilter;
  String? _categoryFilter;
  String? _priorityFilter;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final reports = await ReportService(
        context.read<AuthProvider>().apiService,
      ).getAllReports();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Reports could not be loaded. Please try again.';
          _isLoading = false;
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
          _loadingNotifications = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unreadCount = null;
          _loadingNotifications = false;
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
    final category = report.triageCategory?.trim();
    return category?.isNotEmpty == true
        ? _formatLabel(category!)
        : 'Category unavailable';
  }

  String _title(Report report) {
    final description = report.description?.trim() ?? '';
    return description.isEmpty
        ? _category(report)
        : description.split(RegExp(r'(?<=[.!?])\s+')).first;
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
    final value = report.serviceDepartment?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _priority(Report report) {
    final value = report.priorityAdvisory?.level.trim();
    return value == null || value.isEmpty ? null : value.toUpperCase();
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

  List<String> get _categories {
    final values =
        (_reports ?? <Report>[])
            .map(_category)
            .where((value) => value != 'Category unavailable')
            .toSet()
            .toList()
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
    final query = _appliedSearch.trim().toLowerCase();
    final reports = (_reports ?? <Report>[]).where((report) {
      final matchesSearch =
          query.isEmpty ||
          report.issueNumber.toLowerCase().contains(query) ||
          (report.description ?? '').toLowerCase().contains(query) ||
          _location(report).toLowerCase().contains(query);
      final matchesDepartment =
          _departmentFilter == null || _department(report) == _departmentFilter;
      final matchesStatus =
          _statusFilter == null || report.status == _statusFilter;
      final matchesCategory =
          _categoryFilter == null || _category(report) == _categoryFilter;
      final matchesPriority =
          _priorityFilter == null || _priority(report) == _priorityFilter;
      return matchesSearch &&
          matchesDepartment &&
          matchesStatus &&
          matchesCategory &&
          matchesPriority;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  List<Report> get _pageReports {
    final reports = _filteredReports;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= reports.length) return const [];
    return reports.skip(start).take(_pageSize).toList();
  }

  int get _pageCount =>
      math.max(1, (_filteredReports.length / _pageSize).ceil());

  int _countStatus(String status) => (_reports ?? <Report>[])
      .where((report) => report.status.toLowerCase() == status)
      .length;

  int get _highPriorityCount => (_reports ?? <Report>[])
      .where((report) => _priority(report) == 'HIGH')
      .length;

  void _applySearch() {
    setState(() {
      _appliedSearch = _searchController.text.trim();
      _currentPage = 1;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _appliedSearch = '';
      _departmentFilter = null;
      _statusFilter = null;
      _categoryFilter = null;
      _priorityFilter = null;
      _currentPage = 1;
    });
  }

  void _updateFilter(VoidCallback update) {
    setState(() {
      update();
      _currentPage = 1;
    });
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

  void _openReport(Report report) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
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
            onTap: () => _navigate('/admin'),
          ),
          _sidebarItem(
            Icons.assignment_outlined,
            'Reports Management',
            selected: true,
            onTap: _closeDrawer,
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
            onRefresh: _loadReports,
            color: _blue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                desktop ? 22 : 12,
                desktop ? 18 : 13,
                desktop ? 22 : 12,
                22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1650),
                  child: _buildPageContent(adminName, desktop: desktop),
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
                constraints: const BoxConstraints(maxWidth: 560),
                child: _headerSearchField(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _notificationBell(),
          const SizedBox(width: 15),
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
              constraints: const BoxConstraints(maxWidth: 150),
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
            const SizedBox(width: 5),
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

  Widget _headerSearchField() {
    return SizedBox(
      height: 37,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          setState(() {
            _appliedSearch = value.trim();
            _currentPage = 1;
          });
        },
        style: const TextStyle(color: _text, fontSize: 10),
        decoration: InputDecoration(
          hintText: 'Search reports by ID, description, or location...',
          hintStyle: const TextStyle(color: _muted, fontSize: 9),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF8190A4),
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          contentPadding: const EdgeInsets.symmetric(horizontal: 9),
          filled: true,
          fillColor: const Color(0xFFF4F6F9),
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
            else if (_unreadCount == null && !_loadingNotifications)
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

  Widget _buildPageContent(String adminName, {required bool desktop}) {
    if (_isLoading && _reports == null) {
      return const SizedBox(
        height: 420,
        child: Center(
          child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
        ),
      );
    }
    if (_error != null && _reports == null) {
      return _errorState();
    }
    final reports = _reports ?? <Report>[];
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
                    'Reports Management',
                    style: TextStyle(
                      color: _text,
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.35,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage and review all submitted civic reports.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            if (desktop)
              IconButton(
                tooltip: 'Refresh reports',
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh_rounded, color: _blue),
              ),
          ],
        ),
        if (!desktop) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Refresh reports',
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh_rounded, color: _blue),
            ),
          ),
        ],
        const SizedBox(height: 15),
        _buildSummaryCards(reports),
        const SizedBox(height: 14),
        _buildReportsPanel(),
      ],
    );
  }

  Widget _buildSummaryCards(List<Report> reports) {
    final cards = [
      _SummaryData(
        title: 'Total Reports',
        value: '${reports.length}',
        icon: Icons.description_outlined,
        color: _blue,
      ),
      _SummaryData(
        title: 'Pending',
        value: '${_countStatus('pending')}',
        icon: Icons.schedule_rounded,
        color: _amber,
      ),
      _SummaryData(
        title: 'Resolved',
        value: '${_countStatus('resolved')}',
        icon: Icons.check_circle_outline_rounded,
        color: _green,
      ),
      _SummaryData(
        title: 'High Priority',
        value: '$_highPriorityCount',
        icon: Icons.flag_outlined,
        color: _red,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        const gap = 11.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _summaryCard(card)),
          ],
        );
      },
    );
  }

  Widget _summaryCard(_SummaryData item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 20,
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

  Widget _buildReportsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilters(),
          const SizedBox(height: 11),
          if (_isLoading)
            const SizedBox(
              height: 210,
              child: Center(
                child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
              ),
            )
          else if (_error != null)
            _inlineError()
          else if (_filteredReports.isEmpty)
            _emptyState()
          else
            _buildReportList(_pageReports),
          if (!_isLoading && _error == null && _filteredReports.isNotEmpty)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        final widgets = narrow
            ? <Widget>[
                SizedBox(width: constraints.maxWidth, child: _searchInput()),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _dropdown(
                    label: 'All Departments',
                    value: _departmentFilter,
                    values: _departments,
                    onChanged: (value) =>
                        _updateFilter(() => _departmentFilter = value),
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _dropdown(
                    label: 'All Status',
                    value: _statusFilter,
                    values: _statuses,
                    display: _formatLabel,
                    onChanged: (value) =>
                        _updateFilter(() => _statusFilter = value),
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _dropdown(
                    label: 'All Categories',
                    value: _categoryFilter,
                    values: _categories,
                    onChanged: (value) =>
                        _updateFilter(() => _categoryFilter = value),
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _dropdown(
                    label: 'All Priority',
                    value: _priorityFilter,
                    values: _priorities,
                    display: _formatLabel,
                    onChanged: (value) =>
                        _updateFilter(() => _priorityFilter = value),
                  ),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _searchButton(),
                ),
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _resetButton(),
                ),
              ]
            : [
                SizedBox(
                  width: constraints.maxWidth * 0.22,
                  child: _searchInput(),
                ),
                SizedBox(
                  width: constraints.maxWidth * 0.14,
                  child: _dropdown(
                    label: 'All Departments',
                    value: _departmentFilter,
                    values: _departments,
                    onChanged: (value) =>
                        _updateFilter(() => _departmentFilter = value),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth * 0.13,
                  child: _dropdown(
                    label: 'All Status',
                    value: _statusFilter,
                    values: _statuses,
                    display: _formatLabel,
                    onChanged: (value) =>
                        _updateFilter(() => _statusFilter = value),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth * 0.14,
                  child: _dropdown(
                    label: 'All Categories',
                    value: _categoryFilter,
                    values: _categories,
                    onChanged: (value) =>
                        _updateFilter(() => _categoryFilter = value),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth * 0.13,
                  child: _dropdown(
                    label: 'All Priority',
                    value: _priorityFilter,
                    values: _priorities,
                    display: _formatLabel,
                    onChanged: (value) =>
                        _updateFilter(() => _priorityFilter = value),
                  ),
                ),
                SizedBox(
                  width: math
                      .max(76.0, constraints.maxWidth * 0.14 - 40)
                      .toDouble(),
                  child: _searchButton(),
                ),
                _resetButton(),
              ];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: widgets,
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
        onSubmitted: (value) {
          setState(() {
            _appliedSearch = value.trim();
            _currentPage = 1;
          });
        },
        style: const TextStyle(color: _text, fontSize: 9),
        decoration: InputDecoration(
          hintText: 'Search by ID, description, location...',
          hintStyle: const TextStyle(color: _muted, fontSize: 9),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 16),
          prefixIconConstraints: const BoxConstraints(minWidth: 33),
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

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    String Function(String)? display,
  }) {
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : null,
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
          for (final item in values)
            DropdownMenuItem<String>(
              value: item,
              child: Text(
                display?.call(item) ?? item,
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
        onPressed: _applySearch,
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

  Widget _resetButton() {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: _clearFilters,
        style: OutlinedButton.styleFrom(
          foregroundColor: _muted,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: const Text('Reset'),
      ),
    );
  }

  Widget _buildReportList(List<Report> reports) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [for (final report in reports) _reportCard(report)],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(1120, constraints.maxWidth),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 92, child: _TableHeading('Report ID')),
          SizedBox(width: 68, child: _TableHeading('Image')),
          Expanded(flex: 18, child: _TableHeading('Issue Details')),
          Expanded(flex: 14, child: _TableHeading('Location')),
          Expanded(flex: 14, child: _TableHeading('Department')),
          Expanded(flex: 10, child: _TableHeading('Priority')),
          Expanded(flex: 10, child: _TableHeading('Status')),
          Expanded(flex: 13, child: _TableHeading('Assigned Officer')),
          Expanded(flex: 13, child: _TableHeading('Submitted On')),
          SizedBox(width: 74, child: _TableHeading('Actions')),
        ],
      ),
    );
  }

  Widget _tableRow(Report report, {required bool last}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 57),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEBEFF4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
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
          SizedBox(width: 68, child: _image(report, 46, 39)),
          Expanded(
            flex: 18,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(report),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (_category(report) != 'Category unavailable')
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
            child: _statusPriorityTag(
              _priority(report) == null
                  ? 'Not set'
                  : _formatLabel(_priority(report)!),
              _priorityColor(_priority(report)),
              Icons.flag_outlined,
            ),
          ),
          Expanded(
            flex: 10,
            child: _statusPriorityTag(
              _formatLabel(report.status),
              _statusColor(report.status),
              report.isResolved
                  ? Icons.check_circle_outline_rounded
                  : Icons.schedule_rounded,
            ),
          ),
          Expanded(
            flex: 13,
            child: _cellText(
              report.assignedOfficer?.name?.trim().isNotEmpty == true
                  ? report.assignedOfficer!.name!.trim()
                  : 'Unassigned',
            ),
          ),
          Expanded(
            flex: 13,
            child: _cellText(
              DateFormat(
                'MMM d, yyyy\nh:mm a',
              ).format(report.createdAt.toLocal()),
            ),
          ),
          SizedBox(
            width: 74,
            child: TextButton(
              onPressed: () => _openReport(report),
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                backgroundColor: const Color(0xFFEEF4FF),
                padding: const EdgeInsets.symmetric(horizontal: 6),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _image(report, 58, 54),
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
                      _title(report),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (_category(report) != 'Category unavailable')
                      _smallTag(_category(report), _blue),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openReport(report),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _statusPriorityTag(
                _formatLabel(report.status),
                _statusColor(report.status),
                report.isResolved
                    ? Icons.check_circle_outline_rounded
                    : Icons.schedule_rounded,
              ),
              _statusPriorityTag(
                _priority(report) == null
                    ? 'Priority not set'
                    : _formatLabel(_priority(report)!),
                _priorityColor(_priority(report)),
                Icons.flag_outlined,
              ),
              _smallTag(
                _department(report) ?? 'Department unavailable',
                _muted,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _mobileInfo(Icons.location_on_outlined, _location(report)),
          _mobileInfo(
            Icons.person_outline_rounded,
            report.assignedOfficer?.name?.trim().isNotEmpty == true
                ? report.assignedOfficer!.name!.trim()
                : 'Unassigned',
          ),
          _mobileInfo(
            Icons.calendar_today_outlined,
            DateFormat(
              'MMM d, yyyy · h:mm a',
            ).format(report.createdAt.toLocal()),
          ),
        ],
      ),
    );
  }

  Widget _image(Report report, double width, double height) {
    final imageUrl = report.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _imagePlaceholder(width, height);
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
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _imagePlaceholder(
            width,
            height,
            child: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(color: _blue, strokeWidth: 1.5),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _imagePlaceholder(width, height),
      ),
    );
  }

  Widget _imagePlaceholder(double width, double height, {Widget? child}) {
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
          height: 1.35,
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

  Widget _statusPriorityTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final total = _filteredReports.length;
    final start = (_currentPage - 1) * _pageSize + 1;
    final end = math.min(_currentPage * _pageSize, total);
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                'Showing $start to $end of $total reports',
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pageButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: _currentPage > 1,
                    onPressed: () => setState(() => _currentPage--),
                  ),
                  const SizedBox(width: 4),
                  if (compact)
                    Container(
                      width: 29,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$_currentPage',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    for (final page in _visiblePageNumbers())
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _numberButton(page),
                      ),
                  const SizedBox(width: 4),
                  _pageButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: _currentPage < _pageCount,
                    onPressed: () => setState(() => _currentPage++),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<int> _visiblePageNumbers() {
    if (_pageCount <= 5) {
      return List<int>.generate(_pageCount, (index) => index + 1);
    }
    final start = (_currentPage - 2).clamp(1, _pageCount - 4);
    return List<int>.generate(5, (index) => start + index);
  }

  Widget _numberButton(int page) {
    final active = page == _currentPage;
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 29,
        height: 29,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _blue : _surface,
          border: Border.all(color: active ? _blue : _border),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            color: active ? Colors.white : _muted,
            fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _pageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 29, height: 29),
      padding: EdgeInsets.zero,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18),
      color: _muted,
      disabledColor: const Color(0xFFC8D0DA),
      style: IconButton.styleFrom(
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }

  Widget _inlineError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: _red, size: 30),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Reports could not be loaded.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
          const SizedBox(height: 9),
          OutlinedButton(
            onPressed: _loadReports,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 420),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: _red, size: 42),
          const SizedBox(height: 11),
          Text(
            _error ?? 'Reports could not be loaded. Please try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadReports,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final filtered =
        _appliedSearch.isNotEmpty ||
        _departmentFilter != null ||
        _statusFilter != null ||
        _categoryFilter != null ||
        _priorityFilter != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 27, horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF98A2B3), size: 34),
          const SizedBox(height: 8),
          Text(
            filtered ? 'No matching reports' : 'No reports found',
            style: const TextStyle(
              color: _text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (filtered) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Reset filters'),
            ),
          ],
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

class _SummaryData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _TableHeading extends StatelessWidget {
  final String label;

  const _TableHeading(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _AllReportsScreenState._muted,
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
