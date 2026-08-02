import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/task.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Stream to notify the app when a notification is tapped
  static final StreamController<int> onNotificationTappedController =
      StreamController<int>.broadcast();

  static Future<void> init() async {
    tzdata.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      sound: null, // SILENT
      presentationOptions: DarwinPresentationOptions.alert,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith('task_')) {
          final id = int.tryParse(payload.split('_')[1]);
          if (id != null) {
            onNotificationTappedController.add(id);
          }
        }
      },
    );
  }

  // Schedule a single silent notification
  static Future<void> scheduleReminder(Task task, {int? customId}) async {
    final tz.TZDateTime scheduled = tz.TZDateTime.from(
      task.scheduledTime,
      tz.local,
    );

    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final int notificationId = customId ?? task.id ?? DateTime.now().millisecondsSinceEpoch;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Task reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, // SILENT
      enableVibration: false,
      fullScreenIntent: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: null, // SILENT
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      notificationId,
      task.title,
      task.description,
      scheduled,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task_${task.id}',
    );
  }

  // Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
