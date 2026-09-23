import 'dart:convert';
import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _api;

  NotificationService(this._api);

  Future<List<AppNotification>> getMyNotifications() async {
    final response = await _api.get('/notifications/my');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load notifications (${response.statusCode})');
  }

  Future<AppNotification> markAsRead(int notificationId) async {
    final response = await _api.patch('/notifications/$notificationId/read');
    if (response.statusCode == 200) {
      return AppNotification.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception(
        'Failed to mark notification as read (${response.statusCode})');
  }
}
