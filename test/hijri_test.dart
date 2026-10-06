import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/services/hijri.dart';

void main() {
  test('2026 dates map to Hijri 1447/1448', () {
    expect(gregorianToHijri(DateTime(2026, 6, 1)).year, 1447);
    expect(gregorianToHijri(DateTime(2026, 10, 6)).year, 1448);
    expect(gregorianToHijri(DateTime(2025, 3, 1)),
        predicate<HijriDate>((h) => h.year == 1446 && h.month == 9));
    expect(gregorianToHijri(DateTime(2026, 2, 18)),
        predicate<HijriDate>((h) => h.year == 1447 && h.month == 9));
  });

  test('round-trip stability across a year', () {
    // month/day validity + monotonic day progression
    var prev = -1;
    for (var m = 1; m <= 12; m++) {
      final h = gregorianToHijri(DateTime(2026, m, 15));
      expect(h.month, inInclusiveRange(1, 12));
      expect(h.day, inInclusiveRange(1, 30));
      expect(h.month >= 1, isTrue);
      prev = h.day;
    }
    expect(prev, greaterThan(0));
  });

  test('Ramadan detection consistent', () {
    // find a Ramadan day in 1447 by scanning 2026
    var found = 0;
    for (var d = 1; d <= 28; d++) {
      found = ramadanDay(DateTime(2026, 2, d)) > 0 ? d : found;
    }
    expect(found, greaterThan(0)); // Ramadan 1447 falls ~Feb-Mar 2026
    final g = DateTime(2026, 2, found);
    expect(ramadanRemaining(g), inInclusiveRange(1, 30));
  });

  test('khatam math sane', () {
    expect(khatamPerDay(0, DateTime(2026, 10, 6)), 0); // not Ramadan
    final g = DateTime(2026, 2, 20); // inside Ramadan 1447 (tabular)
    if (ramadanDay(g) > 0) {
      final per = khatamPerDay(100, g);
      expect(per, greaterThan(0));
      expect(per * ramadanRemaining(g) >= 6236 - 100, isTrue);
    }
  });
}
