import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import 'officer_report_detail_screen.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';

class OfficerHome extends StatefulWidget {
  const OfficerHome({super.key});

  @override
  State<OfficerHome> createState() => _OfficerHomeState();
}

class _OfficerHomeState extends State<OfficerHome> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1769E0);
  static const _background = Color(0xFFF6F8FB);
  static const _surface = Colors.white;
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE7EBF1);
  static const _success = Color(0xFF12B76A);
  static const _warning = Color(0xFFF79009);
  static const _errorColor = Color(0xFFF04438);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _queueKey = GlobalKey();
  final _searchController = TextEditingController();

  List<Report>? _reports;
  String? _error;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadReports(), _loadUnreadCount()]);
  }

  Future<void> _loadReports() async {
    try {
      final reports = await ReportService(
        context.read<AuthProvider>().apiService,
      ).getAssignedOfficerReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'We couldn’t load your assigned reports. Please try again.';
        });
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final apiService = context.read<AuthProvider>().apiService;
      final notifications = await NotificationService(
        apiService,
      ).getMyNotifications();
      if (mounted) {
        setState(() {
          _unreadCount = notifications.where((item) => !item.isRead).length;
        });
      }
    } catch (_) {
      // Notification availability does not block the assigned-report dashboard.
    }
  }

  String _formatLabel(String value) {
    return value
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
    if (report.triageCategory?.trim().isNotEmpty == true) {
      return _formatLabel(report.triageCategory!);
    }
    return 'Civic issue';
  }

  String _title(Report report) {
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

  String? _priorityLevel(Report report) {
    final advisory = report.priorityAdvisory?.level.trim();
    if (advisory != null && advisory.isNotEmpty) {
      return advisory.toUpperCase();
    }
    final severity = report.severity?.trim();
    if (severity != null && severity.isNotEmpty) return severity.toUpperCase();
    return null;
  }

  Color _priorityColor(String? level) {
    switch (level?.toUpperCase()) {
      case 'HIGH':
        return _errorColor;
      case 'MEDIUM':
        return _warning;
      case 'LOW':
        return _success;
      default:
        return _muted;
    }
  }

  List<Report> get _visibleReports {
    final query = _searchController.text.trim().toLowerCase();
    final reports = List<Report>.of(_reports ?? <Report>[]);
    reports.sort((a, b) {
      final priorityOrder = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2};
      final aPriority = priorityOrder[_priorityLevel(a)] ?? 3;
      final bPriority = priorityOrder[_priorityLevel(b)] ?? 3;
      final byPriority = aPriority.compareTo(bPriority);
      if (byPriority != 0) return byPriority;
      return b.createdAt.compareTo(a.createdAt);
    });
    if (query.isEmpty) return reports;
    return reports.where((report) {
      return report.issueNumber.toLowerCase().contains(query) ||
          _title(report).toLowerCase().contains(query) ||
          _category(report).toLowerCase().contains(query) ||
          _location(report).toLowerCase().contains(query);
    }).toList();
  }

  int get _highPriorityCount => (_reports ?? <Report>[]).where((report) {
    return report.priorityAdvisory?.level.toUpperCase() == 'HIGH';
  }).length;

  int get _pendingCount => (_reports ?? <Report>[])
      .where((report) => report.status.toLowerCase() == 'pending')
      .length;

  int get _resolvedTodayCount {
    final now = DateTime.now();
    return (_reports ?? <Report>[]).where((report) {
      final resolvedAt = report.resolvedAt?.toLocal();
      return report.isResolved &&
          resolvedAt != null &&
          resolvedAt.year == now.year &&
          resolvedAt.month == now.month &&
          resolvedAt.day == now.day;
    }).length;
  }

  int _priorityCount(String level) => (_reports ?? <Report>[])
      .where((report) => _priorityLevel(report) == level)
      .length;

  Future<void> _openReport(Report report) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OfficerReportDetailScreen(report: report),
      ),
    );
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
                leading: const Icon(Icons.logout_rounded, color: _accent),
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

  Future<void> _scrollToQueue() async {
    final targetContext = _queueKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final user = context.watch<AuthProvider>().user;
    final officerName = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!.trim()
        : 'Officer';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: desktop ? null : Drawer(child: _buildSidebar(officerName)),
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  SizedBox(width: 227, child: _buildSidebar(officerName)),
                  Expanded(child: _buildMainArea(officerName, desktop: true)),
                ],
              )
            : _buildMainArea(officerName, desktop: false),
      ),
    );
  }

  Widget _buildSidebar(String officerName) {
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
                        const Icon(Icons.public_rounded, color: _accent),
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
                        'Officer Portal',
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
            Icons.dashboard_outlined,
            'Dashboard',
            selected: true,
            onTap: _closeDrawer,
          ),
          _sidebarItem(
            Icons.assignment_outlined,
            'Assigned Reports',
            onTap: _scrollToQueue,
          ),
          _sidebarItem(
            Icons.notifications_none_rounded,
            'Notifications',
            onTap: () => _navigate('/notifications'),
          ),
          _sidebarItem(
            Icons.person_outline_rounded,
            'Profile',
            onTap: () => _showProfile(officerName),
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Material(
        color: selected ? _accent : Colors.transparent,
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
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFB6C1D0),
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea(String officerName, {required bool desktop}) {
    return Column(
      children: [
        _buildHeader(officerName, desktop: desktop),
        Expanded(
          child: _reports == null && _error == null
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: _accent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 22 : 12,
                      desktop ? 20 : 14,
                      desktop ? 22 : 12,
                      22,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: _buildDashboard(desktop: desktop),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(String officerName, {required bool desktop}) {
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
                constraints: const BoxConstraints(maxWidth: 525),
                child: _searchField(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF536176),
                size: 22,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: _errorColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: _accent,
            child: Text(
              officerName.isEmpty ? 'O' : officerName[0].toUpperCase(),
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
              constraints: const BoxConstraints(maxWidth: 145),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    officerName,
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
                    'Officer',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF536176),
              size: 19,
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
        style: const TextStyle(color: _text, fontSize: 11),
        decoration: InputDecoration(
          hintText: 'Search reports, issues, or updates...',
          hintStyle: const TextStyle(color: _muted, fontSize: 11),
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
            borderSide: const BorderSide(color: _accent),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard({required bool desktop}) {
    final allReports = _reports ?? <Report>[];
    final visibleReports = _visibleReports;
    final pending = _pendingCount;
    final resolved = allReports
        .where((report) => report.status.toLowerCase() == 'resolved')
        .length;
    final resolvedToday = _resolvedTodayCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(
            color: _text,
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Overview of reports assigned to you and your current workload.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 18),
        _buildStatCards(
          assigned: allReports.length,
          highPriority: _highPriorityCount,
          pending: pending,
          resolvedToday: resolvedToday,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 950) {
              return Column(
                children: [
                  _buildQueueCard(visibleReports),
                  const SizedBox(height: 14),
                  _buildWorkloadCard(pending: pending, resolved: resolved),
                  const SizedBox(height: 14),
                  _buildRecentCard(allReports),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 62, child: _buildQueueCard(visibleReports)),
                const SizedBox(width: 14),
                Expanded(
                  flex: 38,
                  child: Column(
                    children: [
                      _buildWorkloadCard(pending: pending, resolved: resolved),
                      const SizedBox(height: 14),
                      _buildRecentCard(allReports),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCards({
    required int assigned,
    required int highPriority,
    required int pending,
    required int resolvedToday,
  }) {
    final stats = [
      _StatInfo(
        label: 'Assigned to Me',
        value: '$assigned',
        icon: Icons.assignment_outlined,
        color: _accent,
      ),
      _StatInfo(
        label: 'High Priority',
        value: '$highPriority',
        icon: Icons.priority_high_rounded,
        color: _errorColor,
      ),
      _StatInfo(
        label: 'Pending',
        value: '$pending',
        icon: Icons.schedule_rounded,
        color: _warning,
      ),
      _StatInfo(
        label: 'Resolved Today',
        value: '$resolvedToday',
        icon: Icons.check_circle_outline_rounded,
        color: _success,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final stat in stats)
              SizedBox(width: width, child: _statCard(stat)),
          ],
        );
      },
    );
  }

  Widget _statCard(_StatInfo stat) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stat.icon, color: stat.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.label,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.value,
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

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
    Key? key,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildQueueCard(List<Report> reports) {
    return _panel(
      key: _queueKey,
      title: "Today's Queue",
      subtitle: 'Reports requiring your attention',
      child: reports.isEmpty
          ? _emptyQueue()
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      for (final report in reports) _queueReportCard(report),
                    ],
                  );
                }
                return Column(
                  children: [
                    _queueHeader(),
                    for (var index = 0; index < reports.length; index++)
                      _queueRow(
                        reports[index],
                        last: index == reports.length - 1,
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _queueHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 32, child: _HeaderLabel('REPORT')),
          Expanded(flex: 20, child: _HeaderLabel('LOCATION')),
          Expanded(flex: 14, child: _HeaderLabel('PRIORITY')),
          Expanded(flex: 13, child: _HeaderLabel('STATUS')),
          Expanded(flex: 13, child: _HeaderLabel('SUBMITTED')),
          SizedBox(width: 82, child: _HeaderLabel('')),
        ],
      ),
    );
  }

  Widget _queueRow(Report report, {required bool last}) {
    final priority = _priorityLevel(report);
    return InkWell(
      onTap: () => _openReport(report),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFEBEFF4))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 32,
              child: Row(
                children: [
                  _priorityMarker(priority),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          report.issueNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _title(report),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF475467),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 20,
              child: Text(
                _location(report),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF475467), fontSize: 9),
              ),
            ),
            Expanded(flex: 14, child: _priorityPill(priority)),
            Expanded(flex: 13, child: _statusPill(report)),
            Expanded(
              flex: 13,
              child: Text(
                DateFormat('MMM d, yyyy').format(report.createdAt.toLocal()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ),
            SizedBox(
              width: 82,
              child: TextButton(
                onPressed: () => _openReport(report),
                style: TextButton.styleFrom(
                  foregroundColor: _accent,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  textStyle: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View'),
                    Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueReportCard(Report report) {
    final priority = _priorityLevel(report);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _priorityMarker(priority),
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
                    const SizedBox(height: 2),
                    Text(
                      _title(report),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _text, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'View report',
                onPressed: () => _openReport(report),
                icon: const Icon(Icons.chevron_right_rounded, color: _accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              _categoryPill(_category(report)),
              _priorityPill(priority),
              _statusPill(report),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: _muted, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _location(report),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(report.createdAt.toLocal()),
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openReport(report),
              child: const Text('View Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityMarker(String? priority) {
    final color = _priorityColor(priority);
    return Container(
      width: 5,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _priorityPill(String? priority) {
    if (priority == null) {
      return _pill('Not set', _muted, Icons.remove_rounded);
    }
    final color = _priorityColor(priority);
    return _pill(_formatLabel(priority), color, Icons.flag_outlined);
  }

  Widget _statusPill(Report report) {
    final resolved = report.isResolved;
    return _pill(
      _formatLabel(report.status),
      resolved ? _success : _warning,
      resolved ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
    );
  }

  Widget _categoryPill(String category) {
    return _pill(category, _accent, Icons.category_outlined);
  }

  Widget _pill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyQueue() {
    final hasReports = _reports?.isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: Color(0xFF98A2B3),
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            hasReports ? 'No matching reports' : 'No reports assigned',
            style: const TextStyle(
              color: _text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasReports
                ? 'Try another search term.'
                : 'You currently have no civic reports assigned to you.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadCard({required int pending, required int resolved}) {
    final total = (_reports?.length ?? 0);
    return _panel(
      title: 'Workload Overview',
      subtitle: 'Breakdown of reports assigned to you',
      child: Column(
        children: [
          _workloadRow(
            'Pending',
            pending,
            total,
            _warning,
            Icons.schedule_rounded,
          ),
          const SizedBox(height: 14),
          _workloadRow(
            'Resolved',
            resolved,
            total,
            _success,
            Icons.check_circle_outline_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: _border),
          ),
          Row(
            children: [
              Expanded(child: _prioritySummary('High', 'HIGH', _errorColor)),
              Expanded(child: _prioritySummary('Medium', 'MEDIUM', _warning)),
              Expanded(child: _prioritySummary('Low', 'LOW', _success)),
            ],
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Priority uses the report advisory when available, then severity.',
              style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workloadRow(
    String label,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: _text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFFEEF1F4),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _prioritySummary(String label, String level, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
        const SizedBox(height: 4),
        Text(
          '${_priorityCount(level)}',
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCard(List<Report> reports) {
    final recent = List<Report>.of(reports)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final items = recent.take(5).toList();
    return _panel(
      title: 'Recent Assignments',
      subtitle: 'Sorted by report submission date',
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No reports assigned',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _recentRow(items[index], last: index == items.length - 1),
              ],
            ),
    );
  }

  Widget _recentRow(Report report, {required bool last}) {
    final priority = _priorityLevel(report);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEBEFF4))),
      ),
      child: Row(
        children: [
          _priorityMarker(priority),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.issueNumber,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_category(report)} · '
                  '${DateFormat('MMM d, yyyy').format(report.createdAt.toLocal())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [_priorityPill(priority), _statusPill(report)],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View report',
            onPressed: () => _openReport(report),
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: _accent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _errorColor, size: 42),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadAll, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _StatInfo {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatInfo({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _HeaderLabel extends StatelessWidget {
  final String label;

  const _HeaderLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _OfficerHomeState._muted,
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      ),
    );
  }
}
