import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../models/analytics.dart';
import '../../theme/app_theme.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  AnalyticsSummary? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<AuthProvider>().apiService;
      final data = await AnalyticsService(api).getAnalytics();
      setState(() { _analytics = data; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Admin Dashboard', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Welcome, ${auth.user?.fullName ?? "Admin"}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ]),
                GestureDetector(
                  onTap: () async {
                    await auth.logout();
                    if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 22)),
                ),
              ]),
              const SizedBox(height: 28),

              // Stats
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.primary)))
              else if (_analytics != null) ...[
                Row(children: [
                  Expanded(child: _StatCard(label: 'Total', value: '${_analytics!.totalReports}', icon: Icons.assessment_rounded, color: AppTheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Pending', value: '${_analytics!.pendingCount}', icon: Icons.schedule_rounded, color: AppTheme.pending)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Resolved', value: '${_analytics!.resolvedCount}', icon: Icons.check_circle_rounded, color: AppTheme.resolved)),
                ]),
              ],
              const SizedBox(height: 28),

              // Actions
              const Text('Management', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _buildAction(context, Icons.list_alt_rounded, 'All Reports', 'View and filter all civic reports', AppTheme.primaryGradient, '/admin/reports'),
              const SizedBox(height: 12),
              _buildAction(context, Icons.bar_chart_rounded, 'Analytics', 'Charts and statistics', AppTheme.accentGradient, '/admin/analytics'),
              const SizedBox(height: 12),
              _buildAction(context, Icons.person_add_rounded, 'Officer Management', 'Create and assign field officers', const LinearGradient(colors: [Color(0xFF2D6A4F), Color(0xFF40916C)], begin: Alignment.topLeft, end: Alignment.bottomRight), '/admin/officers'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext ctx, IconData icon, String title, String sub, LinearGradient g, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(ctx, route),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: g.colors.first.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)), Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13))])),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard,
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]),
    );
  }
}
