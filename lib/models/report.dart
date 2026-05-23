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

class Report {
  final int id;
  final String issueNumber;
  final double latitude;
  final double longitude;
  final String? areaZone;
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
