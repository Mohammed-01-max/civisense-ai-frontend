class ApiConfig {
  // For web browsers connecting to localhost backend
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // Report endpoints
  static const String submitReport = '/reports/';
  static const String myReports = '/reports/my';
  static const String allReports = '/reports/all';
  static const String modelsInfo = '/reports/models';

  // Analytics
  static const String analytics = '/analytics/';

  // Authority
  static const String resolveIssue = '/authority/resolve';
}
