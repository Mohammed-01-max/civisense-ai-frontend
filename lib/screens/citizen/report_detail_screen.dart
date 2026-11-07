import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _ink = Color(0xFF1A2940);
  static const _muted = Color(0xFF758196);
  static const _border = Color(0xFFE7EBF1);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _timelineKey = GlobalKey();
  final _mapController = MapController();
  double _mapZoom = 14;

  Report get report => widget.report;

  Map<String, String>? _imageHeaders(BuildContext context) {
    final token = context.read<AuthProvider>().apiService.token;
    return token == null ? null : {'Authorization': 'Bearer $token'};
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
    if (report.triageCategory?.trim().isNotEmpty == true) {
      return _formatLabel(report.triageCategory!);
    }
    return 'Not available';
  }

  String get _title {
    final description = report.description?.trim() ?? '';
    if (description.isNotEmpty) {
      return description.split(RegExp(r'(?<=[.!?])\s+')).first;
    }
    return _category == 'Not available' ? 'Civic issue' : _category;
  }

  String get _location {
    final parts = [
      if (report.areaZone?.trim().isNotEmpty == true) report.areaZone!.trim(),
      if (report.jurisdiction?.trim().isNotEmpty == true)
        report.jurisdiction!.trim(),
    ];
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  String get _normalizedStatus =>
      report.status.toLowerCase().replaceAll('_', ' ').trim();

  String get _statusLabel => _formatLabel(report.status);

  Color get _statusColor {
    switch (_normalizedStatus) {
      case 'resolved':
        return const Color(0xFF168B58);
      case 'pending':
        return const Color(0xFFB97808);
      default:
        return _blue;
    }
  }

  bool get _hasAiResult =>
      report.detections.isNotEmpty ||
      report.triageCategory != null ||
      report.triageConfidence != null ||
      report.severity != null ||
      report.severityConfidence != null ||
      report.priorityAdvisory != null;

  bool get _isAssigned =>
      report.assignmentStatus.toLowerCase() == 'assigned' ||
      report.assignedOfficerId != null ||
      report.assignedOfficer != null;

  bool get _isResolved =>
      _normalizedStatus == 'resolved' ||
      _normalizedStatus == 'closed' ||
      report.resolvedAt != null;

  int get _activeStage {
    if (_isResolved) return -1;
    if (_isAssigned) return 2;
    if (_hasAiResult) return 1;
    return 0;
  }

  bool _stageComplete(int index) {
    return switch (index) {
      0 => true,
      1 => _hasAiResult,
      2 => _isAssigned,
      3 => _isResolved,
      _ => false,
    };
  }

  void _closeDrawer() {
    if (MediaQuery.sizeOf(context).width < 1000) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Future<void> _navigate(String route) async {
    _closeDrawer();
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

  Future<void> _scrollToTimeline() async {
    final targetContext = _timelineKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
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
                  Expanded(child: _buildMainArea(userName, desktop: true)),
                ],
              )
            : _buildMainArea(userName, desktop: false),
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
            selected: true,
            onTap: _closeDrawer,
          ),
          _sidebarItem(
            Icons.notifications_none_rounded,
            'Notifications',
            onTap: () => _navigate('/notifications'),
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
                  size: 18,
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

  Widget _buildMainArea(String userName, {required bool desktop}) {
    return Column(
      children: [
        _buildHeader(userName, desktop: desktop),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              desktop ? 16 : 12,
              16,
              desktop ? 16 : 12,
              20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: _buildContent(desktop: desktop),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String userName, {required bool desktop}) {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 20 : 8),
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: Color(0xFF8693A6),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search reports by ID, title, or location...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF536176),
            size: 22,
          ),
          const SizedBox(width: 15),
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

  Widget _buildContent({required bool desktop}) {
    return Container(
      padding: EdgeInsets.all(desktop ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPageHeading(desktop: desktop),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    _buildBasicInformation(),
                    const SizedBox(height: 12),
                    _buildMapCard(),
                    const SizedBox(height: 12),
                    _buildCurrentStatus(),
                    const SizedBox(height: 12),
                    _buildAiCard(),
                    const SizedBox(height: 12),
                    _buildTimelineCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 54,
                    child: Column(
                      children: [
                        _buildBasicInformation(),
                        const SizedBox(height: 12),
                        _buildMapCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 46,
                    child: Column(
                      children: [
                        _buildCurrentStatus(),
                        const SizedBox(height: 12),
                        _buildAiCard(),
                        const SizedBox(height: 12),
                        _buildTimelineCard(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeading({required bool desktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(5),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF60738F),
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Back to My Reports',
                  style: TextStyle(
                    color: Color(0xFF536176),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: _blue,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Details',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View complete details, status and updates of this report.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: desktop ? 12 : 11,
                    ),
                  ),
                ],
              ),
            ),
            if (desktop) ...[
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _scrollToTimeline,
                icon: const Icon(Icons.notifications_none_rounded, size: 16),
                label: const Text('Track Updates'),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!desktop) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _scrollToTimeline,
            icon: const Icon(Icons.notifications_none_rounded, size: 15),
            label: const Text('Track Updates'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
    Color iconColor = _blue,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.025),
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
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF17243A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE8ECF1)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBasicInformation() {
    final user = context.watch<AuthProvider>().user;
    final reportedBy = user?.fullName?.trim().isNotEmpty == true
        ? '${user!.fullName!.trim()} (${_formatLabel(user.role)})'
        : _formatLabel(user?.role ?? 'Citizen');
    final date = DateFormat(
      'MMM d, yyyy, hh:mm a',
    ).format(report.createdAt.toLocal());

    return _card(
      icon: Icons.description_rounded,
      title: 'Basic Information',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = constraints.maxWidth >= 620
              ? constraints.maxWidth * 0.42
              : 150.0;
          final topSection = constraints.maxWidth >= 500
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReportImage(imageWidth, 192),
                    const SizedBox(width: 18),
                    Expanded(child: _buildReportSummary(date, reportedBy)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReportImage(constraints.maxWidth, 190),
                    const SizedBox(height: 13),
                    _buildReportSummary(date, reportedBy),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topSection,
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE8ECF1)),
              _infoRow(
                Icons.home_work_outlined,
                'Status',
                _statusLabel,
                valueWidget: _statusPill(),
              ),
              _infoRow(Icons.calendar_today_outlined, 'Submitted On', date),
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
                    : 'Not provided',
              ),
              _infoRow(Icons.person_outline_rounded, 'Reported By', reportedBy),
              _infoRow(
                Icons.notes_rounded,
                'Description',
                report.description?.trim().isNotEmpty == true
                    ? report.description!.trim()
                    : 'Not provided',
                last: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportImage(double width, double height) {
    final imageUrl = report.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl?.isNotEmpty == true
            ? Image.network(
                imageUrl!,
                headers: _imageHeaders(context),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _imagePlaceholder(
                    child: const CircularProgressIndicator(
                      color: _blue,
                      strokeWidth: 2,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    _imagePlaceholder(),
              )
            : _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder({Widget? child}) {
    return ColoredBox(
      color: const Color(0xFFF1F4F8),
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

  Widget _buildReportSummary(String date, String reportedBy) {
    final category = report.detections.isNotEmpty
        ? report.detections.first.issueType
        : report.triageCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 19,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _tag('#${report.issueNumber}', const Color(0xFF9B4354)),
            if (category != null)
              _tag(_formatLabel(category), _categoryColor(category)),
          ],
        ),
        const SizedBox(height: 12),
        _summaryLine(Icons.calendar_today_outlined, date),
        const SizedBox(height: 6),
        _summaryLine(Icons.location_on_outlined, _location),
        const SizedBox(height: 6),
        _summaryLine(Icons.person_outline_rounded, reportedBy),
      ],
    );
  }

  Color _categoryColor(String category) {
    final value = category.toLowerCase();
    if (value.contains('garbage') || value.contains('waste')) {
      return const Color(0xFF22985A);
    }
    if (value.contains('light')) return const Color(0xFF7446C8);
    if (value.contains('water')) return const Color(0xFF1685B7);
    if (value.contains('tree')) return const Color(0xFF29924F);
    if (value.contains('footpath')) return const Color(0xFFD94658);
    return _blue;
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _summaryLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF60738F), size: 14),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF536176),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusPill() {
    final icon = switch (_normalizedStatus) {
      'resolved' => Icons.check_circle_outline_rounded,
      'pending' => Icons.schedule_rounded,
      _ => Icons.info_outline_rounded,
    };
    return _tagWithIcon(_statusLabel, _statusColor, icon);
  }

  Widget _tagWithIcon(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Widget? valueWidget,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE8ECF1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF314560), size: 17),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF314560),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child:
                valueWidget ??
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF34445B),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    return _card(
      icon: Icons.map_outlined,
      title: 'Location on Map',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  FlutterMap(
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
                              color: Color(0xFFE24D59),
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
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Column(
                      children: [
                        _mapControl(
                          Icons.add_rounded,
                          'Zoom in',
                          () => _changeZoom(1),
                        ),
                        const SizedBox(height: 5),
                        _mapControl(
                          Icons.remove_rounded,
                          'Zoom out',
                          () => _changeZoom(-1),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 60,
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${report.latitude.toStringAsFixed(5)}, '
                        '${report.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _summaryLine(Icons.location_on_outlined, _location),
          const SizedBox(height: 5),
          _summaryLine(
            Icons.my_location_outlined,
            '${report.latitude.toStringAsFixed(5)}, '
            '${report.longitude.toStringAsFixed(5)}',
          ),
        ],
      ),
    );
  }

  Widget _mapControl(IconData icon, String tooltip, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(5),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: _ink, size: 19),
      ),
    );
  }

  void _changeZoom(double amount) {
    _mapZoom = (_mapZoom + amount).clamp(3, 18);
    _mapController.move(LatLng(report.latitude, report.longitude), _mapZoom);
  }

  Widget _buildCurrentStatus() {
    const steps = [
      'Submitted',
      'AI Analysis',
      'Department Assigned',
      'Resolved',
    ];
    final hasHistoryTimestamp = report.resolvedAt != null;

    return _card(
      icon: Icons.schedule_rounded,
      title: 'Current Status',
      iconColor: const Color(0xFFF39A12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 460;
          final markerWidth = compact ? 22.0 : 28.0;
          final horizontalInset = markerWidth / 2;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalInset),
                child: Row(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      _timelineDot(i),
                      if (i != steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 3,
                            color: _stageComplete(i + 1)
                                ? _blue
                                : const Color(0xFFDDE3EB),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          children: [
                            Text(
                              steps[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _stageComplete(i) || i == _activeStage
                                    ? _ink
                                    : _muted,
                                fontSize: compact ? 8 : 9,
                                height: 1.25,
                                fontWeight: i == _activeStage
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _stageDetail(i),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 8,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (hasHistoryTimestamp) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Resolved ${DateFormat('MMM d, yyyy, hh:mm a').format(report.resolvedAt!.toLocal())}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _timelineDot(int index) {
    final completed = _stageComplete(index);
    final current = index == _activeStage;
    final color = completed || current ? _blue : const Color(0xFFDDE3EB);
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        color: completed ? _blue : const Color(0xFFE6EBF1),
        shape: BoxShape.circle,
        border: current
            ? Border.all(color: const Color(0xFFBDD5FF), width: 3)
            : null,
      ),
      child: Icon(
        completed ? Icons.check_rounded : Icons.circle,
        size: completed ? 15 : 9,
        color: completed ? Colors.white : color,
      ),
    );
  }

  String _stageDetail(int index) {
    if (index == 0) {
      return DateFormat('MMM d, hh:mm a').format(report.createdAt.toLocal());
    }
    if (index == 1) return _hasAiResult ? 'Results available' : 'Pending';
    if (index == 2) {
      if (_isAssigned) return 'Assigned';
      if (report.serviceDepartment?.trim().isNotEmpty == true) {
        return 'Suggested';
      }
      return 'Pending';
    }
    if (_isResolved) {
      return report.resolvedAt == null
          ? 'Resolved'
          : DateFormat('MMM d, hh:mm a').format(report.resolvedAt!.toLocal());
    }
    return 'Pending';
  }

  Widget _buildAiCard() {
    final detectionNames = report.detections
        .map((detection) => _formatLabel(detection.issueType))
        .toList();
    final department = report.serviceDepartment?.trim();
    final priority = report.priorityAdvisory;

    return _card(
      icon: Icons.psychology_outlined,
      title: 'AI Analysis & Classification',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          border: Border.all(color: const Color(0xFFE0ECFB)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAiImage(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'AI Analysis Result',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _tagWithIcon(
                        _hasAiResult ? 'Available' : 'Not available',
                        _hasAiResult ? _blue : _muted,
                        _hasAiResult
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (detectionNames.isNotEmpty)
                    _aiInfo('Detected Issue', detectionNames.join(', ')),
                  if (detectionNames.isEmpty && report.triageCategory != null)
                    _aiInfo('Category', _formatLabel(report.triageCategory!)),
                  if (report.triageConfidence != null)
                    _aiInfo(
                      'Confidence Score',
                      '${report.triageConfidence!.toStringAsFixed(2)} '
                          '(${(report.triageConfidence! * 100).toStringAsFixed(0)}%)',
                    ),
                  if (report.severity != null)
                    _aiInfo(
                      'Severity Level',
                      _formatLabel(report.severity!),
                      valueWidget: _tagWithIcon(
                        _formatLabel(report.severity!),
                        _severityColor(report.severity!),
                        Icons.warning_amber_rounded,
                      ),
                    ),
                  if (report.severityConfidence != null)
                    _aiInfo(
                      'Severity Confidence',
                      '${report.severityConfidence!.toStringAsFixed(2)} '
                          '(${(report.severityConfidence! * 100).toStringAsFixed(0)}%)',
                    ),
                  if (department?.isNotEmpty == true)
                    _aiInfo('Suggested Department', department),
                  if (report.triageSource?.isNotEmpty == true)
                    _aiInfo('Classification Model', report.triageSource),
                  if (report.severitySource?.isNotEmpty == true)
                    _aiInfo('Severity Model', report.severitySource),
                  if (priority != null) ...[
                    _aiInfo('Priority Advisory', _formatLabel(priority.level)),
                    _aiInfo(
                      'Priority Reason',
                      _formatLabel(priority.reasonCode),
                    ),
                    _aiInfo(
                      'Assessment Factors',
                      '${_formatLabel(priority.factors.severity)}, '
                          '${_formatLabel(priority.factors.yoloEvidenceState)}, '
                          '${_formatLabel(priority.factors.possibleRecurrence)}',
                    ),
                  ],
                  if (!_hasAiResult)
                    const Text(
                      'No AI assessment fields were returned for this report.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        height: 1.4,
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

  Widget _buildAiImage() {
    final imageUrl = report.imageUrl;
    if (imageUrl?.isNotEmpty != true) {
      return SizedBox(width: 82, height: 94, child: _imagePlaceholder());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 82,
        height: 94,
        child: Image.network(
          imageUrl!,
          headers: _imageHeaders(context),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
        ),
      ),
    );
  }

  Widget _aiInfo(String label, String? value, {Widget? valueWidget}) {
    if ((value == null || value.trim().isEmpty) && valueWidget == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 114,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
            ),
          ),
          Expanded(
            child:
                valueWidget ??
                Text(
                  value!,
                  style: const TextStyle(
                    color: Color(0xFF34445B),
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return const Color(0xFFE5484D);
      case 'medium':
        return const Color(0xFFB97808);
      case 'low':
        return const Color(0xFF168B58);
      default:
        return _blue;
    }
  }

  Widget _buildTimelineCard() {
    final events = <_ReportEvent>[
      _ReportEvent(
        title: 'Report Submitted',
        description: 'Your report was submitted.',
        time: report.createdAt,
        color: _blue,
      ),
    ];

    if (_hasAiResult) {
      events.add(
        _ReportEvent(
          title: 'AI Analysis',
          description: 'AI assessment data is available for this report.',
          color: _blue,
        ),
      );
    }

    if (_isAssigned) {
      final officer = report.assignedOfficer?.name;
      events.add(
        _ReportEvent(
          title: 'Department Assigned',
          description: officer?.isNotEmpty == true
              ? 'Assigned to $officer.'
              : report.serviceDepartment?.trim().isNotEmpty == true
              ? 'Assignment status: ${_formatLabel(report.assignmentStatus)} · ${report.serviceDepartment}.'
              : 'Assignment status: ${_formatLabel(report.assignmentStatus)}.',
          color: _blue,
        ),
      );
    }

    if (_isResolved) {
      events.add(
        _ReportEvent(
          title: 'Resolved',
          description: 'This report is marked resolved.',
          time: report.resolvedAt,
          color: const Color(0xFF168B58),
        ),
      );
    }

    return _card(
      icon: Icons.format_list_bulleted_rounded,
      title: 'Updates & Timeline',
      child: Column(
        key: _timelineKey,
        children: [
          for (var index = 0; index < events.length; index++)
            _timelineEvent(events[index], index < events.length - 1),
        ],
      ),
    );
  }

  Widget _timelineEvent(_ReportEvent event, bool hasNext) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: event.color,
                  shape: BoxShape.circle,
                ),
              ),
              if (hasNext)
                Container(width: 2, height: 42, color: const Color(0xFFDDE3EB)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (event.time != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        DateFormat(
                          'MMM d, yyyy\nhh:mm a',
                        ).format(event.time!.toLocal()),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF60738F),
                          fontSize: 9,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.description,
                  style: const TextStyle(
                    color: Color(0xFF60738F),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportEvent {
  final String title;
  final String description;
  final DateTime? time;
  final Color color;

  const _ReportEvent({
    required this.title,
    required this.description,
    this.time,
    required this.color,
  });
}
