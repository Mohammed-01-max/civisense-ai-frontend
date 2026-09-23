import 'package:flutter/material.dart';
import '../models/report.dart';
import '../theme/app_theme.dart';
import 'issue_chip.dart';

/// Displays all available AI analysis results for a Report.
///
/// Every section is conditional — if the relevant field(s) are null or empty,
/// that section is simply not rendered. No fabricated values are shown.
class AiAssessmentCard extends StatelessWidget {
  final Report report;

  const AiAssessmentCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    // Only render the card at all if there is at least one AI field to show.
    final hasDetections = report.detections.isNotEmpty;
    final hasClassification =
        report.triageCategory != null || report.triageConfidence != null;
    final hasSeverity =
        report.severity != null || report.severityConfidence != null;
    final hasPriority = report.priorityAdvisory != null;
    final hasDepartment = report.serviceDepartment != null;
    final hasSimilar = report.similarReports.isNotEmpty;

    if (!hasDetections &&
        !hasClassification &&
        !hasSeverity &&
        !hasPriority &&
        !hasDepartment &&
        !hasSimilar) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI Assessment',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(
              height: 1, color: Color(0x14FFFFFF), indent: 18, endIndent: 18),
          const SizedBox(height: 14),

          // ── Detections ──────────────────────────────────────────────────
          if (hasDetections) ...[
            _SectionLabel(
                icon: Icons.search_rounded, label: 'Detected Issues'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: report.detections
                    .map((d) => IssueChip(issueType: d.issueType))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Classification ───────────────────────────────────────────────
          if (hasClassification) ...[
            _SectionLabel(
                icon: Icons.category_rounded, label: 'Classification'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _InfoRow(
                label: 'Category',
                value: report.triageCategory != null
                    ? _formatLabel(report.triageCategory!)
                    : null,
                trailing: report.triageConfidence != null
                    ? _ConfidencePill(value: report.triageConfidence!)
                    : null,
              ),
            ),
            if (report.triageSource != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _InfoRow(
                  label: 'Model',
                  value: report.triageSource,
                  valueStyle: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // ── Severity ────────────────────────────────────────────────────
          if (hasSeverity) ...[
            _SectionLabel(
                icon: Icons.warning_amber_rounded, label: 'Severity'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _InfoRow(
                label: 'Level',
                value: report.severity != null
                    ? _formatLabel(report.severity!)
                    : null,
                valueColor: report.severity != null
                    ? _severityColor(report.severity!)
                    : null,
                trailing: report.severityConfidence != null
                    ? _ConfidencePill(value: report.severityConfidence!)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Priority ────────────────────────────────────────────────────
          if (hasPriority) ...[
            _SectionLabel(
                icon: Icons.flag_rounded, label: 'Priority Advisory'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Priority',
                    value: _formatLabel(report.priorityAdvisory!.level),
                    valueColor:
                        _priorityColor(report.priorityAdvisory!.level),
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    label: 'Reason',
                    value: _formatReasonCode(
                        report.priorityAdvisory!.reasonCode),
                  ),
                  const SizedBox(height: 10),
                  _FactorsRow(factors: report.priorityAdvisory!.factors),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Department ──────────────────────────────────────────────────
          if (hasDepartment) ...[
            _SectionLabel(
                icon: Icons.business_rounded, label: 'Routed To'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _InfoRow(
                label: 'Department',
                value: report.serviceDepartment,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Similar Reports ─────────────────────────────────────────────
          if (hasSimilar) ...[
            _SectionLabel(
                icon: Icons.content_copy_rounded,
                label: 'Possible Related Reports'),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'These may refer to the same issue. Not confirmed duplicates.',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            ...report.similarReports.map(
              (s) => Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: _SimilarReportRow(candidate: s),
              ),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : w)
        .join(' ');
  }

  String _formatReasonCode(String code) {
    // Convert reason codes like PRI_HIGH_SEV_EVID into readable text.
    final map = <String, String>{
      'PRI_HIGH_SEV_EVID': 'High severity with visual evidence',
      'PRI_HIGH_SEV_NO_EVID': 'High severity (no direct evidence)',
      'PRI_MED_SEV_EVID': 'Medium severity with visual evidence',
      'PRI_MED_SEV_NO_EVID': 'Medium severity (no direct evidence)',
      'PRI_LOW_SEV': 'Low severity',
      'PRI_REC_EVID': 'Recurring issue with evidence',
      'PRI_REC_NO_EVID': 'Recurring issue',
    };
    return map[code] ?? _formatLabel(code);
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return AppTheme.error;
      case 'MEDIUM':
        return AppTheme.warning;
      case 'LOW':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _priorityColor(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return AppTheme.error;
      case 'MEDIUM':
        return AppTheme.warning;
      case 'LOW':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }
}

// ── Internal sub-widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 14),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;
  final TextStyle? valueStyle;
  final Widget? trailing;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueColor,
    this.valueStyle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null && trailing == null) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (value != null)
          Expanded(
            child: Text(
              value!,
              style: valueStyle ??
                  TextStyle(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  final double value; // 0.0–1.0

  const _ConfidencePill({required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toStringAsFixed(1);
    final color = value >= 0.8
        ? AppTheme.success
        : value >= 0.5
            ? AppTheme.warning
            : AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FactorsRow extends StatelessWidget {
  final PriorityFactors factors;
  const _FactorsRow({required this.factors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contributing Factors',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _FactorItem(
              label: 'Severity',
              value: _fmt(factors.severity)),
          _FactorItem(
              label: 'Visual evidence',
              value: _fmtEvidence(factors.yoloEvidenceState)),
          _FactorItem(
              label: 'Recurrence',
              value: _fmtBool(factors.possibleRecurrence)),
        ],
      ),
    );
  }

  String _fmt(String raw) {
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  String _fmtEvidence(String raw) {
    switch (raw.toUpperCase()) {
      case 'TRUE':
        return 'Detected in image';
      case 'FALSE':
        return 'Not detected';
      case 'UNKNOWN':
        return 'Unknown';
      default:
        return _fmt(raw);
    }
  }

  String _fmtBool(String raw) {
    switch (raw.toUpperCase()) {
      case 'TRUE':
        return 'Likely recurring';
      case 'FALSE':
        return 'No recurrence pattern';
      case 'UNKNOWN':
        return 'Unknown';
      default:
        return _fmt(raw);
    }
  }
}

class _FactorItem extends StatelessWidget {
  final String label;
  final String value;
  const _FactorItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarReportRow extends StatelessWidget {
  final DuplicateCandidate candidate;
  const _SimilarReportRow({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final pct = (candidate.similarityScore * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: AppTheme.textMuted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              candidate.issueNumber,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
            ),
            child: Text(
              '$pct% similar',
              style: const TextStyle(
                color: AppTheme.info,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
