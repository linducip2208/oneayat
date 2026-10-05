// Adzan scheduler: local notifications for prayer times. Fully offline —
// times computed on-device, no server, no location permission (manual city).
// Schedules 7 days ahead; re-run on app start + settings change.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';
import 'prayer_times.dart';
import 'settings_store.dart';

class AdhanScheduler {
  final NotificationService notif;
  AdhanScheduler(this.notif);

  static const int _baseId = 3000;
  static const int _daysAhead = 7;

  Future<void> reschedule(AppSettings s) async {
    await cancelAll();
    if (!s.adhanEnabled) return;
    final method = prayerMethodById(s.prayerMethod);
    final tzOffset =
        DateTime.now().timeZoneOffset.inMinutes.toDouble() / 60.0;
    final now = DateTime.now();
    for (var d = 0; d < _daysAhead; d++) {
      final day = DateTime(now.year, now.month, now.day)
          .add(Duration(days: d));
      final prayer = computePrayerDay(
        localDay: day,
        lat: s.latitude,
        lon: s.longitude,
        method: method,
        tzOffsetHours: tzOffset,
      );
      for (var i = 0; i < kAdhanKeys.length; i++) {
        final key = kAdhanKeys[i];
        if (!s.adhanFor(key)) continue;
        final at = prayer.timeOf(key);
        if (at.isBefore(now)) continue;
        final name = prayerName(key, s.appLang);
        try {
          await notif.plugin.zonedSchedule(
            _baseId + d * 10 + i,
            'Adzan $name',
            s.appLang == 'en'
                ? 'Time for $name prayer • ONE AYAT'
                : 'Saatnya salat $name • ONE AYAT',
            tz.TZDateTime.from(at, tz.local),
            NotificationDetails(
              android: AndroidNotificationDetails(
                'adhan',
                'Adzan',
                importance: Importance.high,
                priority: Priority.high,
                // No bundled adzan audio (licensed asset required to add
                // res/raw/adhan.mp3 + sound: RawResourceAndroidNotificationSound('adhan')).
                actions: [
                  AndroidNotificationAction(
                    'open_home',
                    s.appLang == 'en'
                        ? '📖 Read today\u2019s ayat'
                        : '📖 Baca ayat hari ini',
                    showsUserInterface: true,
                  ),
                ],
              ),
            ),
            androidScheduleMode:
                AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'home',
          );
        } catch (_) {}
      }
    }
  }

  Future<void> cancelAll() async {
    for (var d = 0; d < _daysAhead; d++) {
      for (var i = 0; i < kAdhanKeys.length; i++) {
        try {
          await notif.plugin.cancel(_baseId + d * 10 + i);
        } catch (_) {}
      }
    }
  }
}
