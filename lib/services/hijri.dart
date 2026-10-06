// Tabular (arithmetical) Hijri calendar — pure Dart, offline.
// Approximation of ±1-2 days vs moon-sighting; used for Ramadan mode gating
// and khatam math, never for prayer times or religious rulings.
import 'dart:math' as math;

class HijriDate {
  final int year;
  final int month; // 1..12
  final int day;
  const HijriDate(this.year, this.month, this.day);
  bool get isRamadan => month == 9;
}

double _jdn(int y, int m, int d) {
  var yy = y, mm = m;
  if (mm <= 2) {
    yy -= 1;
    mm += 12;
  }
  final a = (yy / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (((yy + 4716) * 365.25).floor() +
          ((mm + 1) * 30.6001).floor() +
          d +
          b -
          1524.5);
}

/// Tabular leap year: 11 leaps in every 30 years.
bool hijriIsLeap(int year) => ((11 * year + 14) % 30) < 11;

int hijriMonthLength(int year, int month) {
  if (month == 12) return hijriIsLeap(year) ? 30 : 29;
  return month.isOdd ? 30 : 29;
}

/// JDN (noon-based) of 1 Muharram [year] (tabular).
double hijriYearStart(int year) =>
    1948439.5 +
    (year - 1) * 354 +
    ((3 + 11 * year) / 30).floor() -
    1;

/// Gregorian -> tabular Hijri (exact inverse of the forward function).
HijriDate gregorianToHijri(DateTime g) {
  final jd = _jdn(g.year, g.month, g.day).floor() + 0.5;
  var year = (30 * (jd - 1948439.5) / 10631).floor();
  while (jd < hijriYearStart(year)) {
    year--;
  }
  while (jd >= hijriYearStart(year + 1)) {
    year++;
  }
  var month = 1;
  var dayStart = hijriYearStart(year);
  while (month < 12) {
    final next = dayStart + hijriMonthLength(year, month);
    if (jd < next) break;
    dayStart = next;
    month++;
  }
  final day = (jd - dayStart).floor() + 1;
  return HijriDate(year, month, day);
}

/// Days of Ramadan elapsed (1..30) or 0 when not Ramadan.
int ramadanDay(DateTime g) {
  final h = gregorianToHijri(g);
  if (!h.isRamadan) return 0;
  return h.day;
}

/// Remaining Ramadan days including today (tabular 30-day month).
int ramadanRemaining(DateTime g) {
  final d = ramadanDay(g);
  if (d == 0) return 0;
  return math.max(1, 30 - d + 1);
}

/// Suggested ayat/day to khatam (6236) by end of Ramadan.
int khatamPerDay(int ayatRead, DateTime g) {
  final left = ramadanRemaining(g);
  if (left <= 0) return 0;
  return ((6236 - ayatRead) / left).ceil().clamp(1, 6236);
}
