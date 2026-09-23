// Models matching backend schemas.py ReportOut and related types.
// Backend source: backend/schemas.py (ReportOut, PriorityAdvisory, PriorityFactors, DuplicateCandidate)
//
// All AI fields are nullable — older reports may not have them.

class Detection {
  final int id;
  final String issueType;

  Detection({
    required this.id,
    required this.issueType,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      id: json['id'],
      issueType: json['issue_type'],
    );
  }
}

class AssignedOfficer {
  final int id;
  final String? name;
  final String? jurisdiction;
  final String? serviceDepartment;

  AssignedOfficer({
    required this.id,
    this.name,
    this.jurisdiction,
    this.serviceDepartment,
  });

  factory AssignedOfficer.fromJson(Map<String, dynamic> json) {
    return AssignedOfficer(
      id: json['id'],
      name: json['name'],
      jurisdiction: json['jurisdiction'],
      serviceDepartment: json['service_department'],
    );
  }
}

/// Mirrors backend PriorityFactors (schemas.py)
class PriorityFactors {
  final String severity;
  final String yoloEvidenceState;
  final String possibleRecurrence;

  PriorityFactors({
    required this.severity,
    required this.yoloEvidenceState,
    required this.possibleRecurrence,
  });

  factory PriorityFactors.fromJson(Map<String, dynamic> json) {
    return PriorityFactors(
      severity: json['severity'] as String,
      yoloEvidenceState: json['yolo_evidence_state'] as String,
      possibleRecurrence: json['possible_recurrence'] as String,
    );
  }
}

/// Mirrors backend PriorityAdvisory (schemas.py)
class PriorityAdvisory {
  final String level;
  final String reasonCode;
  final String policyVersion;
  final PriorityFactors factors;

  PriorityAdvisory({
    required this.level,
    required this.reasonCode,
    required this.policyVersion,
    required this.factors,
  });

  factory PriorityAdvisory.fromJson(Map<String, dynamic> json) {
    return PriorityAdvisory(
      level: json['level'] as String,
      reasonCode: json['reason_code'] as String,
      policyVersion: json['policy_version'] as String,
      factors: PriorityFactors.fromJson(
          json['factors'] as Map<String, dynamic>),
    );
  }
}

/// Mirrors backend DuplicateCandidate (schemas.py)
class DuplicateCandidate {
  final String issueNumber;
  final double similarityScore;

  DuplicateCandidate({
    required this.issueNumber,
    required this.similarityScore,
  });

  factory DuplicateCandidate.fromJson(Map<String, dynamic> json) {
    return DuplicateCandidate(
      issueNumber: json['issue_number'] as String,
      similarityScore: (json['similarity_score'] as num).toDouble(),
    );
  }
}

/// Mirrors backend ReportOut (schemas.py)
class Report {
  // ── Core fields ────────────────────────────────────────────────────────────
  final int id;
  final String issueNumber;
  final double latitude;
  final double longitude;
  final String? areaZone;
  final String? jurisdiction;
  final String? serviceDepartment;
  final String? routingPolicyVersion;
  final int? assignedOfficerId;
  final AssignedOfficer? assignedOfficer;
  final String assignmentStatus;
  final String? imageUrl;
  final String? description;
  final String status;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final List<Detection> detections;

  // ── AI / triage fields ─────────────────────────────────────────────────────
  /// Complaint triage category (NLP). Null for older reports.
  final String? triageCategory;

  /// Triage model confidence [0–1]. Null for older reports.
  final double? triageConfidence;

  /// Triage source identifier (e.g. model name/version). Null for older reports.
  final String? triageSource;

  // ── Severity prediction fields (XGBoost-TF-IDF) ───────────────────────────
  /// Predicted severity label. Null for older reports.
  final String? severity;

  /// Severity model confidence [0–1]. Null for older reports.
  final double? severityConfidence;

  /// Severity source identifier. Null for older reports.
  final String? severitySource;

  // ── Priority advisory ──────────────────────────────────────────────────────
  /// Full priority advisory object. Null for older reports.
  final PriorityAdvisory? priorityAdvisory;

  // ── Duplicate detection ────────────────────────────────────────────────────
  /// List of similar existing reports. Empty list for older reports.
  final List<DuplicateCandidate> similarReports;

  Report({
    required this.id,
    required this.issueNumber,
    required this.latitude,
    required this.longitude,
    this.areaZone,
    this.jurisdiction,
    this.serviceDepartment,
    this.routingPolicyVersion,
    this.assignedOfficerId,
    this.assignedOfficer,
    required this.assignmentStatus,
    this.imageUrl,
    this.description,
    required this.status,
    this.resolvedAt,
    required this.createdAt,
    required this.detections,
    // AI fields
    this.triageCategory,
    this.triageConfidence,
    this.triageSource,
    this.severity,
    this.severityConfidence,
    this.severitySource,
    this.priorityAdvisory,
    required this.similarReports,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      issueNumber: json['issue_number'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      areaZone: json['area_zone'],
      jurisdiction: json['jurisdiction'],
      serviceDepartment: json['service_department'],
      routingPolicyVersion: json['routing_policy_version'],
      assignedOfficerId: json['assigned_officer_id'],
      assignedOfficer: json['assigned_officer'] != null
          ? AssignedOfficer.fromJson(
              json['assigned_officer'] as Map<String, dynamic>)
          : null,
      assignmentStatus: json['assignment_status'] ?? 'unassigned',
      description: json['description'],
      status: json['status'],
      imageUrl: json['image_url'],
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      detections: (json['detections'] as List)
          .map((d) => Detection.fromJson(d as Map<String, dynamic>))
          .toList(),

      // ── AI fields — all nullable for backward compatibility ────────────────
      triageCategory: json['triage_category'] as String?,
      triageConfidence: json['triage_confidence'] != null
          ? (json['triage_confidence'] as num).toDouble()
          : null,
      triageSource: json['triage_source'] as String?,

      severity: json['severity'] as String?,
      severityConfidence: json['severity_confidence'] != null
          ? (json['severity_confidence'] as num).toDouble()
          : null,
      severitySource: json['severity_source'] as String?,

      priorityAdvisory: json['priority_advisory'] != null
          ? PriorityAdvisory.fromJson(
              json['priority_advisory'] as Map<String, dynamic>)
          : null,

      similarReports: json['similar_reports'] != null
          ? (json['similar_reports'] as List)
              .map((s) =>
                  DuplicateCandidate.fromJson(s as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
}
