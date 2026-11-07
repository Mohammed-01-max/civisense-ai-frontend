import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class AuthorityHome extends StatefulWidget {
  const AuthorityHome({super.key});

  @override
  State<AuthorityHome> createState() => _AuthorityHomeState();
}

class _AuthorityHomeState extends State<AuthorityHome> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _background = Color(0xFFF6F8FB);
  static const _surface = Colors.white;
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE7EBF1);
  static const _warning = Color(0xFFF79009);
  static const _success = Color(0xFF12B76A);
  static const _error = Color(0xFFF04438);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int? _unreadCount;
  bool _loadingUnread = true;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (mounted) setState(() => _loadingUnread = true);
    try {
      final notifications = await NotificationService(
        context.read<AuthProvider>().apiService,
      ).getMyNotifications();
      if (mounted) {
        setState(() {
          _unreadCount = notifications.where((item) => !item.isRead).length;
          _loadingUnread = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unreadCount = null;
          _loadingUnread = false;
        });
      }
    }
  }

  void _closeDrawer() {
    if (MediaQuery.sizeOf(context).width < 1000) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Future<void> _navigate(String route) async {
    _closeDrawer();
    await Navigator.pushNamed(context, route);
    if (route == '/notifications') _loadUnreadCount();
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _showProfile(String displayName) {
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
                displayName,
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
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final user = context.watch<AuthProvider>().user;
    final displayName = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!.trim()
        : 'Authority';
    final roleLabel = user?.role == 'authority'
        ? 'Municipal Authority'
        : 'Authority Portal';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: desktop ? null : Drawer(child: _buildSidebar(displayName)),
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  SizedBox(width: 227, child: _buildSidebar(displayName)),
                  Expanded(
                    child: _buildMainArea(
                      displayName,
                      roleLabel,
                      desktop: true,
                    ),
                  ),
                ],
              )
            : _buildMainArea(displayName, roleLabel, desktop: false),
      ),
    );
  }

  Widget _buildSidebar(String displayName) {
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
                    mainAxisSize: MainAxisSize.min,
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
                        'Municipal Portal',
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
            Icons.checklist_rtl_rounded,
            'Resolve Issue',
            onTap: () => _navigate('/authority/resolve'),
          ),
          _sidebarItem(
            Icons.notifications_none_rounded,
            'Notifications',
            onTap: () => _navigate('/notifications'),
            badge: _unreadCount,
          ),
          _sidebarItem(
            Icons.person_outline_rounded,
            'Profile',
            onTap: () => _showProfile(displayName),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFB6C1D0),
                      fontSize: 11,
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

  Widget _buildMainArea(
    String displayName,
    String organization, {
    required bool desktop,
  }) {
    return Column(
      children: [
        _buildHeader(displayName, organization, desktop: desktop),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUnreadCount,
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

  Widget _buildHeader(
    String displayName,
    String organization, {
    required bool desktop,
  }) {
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
                child: _searchUnavailableField(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: _loadingUnread
                ? 'Loading unread notifications'
                : _unreadCount == null
                ? 'Unread count unavailable'
                : 'Notifications',
            child: _notificationBell(),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: _blue,
            child: Text(
              displayName.isEmpty ? 'A' : displayName[0].toUpperCase(),
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
              constraints: const BoxConstraints(maxWidth: 190),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    organization,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Profile options',
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF536176),
                size: 19,
              ),
              onSelected: (value) {
                if (value == 'profile') _showProfile(displayName);
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

  Widget _searchUnavailableField() {
    return Tooltip(
      message: 'Authority report search is not available in the current API.',
      child: SizedBox(
        height: 38,
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Report search unavailable for Authority',
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _border),
            ),
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
            else if (_unreadCount == null && !_loadingUnread)
              const Positioned(
                right: -4,
                top: -3,
                child: Icon(Icons.error_outline, color: _warning, size: 13),
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
      decoration: const BoxDecoration(color: _error, shape: BoxShape.circle),
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
                    'Dashboard',
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
                    'Overview of Authority actions and account notifications.',
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
            if (desktop) ...[
              const SizedBox(width: 12),
              _unavailableDateControl(),
            ],
          ],
        ),
        if (!desktop) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _unavailableDateControl(),
          ),
        ],
        const SizedBox(height: 18),
        _buildMetricCards(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  _buildUnavailablePanel(
                    title: 'Reports Trend',
                    icon: Icons.bar_chart_rounded,
                    message:
                        'Trend data is unavailable. Authority has no report-list or time-series endpoint.',
                  ),
                  const SizedBox(height: 14),
                  _buildUnavailablePanel(
                    title: 'Reports by Status',
                    icon: Icons.format_list_bulleted_rounded,
                    message:
                        'Status counts are unavailable. Report analytics are restricted to Admin.',
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 58,
                  child: _buildUnavailablePanel(
                    title: 'Reports Trend',
                    icon: Icons.bar_chart_rounded,
                    message:
                        'Trend data is unavailable. Authority has no report-list or time-series endpoint.',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 42,
                  child: _buildUnavailablePanel(
                    title: 'Reports by Status',
                    icon: Icons.format_list_bulleted_rounded,
                    message:
                        'Status counts are unavailable. Report analytics are restricted to Admin.',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _buildRecentReports(),
        const SizedBox(height: 14),
        _buildResolvePanel(),
      ],
    );
  }

  Widget _unavailableDateControl() {
    return Tooltip(
      message: 'The current Authority APIs do not support date filtering.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, color: _muted, size: 15),
            SizedBox(width: 7),
            Text(
              'Date range unavailable',
              style: TextStyle(color: _muted, fontSize: 10),
            ),
            SizedBox(width: 5),
            Icon(Icons.keyboard_arrow_down_rounded, color: _muted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCards() {
    final metrics = [
      _MetricInfo(
        title: 'Total Reports',
        value: 'Unavailable',
        detail: 'Authority report listing is not provided',
        icon: Icons.description_outlined,
        color: _blue,
      ),
      _MetricInfo(
        title: 'Pending Reports',
        value: 'Unavailable',
        detail: 'No Authority report counts endpoint',
        icon: Icons.schedule_rounded,
        color: _warning,
      ),
      _MetricInfo(
        title: 'Resolved Reports',
        value: 'Unavailable',
        detail: 'No Authority report counts endpoint',
        icon: Icons.check_circle_outline_rounded,
        color: _success,
      ),
      _MetricInfo(
        title: 'Unread Notifications',
        value: _loadingUnread
            ? 'Loading'
            : _unreadCount?.toString() ?? 'Unavailable',
        detail: _unreadCount == null && !_loadingUnread
            ? 'Could not retrieve notification count'
            : 'From your notification account',
        icon: Icons.notifications_none_rounded,
        color: _blue,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(width: width, child: _metricCard(metric)),
          ],
        );
      },
    );
  }

  Widget _metricCard(_MetricInfo metric) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(metric.icon, color: metric.color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.title,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 5),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: metric.value == 'Unavailable' ? _muted : _text,
                    fontSize: metric.value == 'Unavailable' ? 16 : 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailablePanel({
    required String title,
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 19),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.insert_chart_outlined_rounded,
                    color: const Color(0xFF98A2B3).withValues(alpha: 0.8),
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Data unavailable',
                    style: TextStyle(
                      color: _text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecentReports() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                onPressed: () => _showUnavailableMessage(
                  'The Authority API does not provide a report-list screen.',
                ),
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
          const SizedBox(height: 12),
          _buildUnavailableFilters(),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 23),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFEDF0F4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.inbox_outlined,
                  color: Color(0xFF98A2B3),
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Report list unavailable',
                  style: TextStyle(
                    color: _text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Report retrieval is not exposed to the Authority role. '
                  'Use the supported resolution workflow to look up an issue by its number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 9, height: 1.4),
                ),
                const SizedBox(height: 11),
                OutlinedButton.icon(
                  onPressed: () => _navigate('/authority/resolve'),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                  ),
                  label: const Text('Open Resolve Issue'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _blue),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableFilters() {
    const labels = [
      'Search unavailable',
      'Department filter unavailable',
      'Status filter unavailable',
      'Priority filter unavailable',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        final itemWidth = compact
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 24) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in labels)
              SizedBox(
                width: itemWidth,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildResolvePanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
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
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final details = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Authority Resolution',
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Resolve an issue using its report number. This is the report action currently supported for Authority.',
                style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
              ),
            ],
          );
          final button = ElevatedButton.icon(
            onPressed: () => _navigate('/authority/resolve'),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
            label: const Text('Resolve an Issue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: button),
              ],
            );
          }
          return Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: _success, size: 27),
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }

  void _showUnavailableMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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

class _MetricInfo {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _MetricInfo({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
}
