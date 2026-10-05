import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/services/progress_logic.dart';

void main() {
  test('consecutive days build streak', () {
    final set = {'2026-10-03', '2026-10-04', '2026-10-05'};
    final r = computeStreaks(set, '2026-10-05');
    expect(r.current, 3);
    expect(r.longest, 3);
  });

  test('gap resets current streak but keeps longest', () {
    final set = {'2026-10-01', '2026-10-02', '2026-10-05'};
    final r = computeStreaks(set, '2026-10-05');
    expect(r.current, 1);
    expect(r.longest, 2);
  });

  test('empty set gives zero', () {
    final r = computeStreaks({}, '2026-10-05');
    expect(r.current, 0);
    expect(r.longest, 0);
  });

  test('journey stats math', () {
    final s = journeyStats(daysCompleted: 47, currentStreak: 27, longestStreak: 27);
    expect(s.totalAyatRead, 47);
    expect(s.progressPct, closeTo(47 / 6236 * 100, 0.0001));
  });

  test('milestones fire exactly once', () {
    expect(streakMilestonesHit(7), ['7 days']);
    expect(streakMilestonesHit(27), isEmpty);
    expect(streakMilestonesHit(365), ['365 days']);
  });
}
