// Streak-freeze (2x/month) + notification-action handlers.
// Handlers use only SharedPreferences + sqflite (+ pure metadata) so they run
// in BOTH the main isolate (foreground tap) and the background isolate
// (silent action tap). All fail-safe.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/surah_metadata.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/quran_repository.dart';
import 'app_day.dart';
import 'progress_repository.dart';
import 'settings_store.dart';

const int kFreezePerMonth = 2;
const String _kFreezeMonth = 'freeze_month';
const String _kFreezeUsed = 'freeze_used';

String currentMonthKey([DateTime? now]) {
  final n = now ?? DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}';
}

/// Pure rollover decision (unit-tested).
///
/// Returns (allowed, newStoredUsedForCurrentMonth).
(int allowed, int newUsed) freezeDecision(
    String? storedMonth, int storedUsed, String curMonth) {
  if (storedMonth != curMonth) return (1, 1);
  if (storedUsed < kFreezePerMonth) return (1, storedUsed + 1);
  return (0, storedUsed);
}

class FreezeStatus {
  final String month;
  final int used;
  const FreezeStatus(this.month, this.used);
  int get remaining => (kFreezePerMonth - used).clamp(0, kFreezePerMonth);
}

Future<FreezeStatus> getFreezeStatus() async {
  final p = await SharedPreferences.getInstance();
  final cur = currentMonthKey();
  final m = p.getString(_kFreezeMonth);
  if (m != cur) return FreezeStatus(cur, 0);
  return FreezeStatus(cur, p.getInt(_kFreezeUsed) ?? 0);
}

/// Atomically consume one freeze slot. Returns false when none left.
Future<bool> tryConsumeFreezeSlot() async {
  final p = await SharedPreferences.getInstance();
  final cur = currentMonthKey();
  final (allowed, newUsed) =
      freezeDecision(p.getString(_kFreezeMonth), p.getInt(_kFreezeUsed) ?? 0, cur);
  if (allowed == 0) return false;
  await p.setString(_kFreezeMonth, cur);
  await p.setInt(_kFreezeUsed, newUsed);
  return true;
}

// ---------- payload ----------
// v1|todayKey|s|a|missed|ys|ya|yk   (ys/ya/yk = yesterday ref or 0/0/'')
class DailyPayload {
  final String todayKey;
  final int surah;
  final int ayah;
  final bool missedYesterday;
  final String yesterdayKey;
  final int yesterdaySurah;
  final int yesterdayAyah;
  const DailyPayload({
    required this.todayKey,
    required this.surah,
    required this.ayah,
    required this.missedYesterday,
    required this.yesterdayKey,
    required this.yesterdaySurah,
    required this.yesterdayAyah,
  });
}

String buildDailyPayload({
  required String todayKey,
  required int surah,
  required int ayah,
  required bool missedYesterday,
  required String yesterdayKey,
  required int yesterdaySurah,
  required int yesterdayAyah,
}) =>
    'v1|$todayKey|$surah|$ayah|${missedYesterday ? 1 : 0}|$yesterdayKey|$yesterdaySurah|$yesterdayAyah';

DailyPayload? parseDailyPayload(String? raw) {
  if (raw == null || raw == 'home') return null;
  final parts = raw.split('|');
  if (parts.length != 8 || parts[0] != 'v1') return null;
  try {
    return DailyPayload(
      todayKey: parts[1],
      surah: int.parse(parts[2]),
      ayah: int.parse(parts[3]),
      missedYesterday: parts[4] == '1',
      yesterdayKey: parts[5],
      yesterdaySurah: int.parse(parts[6]),
      yesterdayAyah: int.parse(parts[7]),
    );
  } catch (_) {
    return null;
  }
}

