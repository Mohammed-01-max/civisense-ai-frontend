import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/notification.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';
import 'report_detail_screen.dart';

class CitizenHome extends StatefulWidget {
  const CitizenHome({super.key});

  @override
  State<CitizenHome> createState() => _CitizenHomeState();
}

class _CitizenHomeState extends State<CitizenHome> {
  static const Color _blue = Color(0xFF1769E0);
  static const Color _navy = Color(0xFF0D1B2A);
  static const Color _ink = Color(0xFF1A2940);
  static const Color _muted = Color(0xFF758196);
  static const Color _canvas = Color(0xFFF6F8FB);
  static const Color _line = Color(0xFFE7EBF1);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  List<Report>? _reports;
  List<AppNotification>? _notifications;
  bool _reportsLoading = true;
  bool _notificationsLoading = true;
  String? _reportsError;
  String? _notificationsError;
  String _searchQuery = '';
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  Future<void> _loadDashboard() async {
    await Future.wait([_loadReports(), _loadNotifications()]);
  }

  Future<void> _loadReports() async {
    setState(() {
      _reportsLoading = true;
      _reportsError = null;
    });
    try {
      final api = context.read<AuthProvider>().apiService;
      final reports = await ReportService(api).getMyReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _reportsLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _reportsError = error.toString().replaceFirst('Exception: ', '');
          _reportsLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _notificationsLoading = true;
      _notificationsError = null;
    });
    try {
      final api = context.read<AuthProvider>().apiService;
      final notifications = await NotificationService(api).getMyNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _notificationsLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _notificationsError = error.toString().replaceFirst(
            'Exception: ',
            '',
          );
          _notificationsLoading = false;
        });
      }
    }
  }

  Future<void> _navigate(String route) async {
    if (MediaQuery.sizeOf(context).width < 1100) {
      _scaffoldKey.currentState?.closeDrawer();
    }
    await Navigator.pushNamed(context, route);
    if (mounted) _loadDashboard();
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _showProfile() {
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _UserAvatar(name: user?.fullName ?? user?.email ?? 'Citizen'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Citizen',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1100;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!.trim()
        : 'Citizen';

    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(userName)),
      backgroundColor: _canvas,
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _sidebarCollapsed ? 84 : 227,
                    child: _buildSidebar(
                      userName,
                      collapsed: _sidebarCollapsed,
                    ),
                  ),
                  Expanded(child: _buildMainArea(userName, isDesktop: true)),
                ],
              )
            : _buildMainArea(userName, isDesktop: false),
      ),
    );
  }

  Widget _buildSidebar(String userName, {bool collapsed = false}) {
    return Container(
      color: _navy,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 14 : 16,
              collapsed ? 25 : 14,
              collapsed ? 14 : 12,
              collapsed ? 30 : 20,
            ),
            child: collapsed
                ? Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset('assets/images/civisense_logo.svg'),
                  )
                : Row(
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
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CiviSense AI',
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Citizen Portal',
                              style: TextStyle(
                                color: Color(0xFFAAB7C9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14),
              children: [
                _SidebarItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Dashboard',
                  selected: true,
                  collapsed: collapsed,
                  onTap: () {
                    if (MediaQuery.sizeOf(context).width < 1100) {
                      _scaffoldKey.currentState?.closeDrawer();
                    }
                  },
                ),
                const SizedBox(height: 6),
                _SidebarItem(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Report an Issue',
                  collapsed: collapsed,
                  onTap: () => _navigate('/citizen/submit'),
                ),
                _SidebarItem(
                  icon: Icons.description_outlined,
                  label: 'My Reports',
                  collapsed: collapsed,
                  onTap: () => _navigate('/citizen/reports'),
                ),
                _SidebarItem(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  collapsed: collapsed,
                  badge: _unreadCount,
                  onTap: () => _navigate('/notifications'),
                ),
                _SidebarItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  collapsed: collapsed,
                  onTap: _showProfile,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 12 : 14,
              12,
              collapsed ? 12 : 14,
              18,
            ),
            child: _SidebarItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              collapsed: collapsed,
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  int get _unreadCount =>
      _notifications?.where((notification) => !notification.isRead).length ?? 0;

  Widget _buildMainArea(String userName, {required bool isDesktop}) {
    return Column(
      children: [
        _buildTopBar(userName, isDesktop: isDesktop),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDashboard,
            color: _blue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 34 : 18,
                isDesktop ? 28 : 22,
                isDesktop ? 34 : 18,
                34,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcome(userName, isDesktop: isDesktop),
                  const SizedBox(height: 25),
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 1000) {
                        return Column(
                          children: [
                            _buildRecentReports(),
                            const SizedBox(height: 20),
                            _buildNotificationsCard(),
                            const SizedBox(height: 20),
                            _buildQuickActions(),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildRecentReports()),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildNotificationsCard(),
                                const SizedBox(height: 20),
                                _buildQuickActions(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(String userName, {required bool isDesktop}) {
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 30 : 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Open navigation menu',
            onPressed: () {
              if (isDesktop) {
                setState(() => _sidebarCollapsed = !_sidebarCollapsed);
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
            icon: const Icon(Icons.menu_rounded, color: _ink, size: 23),
          ),
          const SizedBox(width: 14),
          if (width >= 700)
            SizedBox(
              width: width >= 1100 ? 310 : 230,
              height: 40,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: _ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search reports...',
                  hintStyle: const TextStyle(color: _muted, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _muted,
                    size: 19,
                  ),
                  filled: true,
                  fillColor: _canvas,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _navigate('/notifications'),
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              backgroundColor: const Color(0xFFE34F59),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _muted,
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _showProfile,
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                _UserAvatar(name: userName, size: 37),
                if (width >= 760) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Citizen',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _muted,
                    size: 19,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(String userName, {required bool isDesktop}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: TextStyle(
                  color: _ink,
                  fontSize: isDesktop ? 25 : 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.55,
                ),
                children: [
                  const TextSpan(text: 'Welcome Back, '),
                  TextSpan(
                    text: '$userName!',
                    style: const TextStyle(color: _blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Help make your city better by reporting civic issues. Together for a cleaner, safer and smarter city.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
          ],
        );
        final button = FilledButton.icon(
          onPressed: () => _navigate('/citizen/submit'),
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Report an Issue'),
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            elevation: 0,
          ),
        );

        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 17), button],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            button,
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards() {
    final reports = _reports ?? const <Report>[];
    final total = reports.length;
    final resolved = reports
        .where((report) => report.status.toLowerCase() == 'resolved')
        .length;
    final pending = reports
        .where((report) => report.status.toLowerCase() == 'pending')
        .length;

    final metrics = [
      _MetricData(
        label: 'Total Reports',
        value: _reportsLoading && _reports == null ? '—' : '$total',
        icon: Icons.description_outlined,
        color: _blue,
        tint: const Color(0xFFEBF3FF),
      ),
      _MetricData(
        label: 'Resolved',
        value: _reportsLoading && _reports == null ? '—' : '$resolved',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF1CA777),
        tint: const Color(0xFFEAF8F2),
      ),
      _MetricData(
        label: 'Pending',
        value: _reportsLoading && _reports == null ? '—' : '$pending',
        icon: Icons.schedule_rounded,
        color: const Color(0xFFE05B61),
        tint: const Color(0xFFFFEFF0),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                child: _MetricCard(
                  data: metric,
                  onTap: () => _navigate('/citizen/reports'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRecentReports() {
    final reports = _filteredReports;
    return _DashboardCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 19, 16, 15),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Reports',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigate('/citizen/reports'),
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          if (_reportsLoading && _reports == null)
            const _CardMessage(
              icon: null,
              message: 'Loading reports...',
              loading: true,
            )
          else if (_reportsError != null)
            _CardMessage(
              icon: Icons.error_outline_rounded,
              message: _reportsError!,
              actionLabel: 'Retry',
              onAction: _loadReports,
            )
          else if (reports.isEmpty)
            _CardMessage(
              icon: Icons.inbox_outlined,
              message: _searchQuery.isEmpty
                  ? 'No reports submitted yet.'
                  : 'No reports match your search.',
              actionLabel: _searchQuery.isEmpty
                  ? 'Report an Issue'
                  : 'Clear search',
              onAction: _searchQuery.isEmpty
                  ? () => _navigate('/citizen/submit')
                  : () => _searchController.clear(),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < reports.length && index < 5;
                        index++
                      )
                        _ReportListTile(
                          report: reports[index],
                          issueType: _issueType(reports[index]),
                          location: _location(reports[index]),
                          imageHeaders: _imageHeaders,
                          onView: () => _openReport(reports[index]),
                          onMore: () => _showReportActions(reports[index]),
                        ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 43,
                    dataRowMinHeight: 66,
                    dataRowMaxHeight: 70,
                    horizontalMargin: 18,
                    columnSpacing: 22,
                    headingTextStyle: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    dataTextStyle: const TextStyle(color: _ink, fontSize: 11),
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('ISSUE TYPE')),
                      DataColumn(label: Text('LOCATION')),
                      DataColumn(label: Text('STATUS')),
                      DataColumn(label: Text('SUBMITTED ON')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: [
                      for (
                        var index = 0;
                        index < reports.length && index < 5;
                        index++
                      )
                        _buildReportRow(reports[index]),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Report> get _filteredReports {
    final reports = [...?_reports];
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_searchQuery.isEmpty) return reports;
    return reports.where((report) {
      final searchable = [
        report.issueNumber,
        _issueType(report),
        _location(report),
        report.status,
      ].join(' ').toLowerCase();
      return searchable.contains(_searchQuery);
    }).toList();
  }

  DataRow _buildReportRow(Report report) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            report.issueNumber,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          SizedBox(
            width: 120,
            child: Row(
              children: [
                _ReportThumbnail(
                  imageUrl: report.imageUrl,
                  imageHeaders: _imageHeaders,
                  size: 33,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _issueType(report),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 110,
            child: Text(
              _location(report),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted),
            ),
          ),
        ),
        DataCell(_StatusPill(status: report.status)),
        DataCell(
          Text(
            DateFormat('MMM d, yyyy').format(report.createdAt.toLocal()),
            style: const TextStyle(color: _muted),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _openReport(report),
                style: TextButton.styleFrom(
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('View'),
              ),
              IconButton(
                tooltip: 'More actions',
                onPressed: () => _showReportActions(report),
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _issueType(Report report) {
    if (report.detections.isNotEmpty) return report.detections.first.issueType;
    if (report.triageCategory?.isNotEmpty == true) {
      return report.triageCategory!;
    }
    return 'Civic issue';
  }

  String _location(Report report) {
    final zone = report.areaZone?.trim();
    if (zone != null && zone.isNotEmpty) return zone;
    final jurisdiction = report.jurisdiction?.trim();
    if (jurisdiction != null && jurisdiction.isNotEmpty) return jurisdiction;
    return '${report.latitude.toStringAsFixed(3)}, ${report.longitude.toStringAsFixed(3)}';
  }

  Map<String, String>? _imageHeaders() {
    final token = context.read<AuthProvider>().apiService.token;
    return token == null ? null : {'Authorization': 'Bearer $token'};
  }

  void _openReport(Report report) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report),
      ),
    ).then((_) {
      if (mounted) _loadDashboard();
    });
  }

  Future<void> _showReportActions(Report report) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('View report'),
              subtitle: Text(report.issueNumber),
              onTap: () {
                Navigator.pop(sheetContext);
                _openReport(report);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_rounded),
              title: const Text('View all reports'),
              onTap: () {
                Navigator.pop(sheetContext);
                _navigate('/citizen/reports');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    final notifications = _notifications ?? const <AppNotification>[];
    return _DashboardCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigate('/notifications'),
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          if (_notificationsLoading && _notifications == null)
            const _CardMessage(
              icon: null,
              message: 'Loading notifications...',
              loading: true,
              compact: true,
            )
          else if (_notificationsError != null)
            _CardMessage(
              icon: Icons.error_outline_rounded,
              message: _notificationsError!,
              actionLabel: 'Retry',
              onAction: _loadNotifications,
              compact: true,
            )
          else if (notifications.isEmpty)
            const _CardMessage(
              icon: Icons.notifications_none_rounded,
              message: 'No notifications yet.',
              compact: true,
            )
          else
            ...notifications
                .take(4)
                .map(
                  (notification) => _NotificationRow(
                    notification: notification,
                    onTap: () => _navigate('/notifications'),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    const actions = [
      _QuickActionData(
        icon: Icons.add_a_photo_outlined,
        title: 'Report an Issue',
        subtitle: 'Submit a civic concern',
        tint: Color(0xFFEBF3FF),
        color: Color(0xFF2472E4),
        route: '/citizen/submit',
      ),
      _QuickActionData(
        icon: Icons.description_outlined,
        title: 'My Reports',
        subtitle: 'Track your submissions',
        tint: Color(0xFFEAF8F2),
        color: Color(0xFF1CA777),
        route: '/citizen/reports',
      ),
      _QuickActionData(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: 'Updates on your reports',
        tint: Color(0xFFFFF6E2),
        color: Color(0xFFD99A18),
        route: '/notifications',
      ),
    ];

    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          for (final action in actions)
            _QuickActionTile(
              data: action,
              onTap: () => _navigate(action.route),
            ),
          _QuickActionTile(
            data: const _QuickActionData(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'View your account details',
              tint: Color(0xFFF3EEFF),
              color: Color(0xFF8B65D9),
              route: '',
            ),
            onTap: _showProfile,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.collapsed = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool collapsed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFFB6C1D0);
    return Tooltip(
      message: collapsed ? label : '',
      child: Material(
        color: selected ? const Color(0xFF1769E0) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 43,
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 13),
                Icon(icon, color: foreground, size: 19),
                if (!collapsed) ...[
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 11),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE34F59),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, this.size = 38});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE5EEFA),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? 'C' : initials,
        style: const TextStyle(
          color: Color(0xFF326BB4),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color tint;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data, required this.onTap});

  final _MetricData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 119,
          padding: const EdgeInsets.fromLTRB(17, 15, 13, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEBEFF4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: data.tint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(data.icon, size: 18, color: data.color),
                  ),
                  const SizedBox(height: 9),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: data.color.withValues(alpha: 0.72),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                data.value,
                style: TextStyle(
                  color: data.color,
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: const TextStyle(
                  color: Color(0xFF657287),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFEBEFF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardMessage extends StatelessWidget {
  const _CardMessage({
    required this.message,
    this.icon,
    this.loading = false,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String message;
  final IconData? icon;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 21 : 30,
      ),
      child: Column(
        children: [
          if (loading)
            const SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF1769E0),
              ),
            )
          else if (icon != null)
            Icon(icon, color: _CitizenHomeState._muted, size: 25),
          SizedBox(height: loading || icon != null ? 9 : 0),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF758196),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _ReportThumbnail extends StatelessWidget {
  const _ReportThumbnail({
    required this.imageUrl,
    required this.imageHeaders,
    this.size = 38,
  });

  final String? imageUrl;
  final Map<String, String>? Function() imageHeaders;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? const ColoredBox(
                color: Color(0xFFF0F3F8),
                child: Icon(
                  Icons.image_outlined,
                  size: 17,
                  color: Color(0xFF97A3B4),
                ),
              )
            : Image.network(
                url,
                headers: imageHeaders(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFFF0F3F8),
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 17,
                    color: Color(0xFF97A3B4),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ReportListTile extends StatelessWidget {
  const _ReportListTile({
    required this.report,
    required this.issueType,
    required this.location,
    required this.imageHeaders,
    required this.onView,
    required this.onMore,
  });

  final Report report;
  final String issueType;
  final String location;
  final Map<String, String>? Function() imageHeaders;
  final VoidCallback onView;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EBF1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReportThumbnail(
                imageUrl: report.imageUrl,
                imageHeaders: imageHeaders,
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issueType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A2940),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.issueNumber} · $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF758196),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _StatusPill(status: report.status),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More actions',
                onPressed: onMore,
                icon: const Icon(Icons.more_vert_rounded, size: 19),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat(
                      'MMM d, yyyy',
                    ).format(report.createdAt.toLocal()),
                    style: const TextStyle(
                      color: Color(0xFF758196),
                      fontSize: 10,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onView,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1769E0),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().replaceAll('_', ' ');
    final isResolved = normalized == 'resolved';
    final isPending = normalized == 'pending';
    final color = isResolved
        ? const Color(0xFF1CA777)
        : isPending
        ? const Color(0xFFD99A18)
        : const Color(0xFF2472E4);
    final label = normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isResolved = notification.type.toLowerCase().contains('resolved');
    final color = isResolved
        ? const Color(0xFF1CA777)
        : const Color(0xFF2472E4);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isResolved ? Icons.check_rounded : Icons.assignment_outlined,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _CitizenHomeState._ink,
                            fontSize: 11,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 4, left: 5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1769E0),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF758196),
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF9AA4B2),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date.toLocal());
    if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return DateFormat('MMM d').format(date.toLocal());
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color color;
  final String route;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data, required this.onTap});

  final _QuickActionData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: data.tint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: data.tint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, color: data.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          color: _CitizenHomeState._ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        style: const TextStyle(
                          color: _CitizenHomeState._muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Color(0xFF8995A7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
