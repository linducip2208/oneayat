// Daily reminder scheduler: 7 days ahead, body carries the actual ayat
// (translation snippet + ref), auto-skipped when already read, gentle tone
// when yesterday was missed. Re-run on start, settings change, mark-done.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../data/quran_repository.dart';
import 'app_day.dart';
import 'notification_service.dart';
import 'progress_logic.dart';
import 'progress_repository.dart';
import 'settings_store.dart';
import 'streak_freeze.dart';

/// Pure body builder (unit-tested).
String reminderBody({
  required String? translation,
  required String surahName,
  required int surah,
  required int ayah,
  required String lang,
  required bool missedYesterday,
  required int streak,
}) {
  final ref = 'QS. $surahName ($surah:$ayah)';
  final snippet = _truncate((translation ?? '').trim(), 110);
  var prefix = '';
  if (missedYesterday && streak == 0) {
    prefix = lang == 'en'
        ? 'Missed yesterday — no guilt. '
        : 'Kemarin terlewat, tidak apa-apa. ';
  } else if (streak == 7 ||
      streak == 30 ||
      streak == 100 ||
      streak == 365) {
    prefix = lang == 'en'
        ? '🔥 $streak days! '
        : '🔥 $streak hari! ';
  }
  if (snippet.isEmpty) {
    return '$prefix${lang == 'en' ? 'Your ayat for today is ready. ' : 'Ayat hari ini sudah siap. '}$ref';
  }
  return '$prefix“$snippet” — $ref';
}

String _truncate(String s, int max) {
  final one = s.replaceAll(RegExp(r'\s+'), ' ');
  if (one.length <= max) return one;
  return '${one.substring(0, max - 1).trim()}…';
}

class DailyReminderScheduler {
  final NotificationService notif;
  final QuranRepository quran;
  final ProgressRepository progress;
  DailyReminderScheduler(this.notif, this.quran, this.progress);

  static const int _baseId = 1100;
  static const int _daysAhead = 7;

  Future<void> reschedule(AppSettings s, {required bool fullCoverage}) async {
    await cancelAll();
    if (!s.reminderEnabled) return;
    final now = DateTime.now();
    // App-day aware: before Subuh still counts as yesterday.
    final todayKey = s.currentAppDayKey(now);
    var appToday = DateTime(now.year, now.month, now.day);
    if (dateKey(appToday) != todayKey) {
      appToday = appToday.subtract(const Duration(days: 1));
    }
    final yesterdayKey =
        dateKey(appToday.subtract(const Duration(days: 1)));
    final days = await progress.daysCompleted();
    final missedYesterday =
        days > 0 && !(await progress.isDailyDone(yesterdayKey));
    final streaks = await progress.streaks();
    final streak = streaks.$1;
    for (var d = 0; d < _daysAhead; d++) {
      final dayLocal = appToday.add(Duration(days: d));
      final key = dateKey(dayLocal);
      if (key == todayKey) {
        // Today's slot: skip when already read.
        if (await progress.isDailyDone(key)) continue;
      } else {
        if (await progress.isDailyDone(key)) continue;
      }
      final dateUtc =
          DateTime.utc(dayLocal.year, dayLocal.month, dayLocal.day);
      final refDaily =
          await quran.dailyRef(dateUtc, fullCoverage: fullCoverage);
      // Yesterday's ref (for streak-freeze action) — only meaningful today.
      var yKey = '';
      var ys = 0;
      var ya = 0;
      final isToday = key == todayKey;
      if (isToday && missedYesterday) {
        final yLocal = dayLocal.subtract(const Duration(days: 1));
        yKey = dateKey(yLocal);
        final yUtc = DateTime.utc(yLocal.year, yLocal.month, yLocal.day);
        final yRef = await quran.dailyRef(yUtc, fullCoverage: fullCoverage);
        ys = yRef.surah;
        ya = yRef.ayah;
      }
      final AyahDetail? det = await quran.ayahDetail(
        refDaily.surah,
        refDaily.ayah,
        readingId: s.readingId,
        lang: s.trLang,
      );
      final translation =
          s.trLang == 'en' ? det?.enTranslation : det?.idTranslation;
      final body = reminderBody(
        translation: translation,
        surahName: quran.surahName(refDaily.surah),
        surah: refDaily.surah,
        ayah: refDaily.ayah,
        lang: s.appLang,
        missedYesterday: d == 0 && missedYesterday,
        streak: d == 0 ? streak : 0,
      );
      var at = tz.TZDateTime.from(
        DateTime(dayLocal.year, dayLocal.month, dayLocal.day, s.reminderHour,
            s.reminderMinute),
        tz.local,
      );
      if (at.isBefore(tz.TZDateTime.now(tz.local))) continue;
      final payload = buildDailyPayload(
        todayKey: key,
        surah: refDaily.surah,
        ayah: refDaily.ayah,
        missedYesterday: isToday && missedYesterday,
        yesterdayKey: yKey,
        yesterdaySurah: ys,
        yesterdayAyah: ya,
      );
      try {
        await notif.plugin.zonedSchedule(
          _baseId + d,
          'ONE AYAT',
          body,
          at,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_ayat',
              'Daily Ayat',
              importance: Importance.high,
              priority: Priority.high,
              actions: [
                const AndroidNotificationAction(
                  'mark_read',
                  '✓ Tandai dibaca',
                  showsUserInterface: false,
                ),
                const AndroidNotificationAction(
                  'snooze',
                  '⏰ 1 jam lagi',
                  showsUserInterface: false,
                ),
                if (isToday && missedYesterday)
                  const AndroidNotificationAction(
                    'freeze',
                    '❄ Bekukan kemarin',
                    showsUserInterface: false,
                  ),
              ],
            ),
          ),
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (_) {}
    }
    await _scheduleFridayRecap(s, appToday);
  }

  /// Friday morning recap: last 7 app days read/total. One notification only.
  Future<void> _scheduleFridayRecap(AppSettings s, DateTime appToday) async {
    const id = 1200;
    try {
      await notif.plugin.cancel(id);
    } catch (_) {}
    var read = 0;
    for (var i = 0; i < 7; i++) {
      final k = dateKey(appToday.subtract(Duration(days: i)));
      try {
        if (await progress.isDailyDone(k)) read++;
      } catch (_) {}
    }
    final friday = nextFriday(DateTime.now());
    final at = tz.TZDateTime.from(
      DateTime(friday.year, friday.month, friday.day, s.reminderHour,
          s.reminderMinute),
      tz.local,
    );
    if (at.isBefore(tz.TZDateTime.now(tz.local))) return;
    final body = s.appLang == 'en'
        ? 'This week: $read/7 days • ${await progress.daysCompleted()} ayat on your journey. Bismillah, one more today.'
        : 'Pekan ini: $read/7 hari • ${await progress.daysCompleted()} ayat perjalananmu. Bismillah, satu lagi hari ini.';
    try {
      await notif.plugin.zonedSchedule(
        id,
        s.appLang == 'en' ? 'ONE AYAT • Friday' : 'ONE AYAT • Jumat',
        body,
        at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_ayat',
            'Daily Ayat',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'home',
      );
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await notif.plugin.cancel(1001); // legacy repeating id
    } catch (_) {}
    for (var d = 0; d < _daysAhead; d++) {
      try {
        await notif.plugin.cancel(_baseId + d);
      } catch (_) {}
    }
    try {
      await notif.plugin.cancel(1200); // friday recap
    } catch (_) {}
  }
}
