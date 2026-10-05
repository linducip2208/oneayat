// Local notifications: daily reminder + adzan, no server.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'device_timezone.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await DeviceTimezone.getName();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (_) {},
    );
    _ready = true;
  }

  Future<void> scheduleDaily({
    required int hour, required int minute,
    required bool enabled, required String lang,
  }) async {
    if (!_ready) return;
    await plugin.cancel(1001);
    if (!enabled) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (at.isBefore(now)) at = at.add(const Duration(days: 1));
      final title = lang == 'en' ? 'ONE AYAT' : 'ONE AYAT';
      final body = lang == 'en'
          ? 'Your ayat for today is ready.'
          : 'Ayat hari ini sudah siap.';
      await plugin.zonedSchedule(
        1001, title, body, at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_ayat', 'Daily Ayat',
            importance: Importance.high, priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }
}
