import 'package:cateredtoyou/models/notification_model.dart';
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });
    final notifications = await _notificationService.getNotifications();
    setState(() {
      _notifications = notifications
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _isLoading = false;
    });
  }

  Future<void> _deleteNotification(int id) async {
    await _notificationService.deleteNotification(id);
    _loadNotifications();
  }

  Future<void> _markAsRead(int id) async {
    await _notificationService.markAsRead(id);
    _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    _loadNotifications();
  }

  Future<void> _deleteAllNotificaitons() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications? This action cannot be undone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _notificationService.deleteAllNotifications();
                _loadNotifications();
              },
              child: const Text('DELETE')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread =
        _notifications.any((notification) => !notification.isRead);

    return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (hasUnread)
              IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
                onPressed: _markAllAsRead,
              ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Delete all',
              onPressed:
                  _notifications.isEmpty ? null : _deleteAllNotificaitons,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? const Center(child: Text('No Notifications'))
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final dateFormat = DateFormat('MMM d, yyyy - h:mm a');

                        return Dismissible(
                          key: Key('notification_${notification.id}'),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            _deleteNotification(notification.id);
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: notification.isRead
                                  ? Colors.grey.shade200
                                  : Theme.of(context).primaryColor,
                              child: Icon(
                                Icons.notifications,
                                color: notification.isRead
                                    ? Colors.grey
                                    : Colors.white,
                              ),
                            ),
                            title: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notification.body),
                                const SizedBox(height: 4),
                                Text(
                                  notification.scheduledTime != null
                                      ? 'Scheduled for: ${dateFormat.format(notification.scheduledTime!)}'
                                      : 'Received: ${dateFormat.format(notification.timestamp)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: !notification.isRead
                                ? IconButton(
                                    icon:
                                        const Icon(Icons.check_circle_outline),
                                    tooltip: 'Mark as read',
                                    onPressed: () =>
                                        _markAsRead(notification.id),
                                  )
                                : null,
                            onTap: () {
                              if (!notification.isRead) {
                                _markAsRead(notification.id);
                              }

                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(notification.title),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(notification.body),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Received: ${dateFormat.format(notification.timestamp)}',
                                          style: const TextStyle(
                                              fontSize: 14, color: Colors.grey),
                                        ),
                                        if (notification.scheduledTime != null)
                                          Text(
                                            'Scheduled for: ${dateFormat.format(notification.scheduledTime!)}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          )
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('CLOSE'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteNotification(notification.id);
                                      },
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
      );
  }
}
