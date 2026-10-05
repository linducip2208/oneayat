// App-day + smart-suggestion helpers (pure, unit-tested).
//
// Grace hour: before today's Subuh still counts as yesterday, so night owls
// are not punished at midnight.
import 'progress_logic.dart';

/// [fajrToday] = today's Fajr as local DateTime.
String appDayKeyFor(DateTime localNow, DateTime fajrToday) {
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  if (localNow.isBefore(fajrToday)) {
    return dateKey(today.subtract(const Duration(days: 1)));
  }
  return dateKey(today);
}

/// Suggest a reminder hour from recent read timestamps (ms since epoch).
/// Returns null when no change is warranted: too little data, already close
/// (<=1h), or spread too wide (no habit).
int? suggestReminderHour(List<int> openedAtMs, int currentHour) {
  if (openedAtMs.length < 5) return null;
  final hours = openedAtMs
      .map((ms) => DateTime.fromMillisecondsSinceEpoch(ms).hour)
      .toList()
    ..sort();
  final median = hours[hours.length ~/ 2];
  if ((median - currentHour).abs() <= 1) return null;
  // Habit strength: >=60% of reads within +-1h of median.
  final near =
      hours.where((h) => (h - median).abs() <= 1).length / hours.length;
  if (near < 0.6) return null;
  return median;
}

/// Next Friday (strictly after [from] if [from] is Friday).
DateTime nextFriday(DateTime from) {
  var d = DateTime(from.year, from.month, from.day);
  do {
    d = d.add(const Duration(days: 1));
  } while (d.weekday != DateTime.friday);
  return d;
}

/// Snooze cap: max 2 per day.
bool snoozeAllowed(int usedToday) => usedToday < 2;
