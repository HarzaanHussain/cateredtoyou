import 'dart:convert';

import 'package:cateredtoyou/models/notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationStorage {
  static const String _storageKey = 'app_notifications';

  // Saves notifications to local storage
  static Future<void> saveNotifications(
      List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final String notificationsJson = jsonEncode(
      notifications
          .map((notifications) => notifications.storeAsJson())
          .toList(),
    );
    await prefs.setString(_storageKey, notificationsJson);
  }

  // Gets all notifications from local storage
  static Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString(_storageKey);

    if (notificationsJson == null) {
      return [];
    }

    final List<dynamic> decodedJson = jsonDecode(notificationsJson);
    return decodedJson
        .map((item) => AppNotification.createFromJson(item))
        .toList();
  }

  // Add a new notifications to storage function
  static Future<void> addNotification(AppNotification notification) async {
    final notifications = await getNotifications();
    notifications.add(notification);
    await saveNotifications(notifications);
  }

  // Deletes a notification by its ID
  static Future<void> deleteNotification(int id) async {
    final notifications = await getNotifications();
    notifications.removeWhere((notifications) => notifications.id == id);
    await saveNotifications(notifications);
  }

  // Marks a notification as read
  static Future<void> markAsRead(int id) async {
    final notifications = await getNotifications();
    final index =
        notifications.indexWhere((notifications) => notifications.id == id);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      await saveNotifications(notifications);
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    final notifications = await getNotifications();
    final updateNotifications = notifications
        .map((notifications) => notifications.copyWith(isRead: true))
        .toList();
    await saveNotifications(updateNotifications);
  }

  // Deletes all notifications
  static Future<void> deleteAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
