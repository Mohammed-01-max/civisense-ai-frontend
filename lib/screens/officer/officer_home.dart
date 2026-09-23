import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/report_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/report_card.dart';

class OfficerHome extends StatefulWidget {
  const OfficerHome({super.key});

  @override
  State<OfficerHome> createState() => _OfficerHomeState();
}

class _OfficerHomeState extends State<OfficerHome> {
  List<Report>? _reports;
  String? _error;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadReports(),
      _loadUnreadCount(),
    ]);
  }

  Future<void> _loadReports() async {
    try {
      final reports = await ReportService(
        context.read<AuthProvider>().apiService,
      ).getAssignedOfficerReports();
      if (mounted) setState(() => _reports = reports);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final apiService = context.read<AuthProvider>().apiService;
      final service = NotificationService(apiService);
      final notifs = await service.getMyNotifications();
      if (mounted) {
        setState(() {
          _unreadCount = notifs.where((n) => !n.isRead).length;
        });
      }
    } catch (e) {
      // Ignore notification fetch failures on home screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Reports'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(_unreadCount.toString()),
              backgroundColor: AppTheme.error,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              await Navigator.pushNamed(context, '/notifications');
              _loadUnreadCount();
            },
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
            : _reports == null
                ? const Center(child: CircularProgressIndicator())
                : _reports!.isEmpty
                    ? const Center(child: Text('No assigned pending reports'))
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          itemCount: _reports!.length,
                          itemBuilder: (_, index) => ReportCard(report: _reports![index]),
                        ),
                      ),
      ),
    );
  }
}