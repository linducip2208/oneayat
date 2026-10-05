import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/services/app_day.dart';

void main() {
  test('before fajr counts as yesterday (grace hour)', () {
    final fajr = DateTime(2026, 10, 5, 4, 30);
    expect(appDayKeyFor(DateTime(2026, 10, 5, 2, 0), fajr), '2026-10-04');
    expect(appDayKeyFor(DateTime(2026, 10, 5, 6, 0), fajr), '2026-10-05');
    expect(appDayKeyFor(DateTime(2026, 10, 5, 4, 30), fajr), '2026-10-05');
  });

  test('suggest hour from habit, needs 5+ reads', () {
    List<int> at(List<int> hours) => [
          for (final h in hours)
            DateTime(2026, 10, 1, h, 15).millisecondsSinceEpoch,
        ];
    expect(suggestReminderHour(at([21, 21, 22, 21, 20]), 8), 21);
    // too little data
    expect(suggestReminderHour(at([21, 21]), 8), isNull);
    // already close
    expect(suggestReminderHour(at([21, 21, 21, 22, 21]), 21), isNull);
    // spread too wide
    expect(suggestReminderHour(at([6, 12, 18, 21, 23]), 8), isNull);
  });

  test('nextFriday strictly ahead', () {
    // 2026-10-05 is a Monday.
    expect(nextFriday(DateTime(2026, 10, 5)).day, 9);
    // Friday -> next Friday (7 days).
    final f = nextFriday(DateTime(2026, 10, 9));
    expect(f.day, 16);
    expect(f.weekday, DateTime.friday);
  });

  test('snooze cap 2 per day', () {
    expect(snoozeAllowed(0), isTrue);
    expect(snoozeAllowed(1), isTrue);
    expect(snoozeAllowed(2), isFalse);
  });
}
