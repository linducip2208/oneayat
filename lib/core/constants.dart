// ONE AYAT — core constants. Offline-first, no backend.
class AppConstants {
  static const String appName = 'ONE AYAT';
  static const String tagline = 'One Day. One Ayat.';
  static const String applicationId = 'com.oneayat.app';

  /// Total ayahs in Madani mushaf.
  static const int totalAyahs = 6236;

  /// Epoch for deterministic daily ayat (UTC). Do not change after release.
  static final DateTime epochUtc = DateTime.utc(2024, 1, 1);

  /// Madani ayah counts for surahs 1..114.
  static const List<int> ayahCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
    111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
    54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
    49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52,
    44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19,
    26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
    6, 3, 5, 4, 5, 6,
  ];

  /// Prefix sums: start index (0-based global) of each surah.
  static final List<int> surahStartIndex = _buildStarts();

  static List<int> _buildStarts() {
    final out = List<int>.filled(114, 0);
    var acc = 0;
    for (var i = 0; i < 114; i++) {
      out[i] = acc;
      acc += ayahCounts[i];
    }
    return out;
  }

  /// Map global 0-based index -> (surah, ayah). Both 1-based.
  static (int surah, int ayah) globalIndexToRef(int globalIndex) {
    var lo = 0, hi = 113;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final start = surahStartIndex[mid];
      final end = start + ayahCounts[mid];
      if (globalIndex < start) {
        hi = mid - 1;
      } else if (globalIndex >= end) {
        lo = mid + 1;
      } else {
        return (mid + 1, globalIndex - start + 1);
      }
    }
    return (114, 6);
  }

  static int refToGlobalIndex(int surah, int ayah) =>
      surahStartIndex[surah - 1] + (ayah - 1);

  /// Deterministic day index since epoch (UTC date only).
  static int dayIndexFor(DateTime dateUtc) {
    final d = DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);
    return d.difference(epochUtc).inDays;
  }

  /// Deterministic global ayah index for a date. Stable across releases.
  static int dailyGlobalIndexFor(DateTime dateUtc) {
    final day = dayIndexFor(dateUtc);
    final norm = ((day % totalAyahs) + totalAyahs) % totalAyahs;
    // Even spread stride (prime vs total) so consecutive days feel varied
    // yet deterministic, without randomness.
    const stride = 733;
    return (norm * stride) % totalAyahs;
  }
}
