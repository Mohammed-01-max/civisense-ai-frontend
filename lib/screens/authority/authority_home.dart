import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class AuthorityHome extends StatelessWidget {
  const AuthorityHome({super.key});

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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Authority Panel', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Welcome, ${auth.user?.fullName ?? "Authority"}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ]),
                GestureDetector(
                  onTap: () async {
                    await auth.logout();
                    if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 22)),
                ),
              ]),
              const SizedBox(height: 40),

              // Resolve action
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/authority/resolve'),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFFF5722)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF5722).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32)),
                    const SizedBox(width: 20),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Resolve Issue', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Mark a civic issue as resolved', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                    ])),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 40),

              // Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.glassCard,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 22), const SizedBox(width: 10), const Text('How to Resolve', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600))]),
                  const SizedBox(height: 16),
                  _infoStep('1', 'Get the issue number (e.g., CIV-000042)'),
                  _infoStep('2', 'Enter the issue number in the resolve form'),
                  _infoStep('3', 'Confirm to mark the issue as resolved'),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(num, style: const TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
      ]),
    );
  }
}