/// Mark today read from a notification action. Only applies when the payload
/// date is the current app day (grace hour respected); stale ones ignored.
Future<bool> handleMarkReadAction(String? payload) async {
  try {
    final p = parseDailyPayload(payload);
    if (p == null) return false;
    final settings = AppSettings();
    await settings.load();
    if (p.todayKey != settings.currentAppDayKey()) return false;
    final qdb = QuranDatabase();
    final progress = ProgressRepository(qdb);
    if (await progress.isDailyDone(p.todayKey)) return true;
    await progress.markDailyDone(p.todayKey, AyahRef(p.surah, p.ayah));
    await qdb.close();
    return true;
  } catch (_) {
    return false;
  }
}

/// Mark today read from the home-screen widget button (no payload).
/// Computes today's ref deterministically from the local database.
Future<bool> handleWidgetMarkRead() async {
  try {
    final settings = AppSettings();
    await settings.load();
    final qdb = QuranDatabase();
    try {
      final progress = ProgressRepository(qdb);
      final key = settings.currentAppDayKey();
      if (await progress.isDailyDone(key)) return true;
      final health = await qdb.checkHealth();
      final repo = QuranRepository(qdb);
      final parts = key.split('-');
      final dateUtc = DateTime.utc(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final refDaily = await repo.dailyRef(dateUtc,
          fullCoverage: health.fullCoverage);
      await progress.markDailyDone(key, refDaily);
      return true;
    } finally {
      await qdb.close();
    }
  } catch (_) {
    return false;
  }
}

enum FreezeResult { applied, noSlot, alreadyRead, invalid }

/// Snooze today's reminder by 1 hour, max 2x per app day.
/// Rebuilds a lightweight notification (ref only, no translation lookup) so it
/// works in the background isolate without the translation database.
Future<bool> handleSnoozeAction(String? payload) async {
  try {
    final p = parseDailyPayload(payload);
    if (p == null) return false;
    final settings = AppSettings();
    await settings.load();
    if (p.todayKey != settings.currentAppDayKey()) return false;
    final prefs = await SharedPreferences.getInstance();
    final snoozeKey = 'snooze_${p.todayKey}';
    final used = prefs.getInt(snoozeKey) ?? 0;
    if (!snoozeAllowed(used)) return false;
    tzdata.initializeTimeZones();
    final at = tz.TZDateTime.from(
      DateTime.now().add(const Duration(hours: 1)),
      tz.UTC,
    );
    final plugin = FlutterLocalNotificationsPlugin();
    final name = kSurahs[p.surah - 1].latin;
    await plugin.zonedSchedule(
      1300 + used,
      'ONE AYAT',
      settings.appLang == 'en'
          ? '⏰ ${p.surah}:${p.ayah} still waiting — tap to read.'
          : '⏰ QS. $name (${p.surah}:${p.ayah}) menunggumu — ketuk untuk membaca.',
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_ayat',
          'Daily Ayat',
          importance: Importance.high,
          priority: Priority.high,
          actions: const [
            AndroidNotificationAction(
              'mark_read',
              '✓ Tandai dibaca',
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
    await prefs.setInt(snoozeKey, used + 1);
    return true;
  } catch (_) {
    return false;
  }
}
/// Freeze yesterday: streak continuity without adding ayat count.
Future<FreezeResult> handleFreezeAction(String? payload) async {
  try {
    final p = parseDailyPayload(payload);
    if (p == null || !p.missedYesterday || p.yesterdayKey.isEmpty) {
      return FreezeResult.invalid;
    }
    final qdb = QuranDatabase();
    final progress = ProgressRepository(qdb);
    try {
      if (await progress.isDailyDone(p.yesterdayKey)) {
        return FreezeResult.alreadyRead;
      }
      if (!await tryConsumeFreezeSlot()) return FreezeResult.noSlot;
      await progress.freezeDay(
          p.yesterdayKey, AyahRef(p.yesterdaySurah, p.yesterdayAyah));
      return FreezeResult.applied;
    } finally {
      await qdb.close();
    }
  } catch (_) {
    return FreezeResult.invalid;
  }
}
