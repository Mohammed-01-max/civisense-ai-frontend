import 'dart:convert';
import '../config/api_config.dart';
import '../models/report.dart';
import 'api_service.dart';

class AuthorityService {
  final ApiService _api;

  AuthorityService(this._api);

  /// Resolve an issue by its issue number (e.g. CIV-000042).
  /// Authority-only endpoint. PATCH /authority/resolve with JSON body.
  Future<Report> resolveIssue(String issueNumber) async {
    final response = await _api.patch(ApiConfig.resolveIssue, body: {
      'issue_number': issueNumber,
    });

    if (response.statusCode == 200) {
      return Report.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to resolve issue');
    }
  }
}
