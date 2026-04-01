import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/announcement.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.notifications);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _notifications = (result['data'] as List)
              .map((n) => AppNotification.fromJson(n))
              .toList();
          _unread = result['unread_count'] ?? 0;
        }
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.put(ApiConfig.notificationsReadAll, {});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notifications'),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Read all', style: TextStyle(color: SanskarTheme.saffron)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: TextStyle(color: SanskarTheme.darkCharcoal.withAlpha(120)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return _NotificationTile(
                        notification: n,
                        onTap: () async {
                          if (!n.isRead) {
                            await ApiService.put(ApiConfig.notificationRead(n.id), {});
                            _load();
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon {
    switch (notification.notificationType) {
      case 'event_reminder':
        return Icons.event;
      case 'announcement':
        return Icons.campaign;
      case 'media_shared':
        return Icons.photo_library;
      case 'rsvp_update':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? SanskarTheme.softWhite
              : SanskarTheme.saffron.withAlpha(10),
          borderRadius: SanskarTheme.radiusMd,
          border: notification.isRead
              ? null
              : Border.all(color: SanskarTheme.saffron.withAlpha(30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SanskarTheme.saffron.withAlpha(20),
                borderRadius: SanskarTheme.radiusSm,
              ),
              child: Icon(_icon, size: 18, color: SanskarTheme.saffron),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: SanskarTheme.darkCharcoal.withAlpha(150),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: SanskarTheme.saffron,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
