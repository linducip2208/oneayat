import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/services/prayer_times.dart';

void main() {
  PrayerDay jakarta(DateTime day) => computePrayerDay(
        localDay: day,
        lat: -6.20,
        lon: 106.85,
        method: prayerMethodById('kemenag'),
        tzOffsetHours: 7.0,
      );

  test('Jakarta ordering sane', () {
    final p = jakarta(DateTime(2026, 10, 5));
    expect(p.fajr.isBefore(p.sunrise), isTrue);
    expect(p.sunrise.isBefore(p.dhuhr), isTrue);
    expect(p.dhuhr.isBefore(p.asr), isTrue);
    expect(p.asr.isBefore(p.maghrib), isTrue);
    expect(p.maghrib.isBefore(p.isha), isTrue);
  });

  test('Jakarta Oct times roughly correct (Kemenag)', () {
    final p = jakarta(DateTime(2026, 10, 5));
    int mins(DateTime t) => t.hour * 60 + t.minute;
    // Known approx: Subuh ~04:30, Zuhur ~11:40, Magrib ~17:50 (WIB, Oct)
    expect((mins(p.fajr) - (4 * 60 + 30)).abs(), lessThan(25));
    expect((mins(p.dhuhr) - (11 * 60 + 40)).abs(), lessThan(25));
    expect((mins(p.maghrib) - (17 * 60 + 50)).abs(), lessThan(25));
  });

  test('methods differ in fajr', () {
    final a = computePrayerDay(
        localDay: DateTime(2026, 10, 5),
        lat: -6.20,
        lon: 106.85,
        method: prayerMethodById('kemenag'),
        tzOffsetHours: 7.0);
    final b = computePrayerDay(
        localDay: DateTime(2026, 10, 5),
        lat: -6.20,
        lon: 106.85,
        method: prayerMethodById('isna'),
        tzOffsetHours: 7.0);
    expect(a.fajr.isBefore(b.fajr), isTrue); // 20° earlier than 15°
  });

  test('nextFrom finds upcoming prayer', () {
    final p = jakarta(DateTime(2026, 10, 5));
    final n = p.nextFrom(DateTime(2026, 10, 5, 10, 0));
    expect(n?.$1, 'dhuhr');
    expect(p.nextFrom(DateTime(2026, 10, 5, 23, 0)), isNull);
  });

  test('nearestCity finds Jakarta for Jakarta fix', () {
    expect(nearestCity(-6.21, 106.85).name, 'Jakarta');
    expect(nearestCity(-7.27, 112.74).name, 'Surabaya');
    expect(nearestCity(5.54, 95.31).name, 'Banda Aceh');
  });

  test('city catalog covers Indonesia + valid coords', () {    expect(kPrayerCities.length, greaterThanOrEqualTo(10));
    for (final c in kPrayerCities) {
      expect(c.lat, inInclusiveRange(-11, 6));
      expect(c.lon, inInclusiveRange(95, 141));
    }
  });
}
