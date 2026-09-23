import 'package:flutter/foundation.dart';

class ApiConfig {
  // Set at build time, for example:
  // flutter run --dart-define=API_BASE_URL=https://api.example.invalid
  // Production builds must provide this value; no production host is embedded.
  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    // Development-only defaults preserve the current local workflow. Physical
    // devices must receive a reachable host through API_BASE_URL.
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // Report endpoints
  static const String submitReport = '/reports/';
  static const String myReports = '/reports/my';
  static const String allReports = '/reports/all';
  static const String officerReports = '/officer/reports';
  static const String modelsInfo = '/reports/models';
  static const String adminOfficers = '/admin/officers';

  // Analytics
  static const String analytics = '/analytics/';

  // Authority
  static const String resolveIssue = '/authority/resolve';
}
