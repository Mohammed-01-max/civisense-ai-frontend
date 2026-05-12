import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/report.dart';
import '../../services/authority_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/issue_chip.dart';

class ResolveScreen extends StatefulWidget {
  const ResolveScreen({super.key});
  @override
  State<ResolveScreen> createState() => _ResolveScreenState();
}

class _ResolveScreenState extends State<ResolveScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Report? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final issueNumber = _controller.text.trim();
    if (issueNumber.isEmpty) {
      setState(() => _error = 'Please enter an issue number');
      return;
    }
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final api = context.read<AuthProvider>().apiService;
      final report = await AuthorityService(api).resolveIssue(issueNumber);
      setState(() { _result = report; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resolve Issue'), backgroundColor: AppTheme.surface.withValues(alpha: 0.8)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon header
            Center(child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.resolved.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, color: AppTheme.resolved, size: 56),
            )),
            const SizedBox(height: 24),
            const Center(child: Text('Resolve a Civic Issue', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            const Center(child: Text('Enter the issue number to mark as resolved', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center)),
            const SizedBox(height: 32),

            // Form
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCard,
              child: Column(children: [
                CustomTextField(
                  controller: _controller,
                  label: 'Issue Number',
                  hint: 'e.g., CIV-000042',
                  prefixIcon: Icons.confirmation_number_rounded,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Resolve Issue',
                  icon: Icons.check_rounded,
                  isLoading: _isLoading,
                  gradient: const LinearGradient(colors: [Color(0xFF51CF66), Color(0xFF2F9E44)]),
                  onPressed: _resolve,
                ),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error.withValues(alpha: 0.3))),
                child: Row(children: [const Icon(Icons.error_outline, color: AppTheme.error, size: 20), const SizedBox(width: 10), Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 14)))]),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.resolved.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.resolved.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(Icons.check_circle, color: AppTheme.resolved), const SizedBox(width: 10), const Text('Issue Resolved!', style: TextStyle(color: AppTheme.resolved, fontSize: 18, fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_result!.issueNumber, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)), StatusBadge(status: _result!.status)]),
                  if (_result!.areaZone != null) ...[const SizedBox(height: 10), Row(children: [const Icon(Icons.location_on, color: AppTheme.accent, size: 16), const SizedBox(width: 6), Text(_result!.areaZone!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))])],
                  if (_result!.detections.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: _result!.detections.map((d) => IssueChip(issueType: d.issueType)).toList())],
                ]),
              ),
              const SizedBox(height: 20),
              GradientButton(text: 'Resolve Another', icon: Icons.refresh_rounded, onPressed: () => setState(() { _result = null; _controller.clear(); })),
            ],
          ]),
        ),
      ),
    );
  }
}
