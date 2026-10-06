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

  bool get isReady => _ready;
}
