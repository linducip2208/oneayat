// Daily reminder scheduler: 7 days ahead, body carries the actual ayat
// (translation snippet + ref), auto-skipped when already read, gentle tone
// when yesterday was missed. Re-run on start, settings change, mark-done.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../data/quran_repository.dart';
import 'notification_service.dart';
import 'progress_logic.dart';
import 'progress_repository.dart';
import 'settings_store.dart';

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
    final todayKey = dateKey(now);
    final days = await progress.daysCompleted();
    final yesterdayKey = dateKey(now.subtract(const Duration(days: 1)));
    final missedYesterday =
        days > 0 && !(await progress.isDailyDone(yesterdayKey));
    final streaks = await progress.streaks();
    final streak = streaks.$1;
    for (var d = 0; d < _daysAhead; d++) {
      final dayLocal =
          DateTime(now.year, now.month, now.day).add(Duration(days: d));
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
      try {
        await notif.plugin.zonedSchedule(
          _baseId + d,
          'ONE AYAT',
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
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'home',
        );
      } catch (_) {}
    }
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
  }
}
