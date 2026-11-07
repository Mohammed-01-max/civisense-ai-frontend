import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/notification.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../screens/citizen/report_detail_screen.dart';
import '../../screens/officer/officer_report_detail_screen.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _ink = Color(0xFF1A2940);
  static const _muted = Color(0xFF758196);
  static const _border = Color(0xFFE7EBF1);
  static const _tabs = [
    'All',
    'Report Updates',
    'Assignments',
    'Announcements',
  ];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  List<AppNotification>? _notifications;
  String? _error;
  late final NotificationService _service;
  String _selectedTab = _tabs.first;
  bool _isMarkingAllRead = false;

  bool get _isCitizen => context.read<AuthProvider>().role == 'citizen';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _service = NotificationService(auth.apiService);
    _searchController.addListener(_onSearchChanged);
    _loadNotifications();
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

  Future<void> _loadNotifications() async {
    try {
      final notifs = await _service.getMyNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      final updated = await _service.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        final index =
            _notifications?.indexWhere((item) => item.id == notification.id) ??
            -1;
        if (index >= 0) _notifications![index] = updated;
      });
    } catch (e) {
      if (mounted) _showError('Failed to mark as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final unread = (_notifications ?? <AppNotification>[]).where(
      (item) => !item.isRead,
    );
    if (unread.isEmpty || _isMarkingAllRead) return;

    setState(() => _isMarkingAllRead = true);
    final failures = <String>[];
    for (final notification in unread) {
      try {
        final updated = await _service.markAsRead(notification.id);
        if (!mounted) return;
        setState(() {
          final index =
              _notifications?.indexWhere((item) => item.id == updated.id) ?? -1;
          if (index >= 0) _notifications![index] = updated;
        });
      } catch (e) {
        failures.add('${notification.id}: $e');
      }
    }
    if (!mounted) return;
    setState(() => _isMarkingAllRead = false);
    if (failures.isNotEmpty) {
      _showError(
        'Some notifications could not be marked as read '
        '(${failures.length} failed).',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE5484D),
      ),
    );
  }

  String _category(AppNotification notification) {
    final value = '${notification.type} ${notification.title}'.toLowerCase();
    if (value.contains('assign')) return 'Assignments';
    if (value.contains('announcement') || value.contains('general')) {
      return 'Announcements';
    }
    return 'Report Updates';
  }

  int _categoryCount(String category) {
    final notifications = _notifications ?? <AppNotification>[];
    if (category == 'All') return notifications.length;
    return notifications
        .where((notification) => _category(notification) == category)
        .length;
  }

  List<AppNotification> get _visibleNotifications {
    final query = _searchController.text.trim().toLowerCase();
    return (_notifications ?? <AppNotification>[]).where((notification) {
      final matchesCategory =
          _selectedTab == 'All' || _category(notification) == _selectedTab;
      final matchesSearch =
          query.isEmpty ||
          notification.title.toLowerCase().contains(query) ||
          notification.body.toLowerCase().contains(query) ||
          notification.type.toLowerCase().contains(query) ||
          '${notification.reportId ?? ''}'.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Color _notificationColor(AppNotification notification) {
    final value = '${notification.type} ${notification.title}'.toLowerCase();
    if (value.contains('resolv') || value.contains('success')) {
      return const Color(0xFF15945A);
    }
    if (value.contains('assign')) return const Color(0xFFE89A18);
    if (value.contains('review') || value.contains('reject')) {
      return const Color(0xFFE5484D);
    }
    if (value.contains('announcement') || value.contains('general')) {
      return const Color(0xFF7946C8);
    }
    return _blue;
  }

  IconData _notificationIcon(AppNotification notification) {
    final value = '${notification.type} ${notification.title}'.toLowerCase();
    if (value.contains('resolv') || value.contains('success')) {
      return Icons.check_circle_rounded;
    }
    if (value.contains('assign')) return Icons.person_outline_rounded;
    if (value.contains('review') || value.contains('reject')) {
      return Icons.error_rounded;
    }
    if (value.contains('announcement') || value.contains('general')) {
      return Icons.campaign_rounded;
    }
    return Icons.info_outline_rounded;
  }

  String _relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    return DateFormat('MMM d, yyyy').format(dateTime.toLocal());
  }

  Future<void> _openReport(AppNotification notification) async {
    await _markAsRead(notification);
    if (!mounted || notification.reportId == null) return;
    try {
      final auth = context.read<AuthProvider>();
      final role = auth.role;
      final reportService = ReportService(auth.apiService);

      final List<Report> reports;
      if (role == 'officer') {
        reports = await reportService.getAssignedOfficerReports();
      } else if (role == 'admin' || role == 'authority') {
        reports = await reportService.getAllReports();
      } else {
        reports = await reportService.getMyReports();
      }

      if (!mounted) return;
      Report? matchingReport;
      for (final report in reports) {
        if (report.id == notification.reportId) {
          matchingReport = report;
          break;
        }
      }
      if (matchingReport == null) {
        _showError('The linked report is not available.');
        return;
      }
      final Widget target = (role == 'officer')
          ? OfficerReportDetailScreen(report: matchingReport)
          : ReportDetailScreen(report: matchingReport);

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => target,
        ),
      );
    } catch (e) {
      if (mounted) _showError('Failed to open linked report: $e');
    }
  }

  Future<void> _navigate(String route) async {
    if (MediaQuery.sizeOf(context).width < 1000) {
      _scaffoldKey.currentState?.closeDrawer();
    }
    await Navigator.pushNamed(context, route);
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
                name,
                style: const TextStyle(
                  color: _ink,
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

  @override
  Widget build(BuildContext context) {
    if (!_isCitizen) return _buildStaffScreen();

    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final user = context.watch<AuthProvider>().user;
    final userName = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!.trim()
        : 'Citizen';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF6F8FB),
      drawer: desktop ? null : Drawer(child: _buildSidebar(userName)),
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  SizedBox(width: 227, child: _buildSidebar(userName)),
                  Expanded(child: _buildCitizenMain(userName, desktop: true)),
                ],
              )
            : _buildCitizenMain(userName, desktop: false),
      ),
    );
  }

  Widget _buildStaffScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F1A), Color(0xFF16213E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildSidebar(String userName) {
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
                        'Citizen Portal',
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
            onTap: () => _navigate('/citizen'),
          ),
          _sidebarItem(
            Icons.add_circle_outline_rounded,
            'Report an Issue',
            onTap: () => _navigate('/citizen/submit'),
          ),
          _sidebarItem(
            Icons.fact_check_outlined,
            'My Reports',
            onTap: () => _navigate('/citizen/reports'),
          ),
          _sidebarItem(
            Icons.notifications_none_rounded,
            'Notifications',
            selected: true,
            onTap: () => _closeDrawer(),
          ),
          _sidebarItem(
            Icons.person_outline_rounded,
            'Profile',
            onTap: () => _showProfile(userName),
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

  void _closeDrawer() {
    if (MediaQuery.sizeOf(context).width < 1000) {
      _scaffoldKey.currentState?.closeDrawer();
    }
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
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFB6C1D0),
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCitizenMain(String userName, {required bool desktop}) {
    return Column(
      children: [
        _buildHeader(userName, desktop: desktop),
        Expanded(
          child: _error != null
              ? _buildCitizenError()
              : _notifications == null
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: _blue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 26 : 12,
                      desktop ? 24 : 14,
                      desktop ? 26 : 12,
                      20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: _buildNotificationsContent(desktop: desktop),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(String userName, {required bool desktop}) {
    final unreadCount = (_notifications ?? <AppNotification>[])
        .where((item) => !item.isRead)
        .length;
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 22 : 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (!desktop)
            IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: _ink, size: 20),
            )
          else
            const Icon(Icons.menu_rounded, color: _ink, size: 20),
          const SizedBox(width: 18),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 525),
                child: _searchField(
                  hint: 'Search notifications, reports, or updates...',
                  compact: true,
                ),
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
              if (unreadCount > 0)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5484D),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
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
            backgroundColor: _blue,
            child: Text(
              userName.isEmpty ? 'C' : userName[0].toUpperCase(),
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
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.watch<AuthProvider>().role,
                    style: const TextStyle(color: _muted, fontSize: 10),
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

  Widget _searchField({required String hint, required bool compact}) {
    return SizedBox(
      height: compact ? 38 : 40,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: _ink, fontSize: 11),
        decoration: InputDecoration(
          hintText: hint,
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
            borderSide: const BorderSide(color: _blue),
          ),
        ),
      ),
    );
  }

  Widget _buildCitizenError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFE5484D),
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsContent({required bool desktop}) {
    final notifications = _visibleNotifications;
    final total = _notifications!.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Stay updated on the status of your reports and important updates from the municipal team.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final tabs = _buildTabs();
            final markAll = _buildMarkAllButton();
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tabs,
                  ),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: markAll),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tabs,
                  ),
                ),
                const SizedBox(width: 14),
                markAll,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildNotificationList(notifications, desktop: desktop),
        const SizedBox(height: 8),
        _buildFooter(notifications.length, total),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        for (var index = 0; index < _tabs.length; index++)
          _buildTab(_tabs[index], index == 0),
      ],
    );
  }

  Widget _buildTab(String label, bool first) {
    final selected = _selectedTab == label;
    return Padding(
      padding: EdgeInsets.only(right: label == _tabs.last ? 0 : 3),
      child: Material(
        color: selected ? _blue : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => setState(() => _selectedTab = label),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 47,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? _blue : _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF314560),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.94)
                        : const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_categoryCount(label)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF536176),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkAllButton() {
    final hasUnread = (_notifications ?? <AppNotification>[]).any(
      (item) => !item.isRead,
    );
    return OutlinedButton.icon(
      onPressed: hasUnread && !_isMarkingAllRead ? _markAllAsRead : null,
      icon: _isMarkingAllRead
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_rounded, size: 17),
      label: const Text('Mark all as read'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _blue,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildNotificationList(
    List<AppNotification> notifications, {
    required bool desktop,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEF1F5)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: notifications.isEmpty
          ? _buildEmptyList()
          : Column(
              children: [
                for (var index = 0; index < notifications.length; index++)
                  _buildNotificationRow(
                    notifications[index],
                    last: index == notifications.length - 1,
                    desktop: desktop,
                  ),
              ],
            ),
    );
  }

  Widget _buildNotificationRow(
    AppNotification notification, {
    required bool last,
    required bool desktop,
  }) {
    final color = _notificationColor(notification);
    final linkedReport = notification.reportId != null;

    return InkWell(
      onTap: () => _markAsRead(notification),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 15 : 11,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFEBEFF4))),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: notification.isRead
                        ? const SizedBox(width: 12, height: 12)
                        : const DecoratedBox(
                            decoration: BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 12, height: 12),
                          ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _notificationIcon(notification),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _messageWithReportNumber(notification.body),
                    ],
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  Padding(
                    padding: const EdgeInsets.only(left: 35, top: 10),
                    child: Row(
                      children: [
                        Expanded(child: _timeInfo(notification.createdAt)),
                        if (linkedReport) ...[
                          const SizedBox(width: 8),
                          _viewReportButton(notification),
                        ],
                        _overflowMenu(notification),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: content),
                const SizedBox(width: 14),
                SizedBox(width: 180, child: _timeInfo(notification.createdAt)),
                if (linkedReport) ...[
                  const SizedBox(width: 8),
                  _viewReportButton(notification),
                ],
                _overflowMenu(notification),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _messageWithReportNumber(String body) {
    final reportPattern = RegExp(r'#([A-Za-z0-9-]+)');
    final match = reportPattern.firstMatch(body);
    if (match == null) {
      return Text(
        body,
        style: const TextStyle(
          color: Color(0xFF536176),
          fontSize: 11,
          height: 1.45,
        ),
      );
    }
    final start = match.start;
    final end = match.end;
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFF536176),
          fontSize: 11,
          height: 1.45,
        ),
        children: [
          if (start > 0) TextSpan(text: body.substring(0, start)),
          TextSpan(
            text: body.substring(start, end),
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          if (end < body.length) TextSpan(text: body.substring(end)),
        ],
      ),
    );
  }

  Widget _timeInfo(DateTime createdAt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _relativeTime(createdAt),
          style: const TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          DateFormat('MMM d, yyyy, hh:mm a').format(createdAt.toLocal()),
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _viewReportButton(AppNotification notification) {
    return OutlinedButton(
      onPressed: () => _openReport(notification),
      style: OutlinedButton.styleFrom(
        foregroundColor: _blue,
        backgroundColor: const Color(0xFFF5F8FD),
        side: const BorderSide(color: Color(0xFFE6EDF7)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      child: const Text('View Report'),
    );
  }

  Widget _overflowMenu(AppNotification notification) {
    return PopupMenuButton<String>(
      tooltip: 'Notification actions',
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF314560),
        size: 19,
      ),
      onSelected: (action) {
        if (action == 'read') _markAsRead(notification);
        if (action == 'report') _openReport(notification);
      },
      itemBuilder: (context) => [
        if (!notification.isRead)
          const PopupMenuItem(value: 'read', child: Text('Mark as read')),
        if (notification.reportId != null)
          const PopupMenuItem(value: 'report', child: Text('View Report')),
      ],
    );
  }

  Widget _buildEmptyList() {
    final isEmptyAll = _notifications?.isEmpty ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 50),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFFAAB5C3),
            size: 42,
          ),
          const SizedBox(height: 11),
          Text(
            isEmptyAll ? 'No notifications yet' : 'No matching notifications',
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isEmptyAll
                ? 'Updates about your reports will appear here.'
                : 'Try another category or search term.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int visibleCount, int totalCount) {
    final showingStart = visibleCount == 0 ? 0 : 1;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $showingStart to $visibleCount of $totalCount notifications',
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ),
        _pageButton(Icons.chevron_left_rounded, enabled: false),
        const SizedBox(width: 6),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Text(
            '1',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _pageButton(Icons.chevron_right_rounded, enabled: false),
      ],
    );
  }

  Widget _pageButton(IconData icon, {required bool enabled}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: const Color(0xFFAAB5C3), size: 19),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Color(0xFFE5484D)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_notifications == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notifications!.isEmpty) {
      return const Center(
        child: Text(
          'No notifications yet',
          style: TextStyle(color: Color(0xFF9A9ABF), fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications!.length,
        itemBuilder: (context, index) {
          final notification = _notifications![index];
          final isResolved = notification.type == 'REPORT_RESOLVED';
          return Card(
            elevation: notification.isRead ? 0 : 2,
            color: notification.isRead
                ? const Color(0xFF1A1A2E)
                : const Color(0xFF252542),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: notification.isRead
                    ? Colors.transparent
                    : const Color(0xFF6C63FF).withValues(alpha: 0.3),
              ),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                isResolved
                    ? Icons.check_circle_rounded
                    : Icons.assignment_ind_rounded,
                color: notification.isRead
                    ? const Color(0xFF6B6B8D)
                    : isResolved
                    ? const Color(0xFF51CF66)
                    : const Color(0xFF6C63FF),
                size: 32,
              ),
              title: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead
                      ? FontWeight.normal
                      : FontWeight.bold,
                  color: const Color(0xFFE8E8F0),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.body,
                      style: const TextStyle(color: Color(0xFF9A9ABF)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat(
                        'MMM dd, yyyy • hh:mm a',
                      ).format(notification.createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6B8D),
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () => _markAsRead(notification),
            ),
          );
        },
      ),
    );
  }
}
