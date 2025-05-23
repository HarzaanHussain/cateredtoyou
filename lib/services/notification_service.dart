import 'dart:convert';

import 'package:cateredtoyou/models/notification_model.dart';
import 'package:cateredtoyou/models/reccuring_notification_model.dart';
import 'package:cateredtoyou/utils/notification_storage.dart';
import 'package:cateredtoyou/utils/recurring_notification_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;

//Defining a global key.....not sure if its useful in this context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Generating unique IDs for notifications
  int _nextId = 0;
  Future<int> _getNextId() async {
    final notifications = await NotificationStorage.getNotifications();
    if (notifications.isNotEmpty) {
      // Get maximum id number present and add 1
      _nextId =
          notifications.map((n) => n.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    return _nextId++;
  }

  //INITIALIZATION
  Future<void> initNotification() async {
    if (_isInitialized) return;

    //initialize the timezone
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? permissionGranted =
        await androidPlugin?.requestNotificationsPermission();
    print('Android notification permission granted: $permissionGranted');

    //android settings
    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );

    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    print("Notifications Initialized");
  }

  // notification response handler when tapped
  void _onNotificationTapped(NotificationResponse response) {
    print("Notification tapped: ${response.id}, payload: ${response.payload}");

    // Makes sure this is a valid payload
    if (response.payload == null || response.payload!.isEmpty) {
      print('Empty payload, cannot navigate');
      return;
    }

    // waits a bit for the app to be ready to navigate
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          handleNotificationPayload(response.payload!, context);
        } catch (e) {
          print('No valid context available for navigation');
        }
      }
    });
  }

  void handleNotificationPayload(String payload, BuildContext context) {
    try {
      // Parse the payload
      final Map<String, dynamic> payloadData = _parsePayload(payload);
      print('Parsed payload: $payloadData');

      if (payloadData.containsKey('screen')) {
        final String screen = payloadData['screen'].toString();
        print('Attempting to navigate to: $screen');

        // Get enhanced route that includes any ID parameters
        final String route = _enhanceRouteWithParams(screen, payloadData);

        if (route.isNotEmpty) {
          // Navigate using the context
          print('Navigating to route: $route');
          GoRouter.of(context).go(route);
        } else {
          print('Unknown screen in payload: $screen');
        }
      } else {
        print('Payload does not contain screen information');
      }
    } catch (e) {
      print('Error handling notification payload: $e');
    }
  }

  // helper method to get the route from screen name
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

  // improved payload parsing that handles both formats
  Map<String, dynamic> _parsePayload(String payload) {
    // first try to parse as json
    try {
      return json.decode(payload);
    } catch (_) {
      // if that fails, try to parse as semicolon-delimited string
      final Map<String, dynamic> result = {};
      final pairs = payload.split(';');

      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          result[keyValue[0].trim()] = keyValue[1].trim();
        }
      }
      return result;
    }
  }

  String _enhanceRouteWithParams(
      String screen, Map<String, dynamic> payloadData) {
    // Start with the base route
    switch (screen) {
      case 'events':
        if (payloadData.containsKey('eventId')) {
          return '/events/${payloadData['eventId']}';
        }
        break;

      case 'inventory':
        if (payloadData.containsKey('itemId')) {
          return '/inventory/${payloadData['itemId']}';
        }
        break;

      case 'tasks':
        if (payloadData.containsKey('taskId')) {
          return '/tasks/${payloadData['taskId']}';
        }
        break;

      case 'vehicles':
        if (payloadData.containsKey('vehicleId')) {
          return '/vehicles/${payloadData['vehicleId']}';
        }
        break;

      case 'staff':
        if (payloadData.containsKey('staffId')) {
          return '/staff/${payloadData['staffId']}';
        }
        break;
    }

    // If no specific ID found, return the base route
    return _getRouteFromScreen(screen);
  }

  //NOTIFICATION DETAILS
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
        android: AndroidNotificationDetails(
      'catered_to_you',
      'Catered To You',
      channelDescription: 'Catered To You Notification',
      importance: Importance.max,
      priority: Priority.high,
    ));
  }

  Future<void> processRecurringNotifications() async {
    if (!_isInitialized) await initNotification();
  
    try {
      final now = DateTime.now();
      final notifications = await RecurringNotificationStorage.getRecurringNotifications();
    
      for (final notification in notifications) {
        // Skip inactive notifications
        if (!notification.isActive) continue;
      
        // Skip if end date has passed
        if (notification.endDate != null && notification.endDate!.isBefore(now)) {
          // Deactivate this notification since end date has passed
          await RecurringNotificationStorage.updateRecurringNotification(
            notification.copyWith(isActive: false)
          );
          continue;
        }
      
        // Check if it's time to send this notification
        if (notification.nextScheduledDate.isBefore(now)) {
          // Schedule the notification
          await scheduleNotification(
            title: notification.title,
            body: notification.body,
            scheduledTime: now.add(const Duration(minutes: 1)), // Schedule for 1 minute from now
            screen: notification.screen,
            extraData: notification.extraData,
          );
        
          // Calculate and update the next occurrence
          final nextDate = notification.calculateNextDate(now);
          await RecurringNotificationStorage.updateNextScheduledDate(
            notification.id, 
            nextDate
          );
        
          print('Scheduled recurring notification: ${notification.title} - Next date: $nextDate');
        }
      }
    } catch (e) {
      print('Error processing recurring notifications: $e');
    }
  }

  // Create a recurring notification
