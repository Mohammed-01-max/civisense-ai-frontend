import 'dart:convert';
import '../config/api_config.dart';
import '../models/analytics.dart';
import 'api_service.dart';

class AnalyticsService {
  final ApiService _api;

  AnalyticsService(this._api);

  /// Get analytics summary (admin only).
  Future<AnalyticsSummary> getAnalytics() async {
    final response = await _api.get(ApiConfig.analytics);

    if (response.statusCode == 200) {
      return AnalyticsSummary.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch analytics');
    }
  }
}
