import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/report_card.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});
  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<Report>? _reports;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = context.read<AuthProvider>().apiService;
      final service = ReportService(api);
      final reports = await service.getMyReports();
      setState(() { _reports = reports; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports'), backgroundColor: AppTheme.surface.withValues(alpha: 0.8)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadReports, child: const Text('Retry')),
                  ]))
                : _reports == null || _reports!.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_rounded, color: AppTheme.textMuted, size: 64),
                        const SizedBox(height: 16),
                        const Text('No reports yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('Submit your first civic issue report', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _reports!.length,
                          itemBuilder: (ctx, i) => ReportCard(report: _reports![i]),
                        ),
                      ),
      ),
    );
  }
}
