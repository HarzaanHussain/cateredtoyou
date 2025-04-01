import 'dart:convert';
import 'package:cateredtoyou/models/reccuring_notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class RecurringNotificationStorage {
  static const String _storageKey = 'recurring_notifications';
  static final Uuid _uuid = Uuid();
  
  // Get all recurring notifications
  static Future<List<RecurringNotification>> getRecurringNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString(_storageKey);
    
    if (storedData == null || storedData.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = json.decode(storedData);
      return jsonList
          .map((item) => RecurringNotification.fromJson(item))
          .toList();
    } catch (e) {
      print('Error loading recurring notifications: $e');
      return [];
    }
  }
  
  // Save all recurring notifications
  static Future<void> saveRecurringNotifications(
      List<RecurringNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = notifications.map((item) => item.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }
  
  // Add a new recurring notification
  static Future<RecurringNotification> addRecurringNotification(
      RecurringNotification notification) async {
    final notifications = await getRecurringNotifications();
    
    // Generate a unique ID if not provided
    final id = notification.id.isNotEmpty ? notification.id : _uuid.v4();
    final newNotification = RecurringNotification(
      id: id,
      title: notification.title,
      body: notification.body,
      screen: notification.screen,
      extraData: notification.extraData,
      interval: notification.interval,
      startDate: notification.startDate,
      endDate: notification.endDate,
      isActive: notification.isActive,
      createdAt: DateTime.now(),
      nextScheduledDate: notification.nextScheduledDate,
    );
    
    notifications.add(newNotification);
    await saveRecurringNotifications(notifications);
    
    return newNotification;
  }
  
  // Update an existing recurring notification
  static Future<void> updateRecurringNotification(
      RecurringNotification notification) async {
    final notifications = await getRecurringNotifications();
    final index = notifications.indexWhere((item) => item.id == notification.id);
    
    if (index >= 0) {
      notifications[index] = notification;
      await saveRecurringNotifications(notifications);
    }
  }
  
  // Delete a recurring notification
  static Future<void> deleteRecurringNotification(String id) async {
    final notifications = await getRecurringNotifications();
    notifications.removeWhere((item) => item.id == id);
    await saveRecurringNotifications(notifications);
  }
  
  // Update next scheduled date for a notification
  static Future<void> updateNextScheduledDate(
      String id, DateTime nextDate) async {
    final notifications = await getRecurringNotifications();
    final index = notifications.indexWhere((item) => item.id == id);
    
    if (index >= 0) {
      notifications[index] = notifications[index].copyWith(
        nextScheduledDate: nextDate,
      );
      await saveRecurringNotifications(notifications);
    }
  }
}