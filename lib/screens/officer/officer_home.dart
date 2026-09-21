import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/report_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadReports();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Reports'),
        actions: [
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
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _reports!.length,
                          itemBuilder: (_, index) => ReportCard(report: _reports![index]),
                        ),
                      ),
      ),
    );
  }
}