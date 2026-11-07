import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/report_service.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF1769E0);
  static const _ink = Color(0xFF1A2940);
  static const _muted = Color(0xFF758196);
  static const _border = Color(0xFFE7EBF1);
  static const _tabs = ['All Reports', 'Pending', 'Resolved'];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  List<Report>? _reports;
  bool _isLoading = true;
  String? _error;
  String _selectedTab = _tabs.first;
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Status';
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadReports();
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

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().apiService;
      final reports = await ReportService(api).getMyReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _statusLabel(String status) {
    final normalized = status.toLowerCase().replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _category(Report report) {
    if (report.detections.isNotEmpty) {
      return _statusLabel(report.detections.first.issueType);
    }
    final triageCategory = report.triageCategory;
    if (triageCategory != null && triageCategory.trim().isNotEmpty) {
      return _statusLabel(triageCategory);
    }
    return 'Uncategorized';
  }

  String _title(Report report) {
    final description = report.description?.trim() ?? '';
    if (description.isEmpty) return _category(report);
    final firstSentence = description.split(RegExp(r'(?<=[.!?])\s+')).first;
    return firstSentence;
  }

  Color _categoryColor(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('garbage') || normalized.contains('waste')) {
      return const Color(0xFF22985A);
    }
    if (normalized.contains('light')) return const Color(0xFF7446C8);
    if (normalized.contains('water')) return const Color(0xFF1685B7);
    if (normalized.contains('tree')) return const Color(0xFF29924F);
    if (normalized.contains('footpath')) return const Color(0xFFD94658);
    return _blue;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase().replaceAll('_', ' ').trim()) {
      case 'resolved':
        return const Color(0xFF168B58);
      case 'pending':
        return const Color(0xFFB97808);
      default:
        return const Color(0xFF1769E0);
    }
  }

  List<String> get _categories {
    final categories =
        _reports
            ?.map(_category)
            .where((category) => category != 'Uncategorized')
            .toSet()
            .toList() ??
        <String>[];
    categories.sort();
    return ['All Categories', ...categories];
  }

  List<Report> get _visibleReports {
    final reports = _reports ?? <Report>[];
    final query = _searchController.text.trim().toLowerCase();
    final visible = reports.where((report) {
      final normalizedStatus = report.status
          .toLowerCase()
          .replaceAll('_', ' ')
          .trim();
      final matchesTab = switch (_selectedTab) {
        'Pending' => normalizedStatus == 'pending',
        'Resolved' => normalizedStatus == 'resolved',
        _ => true,
      };
      final matchesCategory =
          _selectedCategory == 'All Categories' ||
          _category(report) == _selectedCategory;
      final matchesStatus =
          _selectedStatus == 'All Status' ||
          _statusLabel(report.status) == _selectedStatus;
      final matchesQuery =
          query.isEmpty ||
          report.issueNumber.toLowerCase().contains(query) ||
          _title(report).toLowerCase().contains(query) ||
          _category(report).toLowerCase().contains(query) ||
          (report.areaZone ?? '').toLowerCase().contains(query) ||
          (report.jurisdiction ?? '').toLowerCase().contains(query);
      return matchesTab && matchesCategory && matchesStatus && matchesQuery;
    }).toList();
    visible.sort(
      (a, b) => _newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return visible;
  }

  int _tabCount(String tab) {
    final reports = _reports ?? <Report>[];
    if (tab == 'All Reports') return reports.length;
    return reports.where((report) {
      final status = report.status.toLowerCase().replaceAll('_', ' ').trim();
      return switch (tab) {
        'Pending' => status == 'pending',
        'Resolved' => status == 'resolved',
        _ => false,
      };
    }).length;
  }

  Future<void> _openReport(Report report) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report),
      ),
    );
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
            onTap: () {},
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  color: _blue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 20 : 12,
                      18,
                      desktop ? 20 : 12,
                      22,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: _buildReportsContent(userName, desktop: desktop),
                      ),
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
                child: _searchField(
                  hint: 'Search reports by ID, title, or location...',
                  compact: true,
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE5484D), size: 44),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _loadReports, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsContent(String userName, {required bool desktop}) {
    return Container(
      padding: EdgeInsets.all(desktop ? 20 : 14),
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
          _buildPageTitle(desktop: desktop),
          const SizedBox(height: 18),
          _buildStatusTabs(),
          const SizedBox(height: 12),
          _buildFilters(desktop: desktop),
          const SizedBox(height: 16),
          if (_reports?.isEmpty ?? true)
            _buildEmpty(
              'No reports yet',
              'Submit your first civic issue report.',
            )
          else if (_visibleReports.isEmpty)
            _buildEmpty(
              'No matching reports',
              'Try changing your search or filters.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 1050
                  ? _buildTable(_visibleReports)
                  : _buildReportCards(_visibleReports),
            ),
        ],
      ),
    );
  }

  Widget _buildPageTitle({required bool desktop}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.description_rounded, color: _blue, size: 23),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Reports',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'View and track the status of all your submitted reports.',
                style: TextStyle(color: _muted, fontSize: desktop ? 12 : 11),
              ),
            ],
          ),
        ),
        if (desktop) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _navigate('/citizen/submit'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Submit New Report'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
        if (!desktop)
          IconButton(
            tooltip: 'Submit new report',
            onPressed: () => _navigate('/citizen/submit'),
            icon: const Icon(Icons.add_circle_outline_rounded, color: _blue),
          ),
      ],
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _buildStatusTab(_tabs[i], i == 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab(String label, bool first) {
    final selected = _selectedTab == label;
    final icon = switch (label) {
      'Pending' => Icons.schedule_rounded,
      'Resolved' => Icons.check_rounded,
      _ => Icons.fact_check_outlined,
    };
    final color = switch (label) {
      'Pending' => const Color(0xFFF39A12),
      'Resolved' => const Color(0xFF18A05E),
      _ => _blue,
    };

    return Material(
      color: selected ? const Color(0xFFEAF2FF) : Colors.transparent,
      borderRadius: BorderRadius.horizontal(
        left: first ? const Radius.circular(6) : Radius.zero,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedTab = label),
        borderRadius: BorderRadius.horizontal(
          left: first ? const Radius.circular(6) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _blue : const Color(0xFF314560),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFD9E8FF)
                      : const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${_tabCount(label)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF536176),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters({required bool desktop}) {
    if (!desktop) {
      return Column(
        children: [
          _searchField(
            hint: 'Search by title, ID, or location...',
            compact: false,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _categoryFilter()),
              const SizedBox(width: 8),
              Expanded(child: _statusFilter()),
            ],
          ),
          const SizedBox(height: 8),
          _sortFilter(),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 16,
          child: _searchField(
            hint: 'Search by title, ID, or location...',
            compact: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 11, child: _categoryFilter()),
        const SizedBox(width: 12),
        Expanded(flex: 10, child: _statusFilter()),
        const SizedBox(width: 90),
        SizedBox(width: 170, child: _sortFilter()),
      ],
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
          fillColor: const Color(0xFFF5F7FA),
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

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    IconData? icon,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFF536176), size: 17),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(value) ? value : items.first,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF718097),
                  size: 18,
                ),
                style: const TextStyle(color: _ink, fontSize: 11),
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (item) {
                  if (item != null) onChanged(item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryFilter() => _dropdown(
    value: _selectedCategory,
    items: _categories,
    onChanged: (value) => setState(() => _selectedCategory = value),
  );

  Widget _statusFilter() {
    final statuses =
        (_reports ?? <Report>[])
            .map((report) => _statusLabel(report.status))
            .toSet()
            .toList()
          ..sort();
    return _dropdown(
      value: _selectedStatus,
      items: ['All Status', ...statuses],
      onChanged: (value) => setState(() => _selectedStatus = value),
    );
  }

  Widget _sortFilter() => _dropdown(
    value: _newestFirst ? 'Newest First' : 'Oldest First',
    items: const ['Newest First', 'Oldest First'],
    icon: Icons.calendar_month_outlined,
    onChanged: (value) =>
        setState(() => _newestFirst = value == 'Newest First'),
  );

  Widget _buildTable(List<Report> reports) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8ECF1)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 34, child: _TableHeading('REPORT')),
                Expanded(flex: 13, child: _TableHeading('CATEGORY')),
                Expanded(flex: 13, child: _TableHeading('STATUS')),
                Expanded(flex: 21, child: _TableHeading('LOCATION')),
                Expanded(flex: 17, child: _TableHeading('SUBMITTED ON')),
                SizedBox(width: 118, child: _TableHeading('ACTIONS')),
              ],
            ),
          ),
          for (var i = 0; i < reports.length; i++)
            _buildTableRow(reports[i], i == reports.length - 1),
        ],
      ),
    );
  }

  Widget _buildTableRow(Report report, bool last) {
    final category = _category(report);
    final status = _statusLabel(report.status);
    final location = [
      if (report.areaZone?.trim().isNotEmpty == true) report.areaZone!.trim(),
      if (report.jurisdiction?.trim().isNotEmpty == true)
        report.jurisdiction!.trim(),
    ].join(', ');

    return InkWell(
      onTap: () => _openReport(report),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFE8ECF1))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 34,
              child: Row(
                children: [
                  _thumbnail(report, width: 72, height: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${report.issueNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _title(report),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _pill(category, _categoryColor(category)),
              ),
            ),
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _pill(
                  status,
                  _statusColor(report.status),
                  icon: _statusIcon(report.status),
                ),
              ),
            ),
            Expanded(
              flex: 21,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF607C9F),
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      location.isEmpty ? 'Not provided' : location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ink, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 17,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat(
                      'MMM d, yyyy',
                    ).format(report.createdAt.toLocal()),
                    style: const TextStyle(color: _ink, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('hh:mm a').format(report.createdAt.toLocal()),
                    style: const TextStyle(
                      color: Color(0xFF607C9F),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 118,
              child: OutlinedButton(
                onPressed: () => _openReport(report),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF314560),
                  backgroundColor: const Color(0xFFF5F7FA),
                  side: const BorderSide(color: Color(0xFFE9EDF2)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Details'),
                    SizedBox(width: 5),
                    Icon(Icons.chevron_right_rounded, size: 17),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCards(List<Report> reports) {
    return Column(
      children: reports
          .map(
            (report) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: InkWell(
                onTap: () => _openReport(report),
                borderRadius: BorderRadius.circular(7),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _thumbnail(report, width: 66, height: 50),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${report.issueNumber}',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _title(report),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'View details',
                            onPressed: () => _openReport(report),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF607C9F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 7,
                        children: [
                          _pill(
                            _category(report),
                            _categoryColor(_category(report)),
                          ),
                          _pill(
                            _statusLabel(report.status),
                            _statusColor(report.status),
                            icon: _statusIcon(report.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF607C9F),
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              [
                                    if (report.areaZone?.trim().isNotEmpty ==
                                        true)
                                      report.areaZone!.trim(),
                                    if (report.jurisdiction
                                            ?.trim()
                                            .isNotEmpty ==
                                        true)
                                      report.jurisdiction!.trim(),
                                  ].join(', ').isEmpty
                                  ? 'Not provided'
                                  : [
                                      if (report.areaZone?.trim().isNotEmpty ==
                                          true)
                                        report.areaZone!.trim(),
                                      if (report.jurisdiction
                                              ?.trim()
                                              .isNotEmpty ==
                                          true)
                                        report.jurisdiction!.trim(),
                                    ].join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'MMM d, yyyy · hh:mm a',
                            ).format(report.createdAt.toLocal()),
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _openReport(report),
                          style: TextButton.styleFrom(
                            foregroundColor: _blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('View Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _thumbnail(
    Report report, {
    required double width,
    required double height,
  }) {
    final imageUrl = report.imageUrl;
    final token = context.read<AuthProvider>().apiService.token;
    final headers = token == null ? null : {'Authorization': token};
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl?.isNotEmpty == true
            ? Image.network(
                imageUrl!,
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _thumbnailFallback(),
              )
            : _thumbnailFallback(),
      ),
    );
  }

  Widget _thumbnailFallback() {
    return const ColoredBox(
      color: Color(0xFFF1F4F8),
      child: Icon(Icons.image_outlined, color: Color(0xFF9AA5B4), size: 20),
    );
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase().replaceAll('_', ' ').trim()) {
      case 'resolved':
        return Icons.check_circle_outline_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _pill(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ],
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

  Widget _buildEmpty(String title, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: Color(0xFFAAB5C3), size: 45),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          if (_reports?.isEmpty ?? true) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _navigate('/citizen/submit'),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Submit New Report'),
              style: FilledButton.styleFrom(backgroundColor: _blue),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  final String label;

  const _TableHeading(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF60738F),
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      ),
    );
  }
}
