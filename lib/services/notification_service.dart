import 'package:cateredtoyou/models/notification_model.dart';
import 'package:cateredtoyou/utils/notification_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;

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

    // Define the callback for when a notification is tapped
    final onDidReceiveLocalNotification =
        (int id, String? title, String? body, String? payload) {
      print('Notification tapped: $id, $title, $body, $payload');
      // handle tap here or payload to navigate to specific view
    };

    //android settings
    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );

    await notificationsPlugin.initialize(initSettings);

    _isInitialized = true;
    print("Notifications Initialized");
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
    String? payload,
  }) async {
    if (!_isInitialized) await initNotification();
    final notificationId = id ?? await _getNextId();

    print('Show Notification: $title - $body');
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
        timestamp: DateTime.now());

    await NotificationStorage.addNotification(notification);
  }

  //SCHEDULING A NOTIFICATIONS
  Future<void> scheduleNotification({
    int? id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) await initNotification();
    final notificationId = id ?? await _getNextId();

    //Get the current date/time in device's local timezone
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    final notification = AppNotification(
        id: notificationId,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        scheduledTime: scheduledTime);

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
