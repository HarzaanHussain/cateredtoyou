import 'dart:convert';
import 'package:cateredtoyou/models/notification_model.dart';
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';

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

  // Handle tapping on a notification in the list
  void _handleNotificationTap(AppNotification notification) {
    // Mark as read if not already read
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Navigate if there's a payload
    if (notification.payload != null && notification.payload!.isNotEmpty) {
      try {
        // Instead of parsing the payload ourselves and only navigating to base screens,
        // use the NotificationService which has logic for enhanced routes with IDs
        _notificationService.handleNotificationPayload(
            notification.payload!, context);
        return; // Exit early since we're navigating away
      } catch (e) {
        print('Error handling notification payload: $e');

        // Fallback to original logic if the notification service fails
        try {
          Map<String, dynamic> payloadData;

          // Try to parse as JSON first
          try {
            payloadData = json.decode(notification.payload!);
          } catch (_) {
            // Fall back to semicolon format
            payloadData = {};
            final pairs = notification.payload!.split(';');
            for (final pair in pairs) {
              final parts = pair.split(':');
              if (parts.length == 2) {
                payloadData[parts[0].trim()] = parts[1].trim();
              }
            }
          }

          // If there's a screen, proceed with navigation
          if (payloadData.containsKey('screen')) {
            final String screenName = payloadData['screen'].toString();
            final String route = _getRouteFromScreen(screenName);

            if (route.isNotEmpty) {
              print('Navigating to: $route from notification tap');
              GoRouter.of(context).go(route);
              return; // Exit early since we're navigating away
            }
          }
        } catch (e) {
          print('Error parsing notification payload: $e');
        }
      }
    }

    // If no navigation happens, show the details dialog
    _showNotificationDetails(notification);
  }

  void _showNotificationDetails(AppNotification notification) {
    final dateFormat = DateFormat('MMM d, yyyy - h:mm a');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification.body),
              const SizedBox(height: 16),
              Text(
                'Received: ${dateFormat.format(notification.timestamp)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (notification.scheduledTime != null)
                Text(
                  'Scheduled for: ${dateFormat.format(notification.scheduledTime!)}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
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
  }

  // Convert screen name to route
  String _getRouteFromScreen(String screen) {
    switch (screen) {
      case 'home':
        return '/home';
      case 'events':
        return '/events';
      case 'staff':
        return '/staff';
      case 'inventory':
        return '/inventory';
      case 'menu-items':
        return '/menu-items';
      case 'customers':
        return '/customers';
      case 'vehicles':
        return '/vehicles';
      case 'deliveries':
        return '/deliveries';
      case 'calendar':
        return '/calendar';
      case 'tasks':
        return '/tasks';
      case 'notifications':
        return '/notifications';
      default:
        return '';
    }
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
      bottomNavigationBar: const BottomToolbar(),
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
            onPressed: _notifications.isEmpty ? null : _deleteAllNotificaitons,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Notification',
            onPressed: () => context.push('/recurring-notifications'),
          )
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
                      final hasNavigationData = notification.payload != null &&
                          notification.payload!.isNotEmpty;

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
                              hasNavigationData
                                  ? Icons.open_in_new
                                  : Icons.notifications,
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
                              if (hasNavigationData)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Tap to navigate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).primaryColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: !notification.isRead
                              ? IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: 'Mark as read',
                                  onPressed: () => _markAsRead(notification.id),
                                )
                              : null,
                          onTap: () => _handleNotificationTap(notification),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
