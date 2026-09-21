class User {
  final int id;
  final String email;
  final String? fullName;
  final String? jurisdiction;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.fullName,
    this.jurisdiction,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      jurisdiction: json['jurisdiction'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'jurisdiction': jurisdiction,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
