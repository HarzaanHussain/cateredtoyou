import 'dart:convert';

import 'package:cateredtoyou/models/notification_model.dart';
import 'package:cateredtoyou/utils/notification_storage.dart';
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
      //parse the payload
      final Map<String, dynamic> payloadData = _parsePayload(payload);
      print('Parsed payload: $payloadData');

      if (payloadData.containsKey('screen')) {
        final String screen = payloadData['screen'].toString();
        print('Attempting to navigate to: $screen');

        // get route from screen name
        final String route = _getRouteFromScreen(screen);

        if (route.isNotEmpty) {
          // navigate using the context
          print('Navigating to route: $route');
          GoRouter.of(context).go(route);
        } else {
          print('Unknown screen in payload $screen');
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
        final keyValue = pair.split(';');
        if (keyValue.length == 2) {
          result[keyValue[0].trim()] = keyValue[1].trim();
        }
      }
      return result;
    }
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
