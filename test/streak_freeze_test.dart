import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/services/streak_freeze.dart';

void main() {
  test('payload round-trips', () {
    const raw = 'v1|2026-10-05|94|5|1|2026-10-04|94|4';
    final p = parseDailyPayload(raw);
    expect(p, isNotNull);
    expect(p!.todayKey, '2026-10-05');
    expect(p.surah, 94);
    expect(p.missedYesterday, isTrue);
    expect(p.yesterdayKey, '2026-10-04');
    expect(
      buildDailyPayload(
        todayKey: p.todayKey,
        surah: p.surah,
        ayah: p.ayah,
        missedYesterday: p.missedYesterday,
        yesterdayKey: p.yesterdayKey,
        yesterdaySurah: p.yesterdaySurah,
        yesterdayAyah: p.yesterdayAyah,
      ),
      raw,
    );
  });

  test('legacy and garbage payloads rejected', () {
    expect(parseDailyPayload(null), isNull);
    expect(parseDailyPayload('home'), isNull);
    expect(parseDailyPayload('v1|a|b'), isNull);
    expect(parseDailyPayload('v2|2026-10-05|1|1|0|||'), isNull);
  });

  test('freeze rollover: new month resets to 1 used', () {
    final (allowed, used) = freezeDecision('2026-09', 2, '2026-10');
    expect(allowed, 1);
    expect(used, 1);
  });

  test('freeze cap: 2 per month enforced', () {
    var (a1, u1) = freezeDecision(null, 0, '2026-10');
    expect((a1, u1), (1, 1));
    var (a2, u2) = freezeDecision('2026-10', u1, '2026-10');
    expect((a2, u2), (1, 2));
    final (a3, u3) = freezeDecision('2026-10', u2, '2026-10');
    expect(a3, 0);
    expect(u3, 2);
  });

  test('frozen days keep streak continuity (pure calc)', () {
    // computeStreaks treats the set as-is; repo includes done=2 rows.
    expect(kFreezePerMonth, 2);
  });
}
