import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;


class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _firebaseMessaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Handling background message: ${message.notification?.title} - ${message.notification?.body}');
  }

  //INITIALIZATION
  Future<void> initNotification() async {
    if(_isInitialized) return;

    //initialize the timezone
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    //firebase messaging
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final fCMToken = await _firebaseMessaging.getToken(); //fcmtoken for this device
    print('Token: $fCMToken');


    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final bool? permissionGranted = await androidPlugin?.requestNotificationsPermission();
    print('Android notification permission granted: $permissionGranted');


    //android settings
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );

    await notificationsPlugin.initialize(initSettings);

    //background message handler
    // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    //LISTEN FOR FOREGROUND MESSAGES
    FirebaseMessaging.onMessage.listen((RemoteMessage message){
      print('Foreground message received: ${message.notification?.title} - ${message.notification?.body}');
      showNotification(
        title: message.notification?.title ?? 'New Notification',
        body: message.notification?.body ?? '',
      );
    });

    //ON TAP
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message){
      print('User tapped on notification ${message.data}');
      //if there is any on tap event for the notification
    });

    _isInitialized = true; // Mark as initialized
    print("Notifications initialized");

  }

  //NOTIFICATION DETAILS
  NotificationDetails notificationDetails(){
    return const NotificationDetails(
        android: AndroidNotificationDetails(
          'catered_to_you',
          'Catered To You',
          channelDescription: 'Catered To You Notification',
          importance: Importance.max,
          priority: Priority.high,
        )
    );
  }


  //SHOW NOTIFICATIONS
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    print('Show Notification: $title - $body');
    return notificationsPlugin.show(id, title, body, notificationDetails(),);
  }

  //SCHEDULING A NOTIFICATIONS
  Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    required int hour,
    required int minute,
}) async {
    //Get the current date/time in device's local timezone
    final now = tz.TZDateTime.now(tz.local);

    //Create a date/time for today at the specified hour/min
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails(),

      //iOS specific: Using exact time.    Apparently this is a required parameter
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,

      //android specific: Allow notification while the device is in low power mode
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

      //Make the notification repeat daily
      // matchDateTimeComponents: DateTimeComponents.time,
    );
    print("Timezone: ${tz.local.name}");
    print("Scheduled a notification for: $scheduledDate");

  }

  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }

}