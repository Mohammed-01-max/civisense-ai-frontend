import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class CitizenHome extends StatelessWidget {
  const CitizenHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, user?.fullName ?? 'Citizen', auth),
                const SizedBox(height: 36),
                const Text('Quick Actions', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _buildActionCard(context, Icons.camera_alt_rounded, 'Report an Issue', 'Take a photo to detect civic problems', AppTheme.primaryGradient, '/citizen/submit'),
                const SizedBox(height: 16),
                _buildActionCard(context, Icons.list_alt_rounded, 'My Reports', 'View your submitted issue reports', AppTheme.accentGradient, '/citizen/reports'),
                const SizedBox(height: 36),
                const Text('How It Works', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _buildStep(Icons.photo_camera_rounded, 'Capture', 'Take a photo of the civic issue', AppTheme.primary),
                _buildStep(Icons.auto_awesome_rounded, 'AI Detection', 'Our AI identifies the type of issue', AppTheme.accent),
                _buildStep(Icons.location_on_rounded, 'Auto Report', 'Report is filed with GPS location', AppTheme.warning),
                _buildStep(Icons.check_circle_rounded, 'Resolution', 'Authorities resolve the issue', AppTheme.resolved),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, AuthProvider auth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, $name 👋', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Report civic issues in your area', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ]),
        ),
        GestureDetector(
          onTap: () => _showLogoutSheet(context, auth),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 24),
          ),
        ),
      ],
    );
  }

  void _showLogoutSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardLight,
            child: Row(children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(auth.user?.fullName ?? 'User', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                Text(auth.user?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
            title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () async {
              await auth.logout();
              if (ctx.mounted) Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (r) => false);
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, String subtitle, LinearGradient gradient, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 28)),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
        ]),
      ),
    );
  }

  Widget _buildStep(IconData icon, String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCardLight,
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ])),
        ]),
      ),
    );
  }
}
