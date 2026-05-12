import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/report_card.dart';

class AllReportsScreen extends StatefulWidget {
  const AllReportsScreen({super.key});
  @override
  State<AllReportsScreen> createState() => _AllReportsScreenState();
}

class _AllReportsScreenState extends State<AllReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Report>? _reports;
  bool _isLoading = true;
  String? _error;
  String? _currentFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final filters = [null, 'pending', 'resolved'];
        _loadReports(status: filters[_tabController.index]);
      }
    });
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports({String? status}) async {
    _currentFilter = status;
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = context.read<AuthProvider>().apiService;
      final reports = await ReportService(api).getAllReports(status: status);
      setState(() { _reports = reports; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reports'),
        backgroundColor: AppTheme.surface.withValues(alpha: 0.8),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [Tab(text: 'All'), Tab(text: 'Pending'), Tab(text: 'Resolved')],
        ),
      ),
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
                    ElevatedButton(onPressed: () => _loadReports(status: _currentFilter), child: const Text('Retry')),
                  ]))
                : _reports == null || _reports!.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_rounded, color: AppTheme.textMuted, size: 64),
                        const SizedBox(height: 16),
                        const Text('No reports found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: () => _loadReports(status: _currentFilter),
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
