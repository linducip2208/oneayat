// Offline prayer-time calculation (pure Dart, no plugins, no network).
// Standard astronomical formulas: solar declination + equation of time from
// Julian date, hour angles per twilight angle / shadow factor.
// Methods differ only in angles — math itself is universal and testable.

import 'dart:math' as math;

class PrayerMethod {
  final String id;
  final String name;
  final double fajrAngle;
  final double ishaAngle;
  final double asrFactor; // 1 = Syafii/Maliki/Hambali, 2 = Hanafi
  const PrayerMethod(this.id, this.name, this.fajrAngle, this.ishaAngle,
      [this.asrFactor = 1.0]);
}

const List<PrayerMethod> kPrayerMethods = [
  PrayerMethod('kemenag', 'Kemenag Indonesia (20°/18°)', 20.0, 18.0),
  PrayerMethod('mwl', 'Muslim World League (18°/17°)', 18.0, 17.0),
  PrayerMethod('isna', 'ISNA Amerika (15°/15°)', 15.0, 15.0),
  PrayerMethod('egypt', 'Mesir (19.5°/17.5°)', 19.5, 17.5),
  PrayerMethod('karachi', 'Karachi (18°/18°)', 18.0, 18.0),
];

PrayerMethod prayerMethodById(String id) =>
    kPrayerMethods.where((m) => m.id == id).firstOrNull ?? kPrayerMethods.first;

/// City catalog so no location permission is needed (privacy-first).
class PrayerCity {
  final String name;
  final double lat;
  final double lon;
  const PrayerCity(this.name, this.lat, this.lon);
}

const List<PrayerCity> kPrayerCities = [
  PrayerCity('Jakarta', -6.20, 106.85),
  PrayerCity('Bandung', -6.91, 107.61),
  PrayerCity('Semarang', -6.97, 110.42),
  PrayerCity('Yogyakarta', -7.80, 110.37),
  PrayerCity('Surabaya', -7.26, 112.75),
  PrayerCity('Denpasar', -8.67, 115.22),
  PrayerCity('Medan', 3.59, 98.67),
  PrayerCity('Padang', -0.95, 100.35),
  PrayerCity('Pekanbaru', 0.51, 101.45),
  PrayerCity('Palembang', -2.99, 104.76),
  PrayerCity('Banda Aceh', 5.55, 95.32),
  PrayerCity('Banjarmasin', -3.32, 114.59),
  PrayerCity('Balikpapan', -1.27, 116.83),
  PrayerCity('Makassar', -5.15, 119.41),
  PrayerCity('Manado', 1.47, 124.84),
  PrayerCity('Mataram', -8.58, 116.12),
  PrayerCity('Kupang', -10.18, 123.58),
  PrayerCity('Jayapura', -2.53, 140.72),
];

