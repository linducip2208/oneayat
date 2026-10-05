// Repository: reading-aware Quran reads (lazy, indexed). Never mixes readings.
// Bookmark identity stays (surah, ayah) so it survives Hafs<->Warsh switches.
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/surah_metadata.dart';
import 'db.dart';
import 'models.dart';
import 'seed_data.dart';

class QuranRepository {
  final QuranDatabase qdb;
  QuranRepository(this.qdb);

  Future<Database> get _d async => qdb.db;

  Future<List<Map<String, Object?>>> surahList() async {
    final d = await _d;
    return d.query('surahs', orderBy: 'number ASC');
  }

  Future<List<Map<String, Object?>>> readingRows() async {
    final d = await _d;
    try {
      return await d.query('quran_readings', orderBy: 'is_default DESC');
    } catch (_) {
      return [];
    }
  }

  Future<int> ayahCountFor(String readingId, int surah) async {
    final d = await _d;
    try {
      final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=? AND surah=?',
        [readingId, surah]);
      final c = (r.first['c'] as int?) ?? 0;
      if (c > 0) return c;
    } catch (_) {}
    if (readingId == 'hafs-madinah') {
      return buildSeedDetails().where((e) => e.surah == surah).length;
    }
    return 0;
  }

  Future<List<AyahDetail>> ayahsOfSurah(int surah,
      {String readingId = 'hafs-madinah', String lang = 'id'}) async {
    final d = await _d;
    List<Map<String, Object?>> rows = [];
    try {
      rows = await d.query('ayah_texts',
          where: 'reading_id=? AND surah=?',
          whereArgs: [readingId, surah],
          orderBy: 'ayah ASC');
    } catch (_) {}
    if (rows.isEmpty && readingId == 'hafs-madinah') {
      // legacy seed fast-path (verbatim Hafs sample)
      final seeded =
          buildSeedDetails().where((e) => e.surah == surah).toList()
            ..sort((a, b) => a.ayah.compareTo(b.ayah));
      return seeded;
    }
    final out = <AyahDetail>[];
    for (final r in rows) {
      final a = r['ayah'] as int;
      out.add(AyahDetail(
        surah: surah,
        ayah: a,
        juz: (r['juz'] as int?) ?? juzFor(surah, a),
        page: r['page'] as int?,
        readingId: readingId,
        arabic: r['arabic'] as String,
        tajwid: r['tajwid'] as String?,
        transliteration: await _tr(d, surah, a, 'tr'),
        idTranslation:
            lang == 'id' ? await _tr(d, surah, a, 'id') : await _tr(d, surah, a, 'id'),
        enTranslation: await _tr(d, surah, a, 'en'),
        tafsir: await _tafsir(d, surah, a, lang),
      ));
    }
    return out;
  }

  Future<String?> _tr(Database d, int s, int a, String lang) async {
    try {
      final r = await d.query('translations',
          where: 'surah=? AND ayah=? AND lang=?',
          whereArgs: [s, a, lang],
          limit: 1);
      return r.isEmpty ? null : r.first['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tafsir(Database d, int s, int a, String lang) async {
    try {
      final r = await d.query('tafsirs',
          where: 'surah=? AND ayah=? AND lang=?',
          whereArgs: [s, a, lang],
          limit: 1);
      return r.isEmpty ? null : r.first['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> tafsirScholar(Database d, int s, int a, String lang) async {
    try {
      final r = await d.query('tafsirs',
          where: 'surah=? AND ayah=? AND lang=?',
          whereArgs: [s, a, lang],
          limit: 1);
      return r.isEmpty ? null : r.first['scholar'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Detail for (surah, ayah) in [readingId]. Returns null when the reading
  /// has no text for this ayah (honest empty state — NEVER falls back to
  /// another reading's text).
  Future<AyahDetail?> ayahDetail(int surah, int ayah,
      {String readingId = 'hafs-madinah', String lang = 'id'}) async {
    final d = await _d;
    try {
      final r = await d.query('ayah_texts',
          where: 'reading_id=? AND surah=? AND ayah=?',
          whereArgs: [readingId, surah, ayah],
          limit: 1);
      if (r.isNotEmpty) {
        final row = r.first;
        return AyahDetail(
          surah: surah,
          ayah: ayah,
          juz: (row['juz'] as int?) ?? juzFor(surah, ayah),
          page: row['page'] as int?,
          readingId: readingId,
          arabic: row['arabic'] as String,
          tajwid: row['tajwid'] as String?,
          transliteration: await _tr(d, surah, ayah, 'tr'),
          idTranslation: await _tr(d, surah, ayah, 'id'),
          enTranslation: await _tr(d, surah, ayah, 'en'),
          tafsir: await _tafsir(d, surah, ayah, lang),
          tafsirScholar: await tafsirScholar(d, surah, ayah, lang),
        );
      }
    } catch (_) {}
    if (readingId == 'hafs-madinah') {
      for (final s in kSeedAyahs) {
        if (s.$1 == surah && s.$2 == ayah) {
          return AyahDetail(
            surah: surah,
            ayah: ayah,
            juz: juzFor(surah, ayah),
            readingId: readingId,
            arabic: s.$3,
            tajwid: s.$3,
            transliteration: s.$4,
            idTranslation: s.$5,
            enTranslation: s.$6,
          );
        }
      }
    }
    return null;
  }

  /// Search respects reading for Arabic + selected translation language.
  Future<List<AyahDetail>> search(String q,
      {String readingId = 'hafs-madinah', String lang = 'id', int limit = 50}) async {
    q = q.trim();
    if (q.isEmpty) return [];
    final qLower = q.toLowerCase();
    final surahHits = kSurahs
        .where((s) =>
            s.latin.toLowerCase().contains(qLower) || q == '${s.number}')
        .toList();
    final out = <AyahDetail>[];
    bool addUnique(AyahDetail det) {
      if (out.length >= limit) return false;
      if (out.any((e) => e.surah == det.surah && e.ayah == det.ayah)) {
        return true;
      }
      out.add(det);
      return true;
    }

    if (readingId == 'hafs-madinah') {
      for (final s in kSeedAyahs) {
        if (out.length >= limit) break;
        final hayId = s.$5.toLowerCase();
        final hayEn = s.$6.toLowerCase();
        final hayTr = lang == 'en' ? hayEn : hayId;
        if (s.$3.contains(q) || hayTr.contains(qLower)) {
          addUnique(AyahDetail(
            surah: s.$1,
            ayah: s.$2,
            juz: juzFor(s.$1, s.$2),
            readingId: readingId,
            arabic: s.$3,
            tajwid: s.$3,
            transliteration: s.$4,
            idTranslation: s.$5,
            enTranslation: s.$6,
          ));
        }
      }
    }
    // DB: Arabic within current reading only.
    try {
      final d = await _d;
      final rows = await d.rawQuery(
        'SELECT surah, ayah FROM ayah_texts WHERE reading_id=? AND arabic LIKE ? LIMIT ?',
        [readingId, '%$q%', limit],
      );
      for (final r in rows) {
        if (out.length >= limit) break;
        final det = await ayahDetail(r['surah'] as int, r['ayah'] as int,
            readingId: readingId, lang: lang);
        if (det != null) addUnique(det);
      }
      // DB: translation in selected language only.
      final trs = await d.rawQuery(
        'SELECT surah, ayah FROM translations WHERE lang=? AND text LIKE ? LIMIT ?',
        [lang, '%$q%', limit],
      );
      for (final r in trs) {
        if (out.length >= limit) break;
        final det = await ayahDetail(r['surah'] as int, r['ayah'] as int,
            readingId: readingId, lang: lang);
        if (det != null) addUnique(det);
      }
    } catch (_) {}
    for (final s in surahHits) {
      if (out.length >= limit) break;
      final det = await ayahDetail(s.number, 1, readingId: readingId, lang: lang);
      if (det != null) addUnique(det);
    }
    return out.take(limit).toList();
  }

  /// Daily identity is (surah, ayah) — stable across reading switches.
  Future<AyahRef> dailyRef(DateTime dateUtc, {required bool fullCoverage}) async {
    if (fullCoverage) {
      final g = AppConstants.dailyGlobalIndexFor(dateUtc);
      final (s, a) = AppConstants.globalIndexToRef(g);
      return AyahRef(s, a);
    }
    final keys = seedKeys.toList()..sort();
    final day = AppConstants.dayIndexFor(dateUtc);
    final pick = keys[((day % keys.length) + keys.length) % keys.length];
    final parts = pick.split(':');
    return AyahRef(int.parse(parts[0]), int.parse(parts[1]));
  }

  String surahName(int n) =>
      (n >= 1 && n <= 114) ? kSurahs[n - 1].latin : 'Surah $n';
}