Future<RecurringNotification> createRecurringNotification({
  required String title,
  required String body,
  required String screen,
  required RecurringInterval interval,
  Map<String, dynamic>? extraData,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  if (!_isInitialized) await initNotification();
  
  final now = DateTime.now();
  final start = startDate ?? now;
  
  // Create the recurring notification object
  final notification = RecurringNotification(
    id: '',  // Will be generated in storage
    title: title,
    body: body,
    screen: screen,
    extraData: extraData,
    interval: interval,
    startDate: start,
    endDate: endDate,
    isActive: true,
    createdAt: now,
    nextScheduledDate: start,
  );
  
  // Save it to storage
  final savedNotification = await RecurringNotificationStorage.addRecurringNotification(
    notification
  );
  
  // If the start date is in the past or very soon, process it right away
  if (start.isBefore(now.add(const Duration(minutes: 15)))) {
    await processRecurringNotifications();
  }
  
  return savedNotification;
}

// Update an existing recurring notification
Future<void> updateRecurringNotification(RecurringNotification notification) async {
  if (!_isInitialized) await initNotification();
  
  await RecurringNotificationStorage.updateRecurringNotification(notification);
}

// Delete a recurring notification
Future<void> deleteRecurringNotification(String id) async {
  if (!_isInitialized) await initNotification();
  
  await RecurringNotificationStorage.deleteRecurringNotification(id);
}

// Get all recurring notifications
Future<List<RecurringNotification>> getRecurringNotifications() async {
  if (!_isInitialized) await initNotification();
  
  return RecurringNotificationStorage.getRecurringNotifications();
}

// Create a standard inventory check recurring notification
Future<RecurringNotification> createInventoryCheckNotification({
  required RecurringInterval interval,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  return createRecurringNotification(
    title: 'Inventory Check Reminder',
    body: 'Time to verify your physical inventory matches your digital records',
    screen: 'inventory',
    interval: interval,
    startDate: startDate,
    endDate: endDate,
  );
}

  //SHOW NOTIFICATIONS
  Future<void> showNotification({
    int? id,
    String? title,
    String? body,
    String? screen,
    Map<String, dynamic>? extraData,
  }) async {
    if (!_isInitialized) await initNotification();
    final notificationId = id ?? await _getNextId();

    // create a standardized payload
    final Map<String, dynamic> payloadMap = {
      'screen': screen ?? 'home',
    };

    // add any extra data
    if (extraData != null) {
      payloadMap.addAll(extraData);
    }

    // convert to a json string
    final String payload = json.encode(payloadMap);

    print('Show Notification: $title - $body with payload: $payload');
    await notificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails(),
      payload: payload,
    );

    //saving the notification to storage
    final notification = AppNotification(
      id: notificationId,
      title: title ?? 'New Notification',
      body: body ?? '',
      timestamp: DateTime.now(),
      payload: payload,
    );

    await NotificationStorage.addNotification(notification);
  }

  //SCHEDULING A NOTIFICATIONS
  Future<void> scheduleNotification({
    int? id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? screen,
    Map<String, dynamic>? extraData,
  }) async {
    if (!_isInitialized) await initNotification();
    final notificationId = id ?? await _getNextId();

    final Map<String, dynamic> payloadMap = {'screen': screen ?? 'home'};

    if (extraData != null) {
      payloadMap.addAll(extraData);
    }

    final String payload = json.encode(payloadMap);

    //Get the current date/time in device's local timezone
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    final notification = AppNotification(
      id: notificationId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      scheduledTime: scheduledTime,
      payload: payload,
    );

    await NotificationStorage.addNotification(notification);

    //Create a date/time for today at the specified hour/min
    await notificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      notificationDetails(),

      //iOS specific: Using exact time.    Apparently this is a required parameter
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,

      //android specific: Allow notification while the device is in low power mode
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,

      //Make the notification repeat daily
      // matchDateTimeComponents: DateTimeComponents.time,
    );
    print("Timezone: ${tz.local.name}");
    print("Scheduled a notification for: $scheduledDate");
  }

  // Get all notifications
  Future<List<AppNotification>> getNotifications() {
    return NotificationStorage.getNotifications();
  }

  Future<void> markAsRead(int id) {
    return NotificationStorage.markAsRead(id);
  }

  Future<void> markAllAsRead() {
    return NotificationStorage.markAllAsRead();
  }

  Future<void> deleteNotification(int id) async {
    await notificationsPlugin.cancel(id);
    await NotificationStorage.deleteNotification(id);
  }

  Future<void> deleteAllNotifications() async {
    await notificationsPlugin.cancelAll();
    await NotificationStorage.deleteAllNotifications();
  }
}
