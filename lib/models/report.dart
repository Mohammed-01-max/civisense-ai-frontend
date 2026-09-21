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

class Report {
  final int id;
  final String issueNumber;
  final double latitude;
  final double longitude;
  final String? areaZone;
  final String? jurisdiction;
  final String? serviceDepartment;
  final int? assignedOfficerId;
  final AssignedOfficer? assignedOfficer;
  final String assignmentStatus;
  final String? imageUrl;
  final String? description;
  final String status;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final List<Detection> detections;

  Report({
    required this.id,
    required this.issueNumber,
    required this.latitude,
    required this.longitude,
    this.areaZone,
    this.jurisdiction,
    this.serviceDepartment,
    this.assignedOfficerId,
    this.assignedOfficer,
    required this.assignmentStatus,
    this.imageUrl,
    this.description,
    required this.status,
    this.resolvedAt,
    required this.createdAt,
    required this.detections,
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
        assignedOfficerId: json['assigned_officer_id'],
        assignedOfficer: json['assigned_officer'] != null
          ? AssignedOfficer.fromJson(json['assigned_officer'])
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
          .map((d) => Detection.fromJson(d))
          .toList(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
}
