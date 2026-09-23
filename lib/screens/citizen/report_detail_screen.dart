import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/ai_assessment_card.dart';

/// Full-detail view for a single Report, accessible from My Reports.
/// Preserves all existing information and adds the AI Assessment section.
class ReportDetailScreen extends StatelessWidget {
  final Report report;

  const ReportDetailScreen({super.key, required this.report});

  Map<String, String>? _imageHeaders(BuildContext context) {
    final token = context.read<AuthProvider>().apiService.token;
    return token == null ? null : {'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(report.issueNumber),
        backgroundColor: AppTheme.surface.withValues(alpha: 0.8),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image ────────────────────────────────────────────────────
              if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    report.imageUrl!,
                    headers: _imageHeaders(context),
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary)),
                      );
                    },
                    errorBuilder: (context, error, _) => Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: AppTheme.textMuted, size: 48)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Status + Header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.glassCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            report.issueNumber,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        StatusBadge(status: report.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MetaRow(
                      icon: Icons.calendar_today_rounded,
                      text: DateFormat('MMM dd, yyyy • hh:mm a')
                          .format(report.createdAt.toLocal()),
                    ),
                    if (report.areaZone != null &&
                        report.areaZone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _MetaRow(
                          icon: Icons.location_on_rounded,
                          text: report.areaZone!,
                          color: AppTheme.accent),
                    ],
                    if (report.jurisdiction != null) ...[
                      const SizedBox(height: 6),
                      _MetaRow(
                          icon: Icons.account_balance_rounded,
                          text: report.jurisdiction!),
                    ],
                    const SizedBox(height: 6),
                    _MetaRow(
                      icon: Icons.gps_fixed_rounded,
                      text:
                          '${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                    if (report.description != null &&
                        report.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0x14FFFFFF)),
                      const SizedBox(height: 12),
                      Text(
                        report.description!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Assignment ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCardLight,
                child: Row(
                  children: [
                    Icon(
                      report.assignmentStatus == 'assigned'
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      color: AppTheme.info,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        report.assignedOfficer?.name != null
                            ? 'Assigned to ${report.assignedOfficer!.name}'
                            : report.assignmentStatus == 'assigned'
                                ? 'Assigned'
                                : 'Unassigned — awaiting officer',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Detection chips (brief, above AI card) ───────────────────
              if (report.detections.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.glassCardLight,
                  child: const Row(
                    children: [
                      Icon(Icons.search_off_rounded,
                          color: AppTheme.textMuted, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'No issues detected by AI in this image',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── AI Assessment ────────────────────────────────────────────
              AiAssessmentCard(report: report),

              // ── Resolved date ────────────────────────────────────────────
              if (report.resolvedAt != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.resolved.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.resolved.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.resolved, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Resolved on ${DateFormat('MMM dd, yyyy').format(report.resolvedAt!.toLocal())}',
                        style: const TextStyle(
                          color: AppTheme.resolved,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final double fontSize;

  const _MetaRow({
    required this.icon,
    required this.text,
    this.color,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: c, fontSize: fontSize),
          ),
        ),
      ],
    );
  }
}