class PrayerDay {
  final DateTime date; // local calendar day
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  const PrayerDay({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  DateTime timeOf(String key) => switch (key) {
        'fajr' => fajr,
        'sunrise' => sunrise,
        'dhuhr' => dhuhr,
        'asr' => asr,
        'maghrib' => maghrib,
        'isha' => isha,
        _ => dhuhr,
      };

  /// Next upcoming prayer (or fajr tomorrow style wrap handled by caller).
  (String key, DateTime at)? nextFrom(DateTime now) {
    const order = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (final k in order) {
      final t = timeOf(k);
      if (!t.isBefore(now)) return (k, t);
    }
    return null;
  }
}

const List<String> kAdhanKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/// Nearest catalog city to a GPS fix (haversine, pure — testable).
PrayerCity nearestCity(double lat, double lon) {
  PrayerCity best = kPrayerCities.first;
  var bestD = double.infinity;
  for (final c in kPrayerCities) {
    final dLat = (c.lat - lat) * math.pi / 180.0;
    final dLon = (c.lon - lon) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat * math.pi / 180.0) *
            math.cos(c.lat * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final d = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    if (d < bestD) {
      bestD = d;
      best = c;
    }
  }
  return best;
}

String prayerName(String key, String lang) {
  const id = {
    'fajr': 'Subuh',
    'sunrise': 'Terbit',
    'dhuhr': 'Zuhur',
    'asr': 'Asar',
    'maghrib': 'Magrib',
    'isha': 'Isya',
  };
  const en = {
    'fajr': 'Fajr',
    'sunrise': 'Sunrise',
    'dhuhr': 'Dhuhr',
    'asr': 'Asr',
    'maghrib': 'Maghrib',
    'isha': 'Isha',
  };
  return (lang == 'en' ? en : id)[key] ?? key;
}

/// Compute all prayer times for a LOCAL calendar day.
/// [tzOffsetHours] = device offset, e.g. DateTime.now().timeZoneOffset.
PrayerDay computePrayerDay({
  required DateTime localDay,
  required double lat,
  required double lon,
  required PrayerMethod method,
  required double tzOffsetHours,
  double elevationMeters = 0,
}) {
  final y = localDay.year, m = localDay.month, d = localDay.day;
  final jd = _julianDate(y, m, d) - lon / 360.0;
  final decl = _sunDeclination(jd);
  final eqt = _equationOfTime(jd);

  double timeFor(double angleDeg, bool afterNoon) {
    final t = _hourAngle(lat, decl, angleDeg, afterNoon);
    return _toLocal(t, lon, eqt, tzOffsetHours);
  }

  final dhuhrH = _toLocal(12.0, lon, eqt, tzOffsetHours);
  final asrH = _toLocal(
      _asrTime(lat, decl, method.asrFactor), lon, eqt, tzOffsetHours);
  // Sunrise/sunset with slight elevation correction.
  final riseAngle = 0.833 + 0.0347 * math.sqrt(math.max(0, elevationMeters));
  DateTime at(double h) => _atLocal(y, m, d, h);

  return PrayerDay(
    date: DateTime(y, m, d),
    fajr: at(timeFor(-method.fajrAngle, false)),
    sunrise: at(timeFor(-riseAngle, false)),
    dhuhr: at(dhuhrH + 2 / 60), // +2 min ihtiyati
    asr: at(asrH),
    maghrib: at(timeFor(-riseAngle, true) + 2 / 60),
    isha: at(timeFor(-method.ishaAngle, true)),
  );
}

double _julianDate(int y, int m, int d) {
  var yy = y, mm = m;
  if (mm <= 2) {
    yy -= 1;
    mm += 12;
  }
  final a = (yy / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (yy + 4716)).floor() +
      (30.6001 * (mm + 1)).floor() +
      d +
      b -
      1524.5;
}

double _sunDeclination(double jd) {
  final d = jd - 2451543.5;
  final g = _fixAngle(357.529 + 0.98560028 * d);
  final q = _fixAngle(280.459 + 0.98564736 * d);
  final l = _fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
  const e = 23.439 - 0.00000036 * 0; // mean obliquity (d-term negligible here)
  final dd = _asin(_sin(e) * _sin(l));
  return dd;
}

double _equationOfTime(double jd) {
  final d = jd - 2451543.5;
  final g = _fixAngle(357.529 + 0.98560028 * d);
  final q = _fixAngle(280.459 + 0.98564736 * d);
  final l = _fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
  const e = 23.439;
  final ra = _atan2(_cos(e) * _sin(l), _cos(l)) / 15.0;
  return q / 15.0 - _fixHour(ra);
}

/// Hour angle in hours for [angleDeg] (negative = below horizon).
double _hourAngle(
    double lat, double decl, double angleDeg, bool afterNoon) {
  final num =
      _sin(angleDeg) - _sin(lat) * _sin(decl);
  final den = _cos(lat) * _cos(decl);
  final v = (num / den).clamp(-1.0, 1.0);
  final ha = _acos(v) / 15.0;
  return afterNoon ? 12.0 + ha : 12.0 - ha;
}

/// Asr time (hours from midnight UTC-base) via shadow factor.
double _asrTime(double lat, double decl, double factor) {
  final angle = _atan(1.0 / (factor + _tan((lat - decl).abs())));
  final ha = _acos(
          ((_sin(angle) - _sin(lat) * _sin(decl)) /
                  (_cos(lat) * _cos(decl)))
              .clamp(-1.0, 1.0)) /
      15.0;
  return 12.0 + ha;
}

double _toLocal(double baseHour, double lon, double eqt, double tz) =>
    baseHour + tz - lon / 15.0 - eqt;

DateTime _atLocal(int y, int m, int d, double h) {
  final hh = h.floor();
  final mm = ((h - hh) * 60).floor();
  return DateTime(y, m, d, hh % 24, mm % 60).add(
      h < 0 || h >= 24 ? Duration(days: h < 0 ? -1 : 1) : Duration.zero);
}

double _fixAngle(double a) => a - 360.0 * (a / 360.0).floor();
double _fixHour(double a) => a - 24.0 * (a / 24.0).floor();
double _sin(double d) => math.sin(d * math.pi / 180.0);
double _cos(double d) => math.cos(d * math.pi / 180.0);
double _tan(double d) => math.tan(d * math.pi / 180.0);
double _asin(double x) => math.asin(x) * 180.0 / math.pi;
double _acos(double x) => math.acos(x) * 180.0 / math.pi;
double _atan(double x) => math.atan(x) * 180.0 / math.pi;
double _atan2(double y, double x) =>
    math.atan2(y, x) * 180.0 / math.pi;
