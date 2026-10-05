// Local notifications: daily reminder + adzan, no server.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'device_timezone.dart';
import 'app_router_holder.dart';
import 'streak_freeze.dart';

/// Background-isolate entry point for silent notification actions
/// (mark-read / freeze without opening the app).
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse r) {
  if (r.actionId == 'mark_read') {
    handleMarkReadAction(r.payload);
  } else if (r.actionId == 'freeze') {
    handleFreezeAction(r.payload);
  } else if (r.actionId == 'snooze') {
    handleSnoozeAction(r.payload);
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Fired in the main isolate after a foreground action is handled
  /// (refresh UI + reschedule). Set once from main().
  static Future<void> Function()? onActionHandled;

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
      onDidReceiveNotificationResponse: (r) async {
        if (r.actionId == 'mark_read') {
          await handleMarkReadAction(r.payload);
          try {
            await onActionHandled?.call();
          } catch (_) {}
        } else if (r.actionId == 'freeze') {
          await handleFreezeAction(r.payload);
          try {
            await onActionHandled?.call();
          } catch (_) {}
        } else if (r.actionId == 'snooze') {
          await handleSnoozeAction(r.payload);
          try {
            await onActionHandled?.call();
          } catch (_) {}
        } else if (r.actionId == 'open_home') {
          try {
            AppRouterHolder.router?.go('/home');
          } catch (_) {}
        } else {
          // Tap on daily/adzan body opens today's ayat (Home).
          try {
            AppRouterHolder.router?.go('/home');
          } catch (_) {}
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationActionBackground,
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
