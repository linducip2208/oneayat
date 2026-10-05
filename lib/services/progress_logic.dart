// Pure-logic services: daily progress + streak (unit-tested, no Flutter deps).
import '../core/constants.dart';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class JourneyStats {
  final int daysCompleted;
  final int totalAyatRead;
  final double progressPct; // 0..100 over 6236
  final int currentStreak;
  final int longestStreak;
  const JourneyStats({
    required this.daysCompleted, required this.totalAyatRead,
    required this.progressPct, required this.currentStreak, required this.longestStreak,
  });
}

JourneyStats journeyStats({required int daysCompleted, required int currentStreak, required int longestStreak, int pacePerDay = 1}) {
  final ayat = daysCompleted * pacePerDay;
  return JourneyStats(
    daysCompleted: daysCompleted,
    totalAyatRead: ayat,
    progressPct: ayat / AppConstants.totalAyahs * 100,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
  );
}

/// Streak update given sorted unique date keys, ending at [todayKey].
({int current, int longest}) computeStreaks(Set<String> doneDates, String todayKey) {
  if (doneDates.isEmpty) return (current: 0, longest: 0);
  final sorted = doneDates.toList()..sort();
  var longest = 1, run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final prev = DateTime.parse(sorted[i - 1]);
    final cur = DateTime.parse(sorted[i]);
    if (cur.difference(prev).inDays == 1) {
      run += 1;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
  }
  // current streak: consecutive ending today (or yesterday if today missing)
  var current = 0;
  var cursor = DateTime.parse(todayKey);
  if (!doneDates.contains(todayKey)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (doneDates.contains(dateKey(cursor))) {
    current += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return (current: current, longest: longest);
}

List<String> streakMilestonesHit(int streak) => [
  if (streak == 7) '7 days',
  if (streak == 30) '30 days',
  if (streak == 100) '100 days',
  if (streak == 365) '365 days',
];
