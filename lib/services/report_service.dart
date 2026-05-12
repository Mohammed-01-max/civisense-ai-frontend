import 'dart:convert';
import 'dart:typed_data';
import '../config/api_config.dart';
import '../models/report.dart';
import 'api_service.dart';

class ReportService {
  final ApiService _api;

  ReportService(this._api);

  /// Submit a new report with image file, GPS coordinates, and optional description.
  /// The backend expects multipart/form-data with fields: file, lat, lon, description.
  Future<Report> submitReport({
    required Uint8List fileBytes,
    required String fileName,
    required double latitude,
    required double longitude,
    String description = '',
  }) async {
    final response = await _api.postMultipart(
      ApiConfig.submitReport,
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'description': description,
      },
    );

    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 201) {
      return Report.fromJson(jsonDecode(responseBody));
    } else {
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to submit report');
    }
  }

  /// Get the current citizen's own reports.
  Future<List<Report>> getMyReports() async {
    final response = await _api.get(ApiConfig.myReports);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((r) => Report.fromJson(r)).toList();
    } else {
      throw Exception('Failed to fetch reports');
    }
  }

  /// Get all reports (admin only). Optional status filter: 'pending' or 'resolved'.
  Future<List<Report>> getAllReports({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _api.get(ApiConfig.allReports, queryParams: queryParams.isNotEmpty ? queryParams : null);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((r) => Report.fromJson(r)).toList();
    } else {
      throw Exception('Failed to fetch reports');
    }
  }
}
