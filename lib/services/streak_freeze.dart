// Streak-freeze (2x/month) + notification-action handlers.
// Handlers use only SharedPreferences + sqflite so they run in BOTH the main
// isolate (foreground tap) and the background isolate (silent action tap).
// All fail-safe: any error returns "not applied", user can act inside the app.
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/models.dart';
import 'progress_logic.dart';
import 'progress_repository.dart';

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
/// date is today (stale notifications are ignored).
Future<bool> handleMarkReadAction(String? payload) async {
  try {
    final p = parseDailyPayload(payload);
    if (p == null) return false;
    if (p.todayKey != dateKey(DateTime.now())) return false;
    final qdb = QuranDatabase();
    final progress = ProgressRepository(qdb);
    if (await progress.isDailyDone(p.todayKey)) return true;
    final parts = p.todayKey.split('-');
    final date = DateTime.utc(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    await progress.markDailyDone(date, AyahRef(p.surah, p.ayah));
    await qdb.close();
    return true;
  } catch (_) {
    return false;
  }
}

enum FreezeResult { applied, noSlot, alreadyRead, invalid }

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
