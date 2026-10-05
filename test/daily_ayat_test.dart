import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/core/constants.dart';

void main() {
  test('total ayahs = 6236 and counts consistent', () {
    expect(AppConstants.ayahCounts.length, 114);
    expect(AppConstants.ayahCounts.reduce((a, b) => a + b), 6236);
    expect(AppConstants.totalAyahs, 6236);
  });

  test('daily global index deterministic for same date', () {
    final d = DateTime.utc(2026, 10, 5);
    expect(AppConstants.dailyGlobalIndexFor(d),
        AppConstants.dailyGlobalIndexFor(DateTime.utc(2026, 10, 5, 23, 59)));
  });

  test('daily index differs across days and stays in range', () {
    final a = AppConstants.dailyGlobalIndexFor(DateTime.utc(2026, 10, 5));
    final b = AppConstants.dailyGlobalIndexFor(DateTime.utc(2026, 10, 6));
    expect(a, isNot(b));
    expect(a, inInclusiveRange(0, 6235));
    expect(b, inInclusiveRange(0, 6235));
  });

  test('global index round-trips through surah:ayah', () {
    for (final g in [0, 1, 6235, 100, 5000]) {
      final (s, a) = AppConstants.globalIndexToRef(g);
      expect(AppConstants.refToGlobalIndex(s, a), g);
      expect(s, inInclusiveRange(1, 114));
    }
  });

  test('epoch stability: 2024-01-01 -> day 0', () {
    expect(AppConstants.dayIndexFor(DateTime.utc(2024, 1, 1)), 0);
  });
}
