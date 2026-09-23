import 'dart:convert';
import '../config/api_config.dart';
import 'api_service.dart';

/// Wraps the admin-only POST /admin/officers endpoint.
/// The caller must already hold an authenticated admin session
/// (token set on the shared [ApiService] instance).
class AdminService {
  final ApiService _api;

  AdminService(this._api);

  /// Creates a new officer account.
  ///
  /// All five fields are required by the backend (OfficerCreate schema,
  /// extra="forbid"). Throws [Exception] with a human-readable message on
  /// any error (400 duplicate email, 403 not admin, 422 validation, etc.).
  ///
  /// Returns the created officer's [OfficerOut] data as a plain Map.
  Future<Map<String, dynamic>> createOfficer({
    required String name,
    required String email,
    required String password,
    required String jurisdiction,
    required String serviceDepartment,
  }) async {
    final response = await _api.post(
      ApiConfig.adminOfficers,
      body: {
        'name': name,
        'email': email,
        'password': password,
        'jurisdiction': jurisdiction,
        'service_department': serviceDepartment,
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return body as Map<String, dynamic>;
    }

    // Extract a user-facing error message from the backend response.
    String message = 'Failed to create officer';
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        // Pydantic 422 validation errors: [{"loc": [...], "msg": "...", ...}]
        final first = detail.first;
        if (first is Map<String, dynamic> && first['msg'] is String) {
          final loc = (first['loc'] as List?)?.skip(1).join(' → ') ?? '';
          final msg = first['msg'] as String;
          message = loc.isNotEmpty ? '$loc: $msg' : msg;
        }
      }
    }
    throw Exception(message);
  }
}
