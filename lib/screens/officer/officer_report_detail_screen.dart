import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class OfficerReportDetailScreen extends StatefulWidget {
  final Report report;

  const OfficerReportDetailScreen({super.key, required this.report});

  @override
  State<OfficerReportDetailScreen> createState() =>
      _OfficerReportDetailScreenState();
}

class _OfficerReportDetailScreenState extends State<OfficerReportDetailScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1769E0);
  static const _background = Color(0xFFF6F8FB);
  static const _surface = Colors.white;
  static const _text = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE7EBF1);
  static const _success = Color(0xFF12B76A);
  static const _warning = Color(0xFFF79009);
  static const _error = Color(0xFFF04438);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapController = MapController();
  double _mapZoom = 14;
  int _unreadCount = 0;

  Report get report => widget.report;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Map<String, String>? _imageHeaders(BuildContext context) {
    final token = context.read<AuthProvider>().apiService.token;
    return token == null ? null : {'Authorization': 'Bearer $token'};
  }

  Future<void> _loadUnreadCount() async {
    try {
      final notifications = await NotificationService(
        context.read<AuthProvider>().apiService,
      ).getMyNotifications();
      final count = notifications.where((item) => !item.isRead).length;
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // The report remains usable if notification counting is unavailable.
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

  String get _category {
    if (report.detections.isNotEmpty) {
      return _formatLabel(report.detections.first.issueType);
    }
    final category = report.triageCategory?.trim();
    return category?.isNotEmpty == true
        ? _formatLabel(category!)
        : 'Not available';
  }

  String get _priority {
    final advisory = report.priorityAdvisory?.level.trim();
    if (advisory?.isNotEmpty == true) return _formatLabel(advisory!);
    final severity = report.severity?.trim();
    if (severity?.isNotEmpty == true) return _formatLabel(severity!);
    return 'Not available';
  }

  Color get _priorityColor {
    final value = report.priorityAdvisory?.level ?? report.severity ?? '';
    switch (value.toUpperCase()) {
      case 'HIGH':
        return _error;
      case 'MEDIUM':
        return _warning;
      case 'LOW':
        return _success;
      default:
        return _muted;
    }
  }

  Color get _statusColor {
    switch (report.status.toLowerCase()) {
      case 'resolved':
        return _success;
      case 'pending':
        return _warning;
      default:
        return _muted;
    }
  }

  String get _location {
    final parts = [
      if (report.areaZone?.trim().isNotEmpty == true) report.areaZone!.trim(),
      if (report.jurisdiction?.trim().isNotEmpty == true)
        report.jurisdiction!.trim(),
    ];
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  String get _assignedOfficer {
    final name = report.assignedOfficer?.name?.trim();
    if (name?.isNotEmpty == true) return name!;
    if (report.assignedOfficerId != null) {
      return 'Officer #${report.assignedOfficerId}';
    }
    return report.assignmentStatus.toLowerCase() == 'assigned'
        ? 'Assigned'
        : 'Not assigned';
  }

  Future<void> _backToReports() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      await Navigator.pushReplacementNamed(context, '/officer');
    }
  }

  Future<void> _navigate(String route) async {
    _closeDrawer();
    if (route == '/officer') {
      await _backToReports();
      return;
    }
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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
            onTap: () => _navigate('/officer'),
          ),
          _sidebarItem(
            Icons.assignment_outlined,
            'Assigned Reports',
            selected: true,
            onTap: () => _navigate('/officer'),
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
    int badge = 0,
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
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFB6C1D0),
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _unreadBadge(badge),
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
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              desktop ? 22 : 12,
              desktop ? 20 : 14,
              desktop ? 22 : 12,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton.icon(
                      onPressed: _backToReports,
                      style: TextButton.styleFrom(
                        foregroundColor: _accent,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 17),
                      label: const Text(
                        'Back to Assigned Reports',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Report Details',
                      style: TextStyle(
                        color: _text,
                        fontSize: desktop ? 27 : 23,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review the submitted report and its available processing information.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: desktop ? 13 : 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 850) {
                          return Column(
                            children: [
                              _buildReportInformation(),
                              const SizedBox(height: 14),
                              _buildMapCard(),
                              const SizedBox(height: 14),
                              _buildAiCard(),
                              const SizedBox(height: 14),
                              _buildProcessingCard(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 58,
                              child: Column(
                                children: [
                                  _buildReportInformation(),
                                  const SizedBox(height: 14),
                                  _buildMapCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 42,
                              child: Column(
                                children: [
                                  _buildProcessingCard(),
                                  const SizedBox(height: 14),
                                  _buildAiCard(),
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
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/notifications'),
            borderRadius: BorderRadius.circular(18),
            child: _unreadBadge(_unreadCount, iconOnly: true),
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
    return Tooltip(
      message: 'Return to Officer Dashboard',
      child: InkWell(
        onTap: () => Navigator.pushReplacementNamed(context, '/officer'),
        borderRadius: BorderRadius.circular(6),
        child: IgnorePointer(
          child: SizedBox(
            height: 38,
            child: TextField(
              readOnly: true,
              style: const TextStyle(color: _text, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Return to Officer Dashboard to search reports...',
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _unreadBadge(int count, {bool iconOnly = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          iconOnly ? Icons.notifications_none_rounded : Icons.circle,
          color: iconOnly ? const Color(0xFF536176) : Colors.transparent,
          size: iconOnly ? 22 : 10,
        ),
        if (count > 0)
          Positioned(
            right: iconOnly ? -7 : -8,
            top: iconOnly ? -7 : -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: _error,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
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
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: _accent, size: 17),
              ),
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
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildReportInformation() {
    final imageUrl = report.imageUrl?.trim();
    return _card(
      title: 'Report Information',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl?.isNotEmpty == true) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: double.infinity,
                height: 220,
                child: Image.network(
                  imageUrl!,
                  headers: _imageHeaders(context),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _imageFallback(
                      child: const CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      _imageFallback(),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            _imageFallback(),
            const SizedBox(height: 14),
          ],
          Text(
            report.description?.trim().isNotEmpty == true
                ? report.description!
                      .trim()
                      .split(RegExp(r'(?<=[.!?])\s+'))
                      .first
                : _category,
            style: const TextStyle(
              color: _text,
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _tag('#${report.issueNumber}', _accent),
              _tag(_category, _accent),
              _tag(
                _formatLabel(report.status),
                _statusColor,
                icon: report.isResolved
                    ? Icons.check_circle_outline_rounded
                    : Icons.schedule_rounded,
              ),
              _tag(_priority, _priorityColor, icon: Icons.flag_outlined),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 8),
          _infoRow(
            Icons.calendar_today_outlined,
            'Submitted',
            DateFormat(
              'MMM d, yyyy · h:mm a',
            ).format(report.createdAt.toLocal()),
          ),
          _infoRow(Icons.location_on_outlined, 'Location', _location),
          _infoRow(
            Icons.my_location_outlined,
            'Coordinates',
            '${report.latitude.toStringAsFixed(5)}, '
                '${report.longitude.toStringAsFixed(5)}',
          ),
          _infoRow(
            Icons.business_outlined,
            'Department',
            report.serviceDepartment?.trim().isNotEmpty == true
                ? report.serviceDepartment!.trim()
                : 'Not available',
          ),
          _infoRow(
            Icons.notes_rounded,
            'Description',
            report.description?.trim().isNotEmpty == true
                ? report.description!.trim()
                : 'Not provided',
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _imageFallback({Widget? child}) {
    return Container(
      width: double.infinity,
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(
        child:
            child ??
            const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF9AA5B4),
              size: 32,
            ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEEF1F4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _muted, size: 16),
          const SizedBox(width: 9),
          SizedBox(
            width: 92,
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
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
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

  Widget _buildMapCard() {
    return _card(
      title: 'Location on Map',
      icon: Icons.map_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 245,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(report.latitude, report.longitude),
                  initialZoom: _mapZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.civisense.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(report.latitude, report.longitude),
                        width: 42,
                        height: 48,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _error,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(Icons.my_location_outlined, color: _accent, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${report.latitude.toStringAsFixed(5)}, '
                  '${report.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ),
              _mapControl(Icons.add_rounded, 'Zoom in', 1),
              const SizedBox(width: 6),
              _mapControl(Icons.remove_rounded, 'Zoom out', -1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapControl(IconData icon, String tooltip, double change) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: () {
          _mapZoom = (_mapZoom + change).clamp(3, 18).toDouble();
          _mapController.move(
            LatLng(report.latitude, report.longitude),
            _mapZoom,
          );
        },
        borderRadius: BorderRadius.circular(5),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: _text, size: 17),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingCard() {
    final assignmentStatus = report.assignmentStatus.trim().isEmpty
        ? 'Not available'
        : _formatLabel(report.assignmentStatus);
    return _card(
      title: 'Processing & Assignment',
      icon: Icons.assignment_turned_in_outlined,
      child: Column(
        children: [
          _processingRow(
            'Current Status',
            _formatLabel(report.status),
            _statusColor,
            report.isResolved
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_rounded,
          ),
          _processingRow(
            'Assignment',
            assignmentStatus,
            report.assignmentStatus.toLowerCase() == 'assigned'
                ? _accent
                : _muted,
            Icons.assignment_ind_outlined,
          ),
          _processingRow(
            'Assigned Officer',
            _assignedOfficer,
            _text,
            Icons.person_outline_rounded,
          ),
          _processingRow(
            'Department',
            report.serviceDepartment?.trim().isNotEmpty == true
                ? report.serviceDepartment!.trim()
                : 'Not available',
            _text,
            Icons.business_outlined,
          ),
          _processingRow(
            'Priority',
            _priority,
            _priorityColor,
            Icons.flag_outlined,
            last: true,
          ),
          if (report.resolvedAt != null) ...[
            const SizedBox(height: 7),
            _processingRow(
              'Resolved On',
              DateFormat(
                'MMM d, yyyy · h:mm a',
              ).format(report.resolvedAt!.toLocal()),
              _success,
              Icons.event_available_outlined,
              last: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _processingRow(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEEF1F4))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    final hasAiData =
        report.triageCategory != null ||
        report.triageConfidence != null ||
        report.severity != null ||
        report.severityConfidence != null ||
        report.priorityAdvisory != null ||
        report.detections.isNotEmpty ||
        report.similarReports.isNotEmpty;
    return _card(
      title: 'AI Analysis',
      icon: Icons.psychology_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasAiData)
            _note(
              Icons.info_outline_rounded,
              'AI analysis information is not available for this report.',
            )
          else ...[
            if (report.triageCategory != null)
              _aiRow('Classification', _formatLabel(report.triageCategory!)),
            if (report.triageConfidence != null)
              _aiRow(
                'AI Confidence',
                _formatConfidence(report.triageConfidence!),
              ),
            if (report.triageSource?.trim().isNotEmpty == true)
              _aiRow('Classification Source', report.triageSource!.trim()),
            if (report.severity != null)
              _aiRow('Severity', _formatLabel(report.severity!)),
            if (report.severityConfidence != null)
              _aiRow(
                'Severity Confidence',
                _formatConfidence(report.severityConfidence!),
              ),
            if (report.severitySource?.trim().isNotEmpty == true)
              _aiRow('Severity Source', report.severitySource!.trim()),
            if (report.priorityAdvisory != null) ...[
              _aiRow(
                'Priority Advisory',
                _formatLabel(report.priorityAdvisory!.level),
                valueColor: _priorityColor,
              ),
              _aiRow(
                'Advisory Reason',
                _formatLabel(report.priorityAdvisory!.reasonCode),
              ),
              _aiRow(
                'Assessment Factors',
                'Severity: ${_formatLabel(report.priorityAdvisory!.factors.severity)}'
                    ' · Visual evidence: '
                    '${_formatLabel(report.priorityAdvisory!.factors.yoloEvidenceState)}'
                    ' · Recurrence: '
                    '${_formatLabel(report.priorityAdvisory!.factors.possibleRecurrence)}',
              ),
            ],
          ],
          const SizedBox(height: 12),
          _sectionLabel('Detected Issues'),
          const SizedBox(height: 7),
          if (report.detections.isEmpty)
            _note(
              Icons.image_search_outlined,
              'No detections are available for this report.',
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: report.detections
                  .map(
                    (detection) =>
                        _tag(_formatLabel(detection.issueType), _accent),
                  )
                  .toList(),
            ),
          if (report.similarReports.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sectionLabel('Related Reports'),
            const SizedBox(height: 4),
            const Text(
              'Similarity matches are not confirmed duplicates.',
              style: TextStyle(color: _muted, fontSize: 9, height: 1.4),
            ),
            const SizedBox(height: 5),
            for (final related in report.similarReports)
              _relatedReportRow(related),
          ],
        ],
      ),
    );
  }

  String _formatConfidence(double confidence) {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  Widget _aiRow(String label, String value, {Color valueColor = _text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _text,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _note(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _muted, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _muted, fontSize: 9, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _relatedReportRow(DuplicateCandidate related) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4))),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: _accent, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              related.issueNumber,
              style: const TextStyle(
                color: _text,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Similarity ${(related.similarityScore * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
