// Quran readings catalog (pure Dart — testable, no plugins).
//
// Two Madinah-oriented readings: Hafs 'an Asim (default) and Warsh 'an Nafi'.
// The catalog NEVER invents Quran text: a reading row may exist with zero
// bundled ayahs ("licensed asset required") — repository then shows an honest
// empty state instead of mixing texts across readings.

class QuranReading {
  final String id; // e.g. 'hafs-madinah'
  final String code;
  final String name;
  final String script; // e.g. 'Madinah Uthmani'
  final String riwayah; // 'Hafs' | 'Warsh'
  final String description;
  final String source;
  final String version;
  final String license;
  final bool isDefault;
  const QuranReading({
    required this.id,
    required this.code,
    required this.name,
    required this.script,
    required this.riwayah,
    required this.description,
    required this.source,
    required this.version,
    required this.license,
    required this.isDefault,
  });
}

const List<QuranReading> kQuranReadings = [
  QuranReading(
    id: 'hafs-madinah',
    code: 'hafs',
    name: 'Madinah — Hafs Tajwid',
    script: 'Madinah Uthmani',
    riwayah: 'Hafs',
    description: "Hafs 'an Asim with tajwid marks, Madinah-oriented layout.",
    source: 'ONE AYAT bundled sample (Hafs text)',
    version: '1.0',
    license: 'Quran text — free to distribute; font asset replaceable (see mushaf_config)',
    isDefault: true,
  ),
  QuranReading(
    id: 'warsh-madinah',
    code: 'warsh',
    name: 'Madinah — Warsh Tajwid',
    script: 'Madinah Uthmani (Warsh)',
    riwayah: 'Warsh',
    description: "Warsh 'an Nafi' with tajwid marks, Madinah-oriented layout.",
    source: 'Licensed Warsh dataset required (not bundled)',
    version: '0',
    license: 'Import a licensed Warsh dataset via tools/import_quran.dart --reading warsh-madinah',
    isDefault: false,
  ),
];

String defaultReadingId() =>
    kQuranReadings.firstWhere((r) => r.isDefault).id;

bool isKnownReading(String id) => kQuranReadings.any((r) => r.id == id);

/// Storage layout (pure — unit tested):
/// `audio/reading/reciter/surah3/ayah3.mp3`
String audioRelativePath({
  required String readingId,
  required String reciterId,
  required int surah,
  required int ayah,
}) {
  final s = surah.toString().padLeft(3, '0');
  final a = ayah.toString().padLeft(3, '0');
  final safeReciter = reciterId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final safeReading = readingId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return 'audio/$safeReading/$safeReciter/$s/$a.mp3';
}

/// Ayah end marker (U+06DD ARABIC END OF AYAH) — decorative only,
/// never part of stored Quran text.
String ayahMarker(int ayah) => '\u06DD${_arabicDigits(ayah)}';

String _arabicDigits(int n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}
