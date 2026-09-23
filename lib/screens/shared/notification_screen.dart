import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification>? _notifications;
  String? _error;
  late NotificationService _service;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _service = NotificationService(auth.apiService);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifs = await _service.getMyNotifications();
      if (mounted) setState(() => _notifications = notifs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _markAsRead(AppNotification notification, int index) async {
    if (notification.isRead) return;
    try {
      final updated = await _service.markAsRead(notification.id);
      if (mounted) {
        setState(() {
          _notifications![index] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(_error!, style: const TextStyle(color: AppTheme.error), textAlign: TextAlign.center),
        ),
      );
    }
    if (_notifications == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notifications!.isEmpty) {
      return const Center(
        child: Text('No notifications yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications!.length,
        itemBuilder: (context, index) {
          final n = _notifications![index];
          final isResolved = n.type == 'REPORT_RESOLVED';
          return Card(
            elevation: n.isRead ? 0 : 2,
            color: n.isRead ? AppTheme.surface : AppTheme.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: n.isRead ? Colors.transparent : AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                isResolved ? Icons.check_circle_rounded : Icons.assignment_ind_rounded,
                color: n.isRead ? AppTheme.textMuted : (isResolved ? AppTheme.resolved : AppTheme.primary),
                size: 32,
              ),
              title: Text(
                n.title,
                style: TextStyle(
                  fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.body, style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(n.createdAt.toLocal()),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              onTap: () => _markAsRead(n, index),
            ),
          );
        },
      ),
    );
  }
}
