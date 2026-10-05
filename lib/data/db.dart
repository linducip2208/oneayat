// SQLite layer (sqflite). v2: readings-aware schema.
// NEVER deletes user data in migrations. Every Quran query respects reading_id.
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../core/surah_metadata.dart';
import '../quran/readings.dart';
import 'seed_data.dart';

class QuranDatabase {
  static const _name = 'oneayat.db';
  static const version = 2;
  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final path = p.join(dir, _name);
    final opened = await openDatabase(
      path,
      version: version,
      onCreate: (d, v) async {
        await _createV1(d);
        await _createV2(d);
        await _seedIfNeeded(d);
        await _seedV2(d);
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) {
          await _createV2(d);
          await _migrateV1toV2(d);
        }
      },
    );
    _db = opened;
    await _seedIfNeeded(opened);
    await _seedV2(opened);
    return opened;
  }

  // ---------- v1 tables (kept intact) ----------
  Future<void> _createV1(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS surahs(
      number INTEGER PRIMARY KEY, latin TEXT NOT NULL, arabic TEXT NOT NULL,
      ayahs INTEGER NOT NULL, revelation TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS ayahs(
      surah INTEGER NOT NULL, ayah INTEGER NOT NULL, juz INTEGER NOT NULL,
      arabic TEXT NOT NULL, PRIMARY KEY(surah, ayah))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS translation_languages(
      code TEXT PRIMARY KEY, language TEXT NOT NULL, title TEXT NOT NULL,
      license TEXT NOT NULL, version TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS translations(
      surah INTEGER NOT NULL, ayah INTEGER NOT NULL, lang TEXT NOT NULL,
      source TEXT NOT NULL, text TEXT NOT NULL,
      PRIMARY KEY(surah, ayah, lang))''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tr_lang ON translations(lang)');
    await db.execute('''CREATE TABLE IF NOT EXISTS bookmark_folders(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bookmarks(
      id INTEGER PRIMARY KEY AUTOINCREMENT, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
      folder_id INTEGER, favorite INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,
      UNIQUE(surah, ayah, folder_id))''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bm_ref ON bookmarks(surah, ayah)');
    await db.execute('''CREATE TABLE IF NOT EXISTS notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
      text TEXT NOT NULL, updated_at INTEGER NOT NULL, UNIQUE(surah, ayah))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS reading_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
      date TEXT NOT NULL, opened_at INTEGER NOT NULL)''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hist_date ON reading_history(date)');
    await db.execute('''CREATE TABLE IF NOT EXISTS daily_progress(
      date TEXT PRIMARY KEY, surah INTEGER NOT NULL, ayah INTEGER NOT NULL, done INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS streaks(
      id INTEGER PRIMARY KEY CHECK(id=1), current INTEGER NOT NULL DEFAULT 0,
      longest INTEGER NOT NULL DEFAULT 0, last_date TEXT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS settings(
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS audio_metadata(
      surah INTEGER NOT NULL, ayah INTEGER NOT NULL, reciter TEXT NOT NULL,
      local_path TEXT, duration_ms INTEGER, PRIMARY KEY(surah, ayah, reciter))''');
    final s = await db.query('streaks', where: 'id=1', limit: 1);
    if (s.isEmpty) {
      await db.insert('streaks', {'id': 1, 'current': 0, 'longest': 0, 'last_date': null});
    }
  }

  // ---------- v2 tables ----------
  Future<void> _createV2(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS quran_readings(
      id TEXT PRIMARY KEY, code TEXT NOT NULL, name TEXT NOT NULL,
      script TEXT NOT NULL, riwayah TEXT NOT NULL, description TEXT NOT NULL,
      source TEXT NOT NULL, version TEXT NOT NULL, license TEXT NOT NULL,
      font_family TEXT, is_default INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS ayah_texts(
      reading_id TEXT NOT NULL, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
      arabic TEXT NOT NULL, tajwid TEXT, normalized TEXT,
      page INTEGER, juz INTEGER NOT NULL,
      PRIMARY KEY(reading_id, surah, ayah))''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_atext_reading ON ayah_texts(reading_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_atext_ar ON ayah_texts(reading_id, arabic)');
    await db.execute('''CREATE TABLE IF NOT EXISTS reciters(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, language TEXT NOT NULL DEFAULT '',
      country TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '',
      image_url TEXT, source TEXT NOT NULL, license TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS reciter_readings(
      reciter_id TEXT NOT NULL, reading_id TEXT NOT NULL,
      PRIMARY KEY(reciter_id, reading_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS audio_files(
      reading_id TEXT NOT NULL, reciter_id TEXT NOT NULL,
      surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
      remote_url TEXT, local_path TEXT, file_size INTEGER,
      downloaded_bytes INTEGER NOT NULL DEFAULT 0,
      checksum TEXT, duration_ms INTEGER, version TEXT,
      status TEXT NOT NULL DEFAULT 'notDownloaded', progress INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(reading_id, reciter_id, surah, ayah))''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audio_reciter ON audio_files(reciter_id, reading_id)');
    await db.execute('''CREATE TABLE IF NOT EXISTS tafsirs(
      surah INTEGER NOT NULL, ayah INTEGER NOT NULL, lang TEXT NOT NULL,
      scholar TEXT NOT NULL, title TEXT NOT NULL, text TEXT NOT NULL,
      source TEXT NOT NULL, version TEXT NOT NULL, license TEXT NOT NULL,
      PRIMARY KEY(surah, ayah, lang))''');
    // translation attribution columns (nullable — legacy rows keep working)
    await _addColumn(db, 'translations', 'translator', 'TEXT');
    await _addColumn(db, 'translations', 'tversion', 'TEXT');
    await _addColumn(db, 'translations', 'tlicense', 'TEXT');
  }

  Future<void> _addColumn(Database db, String table, String col, String type) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      if (info.any((c) => c['name'] == col)) return;
      await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
    } catch (_) {}
  }

  /// v1 -> v2 data migration: register readings, carry bundled Hafs text into
  /// ayah_texts VERBATIM. Warsh gets ZERO rows (licensed asset required).
  /// User tables untouched.
  Future<void> _migrateV1toV2(Database db) async {
    await _seedReadings(db);
    final existing = await db.rawQuery(
        'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=?', ['hafs-madinah']);
    if (((existing.first['c'] as int?) ?? 0) > 0) return;
    final rows = await db.query('ayahs');
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('ayah_texts', {
        'reading_id': 'hafs-madinah',
        'surah': r['surah'], 'ayah': r['ayah'],
        'arabic': r['arabic'], 'tajwid': r['arabic'],
        'normalized': null, 'page': null, 'juz': r['juz'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedReadings(Database db) async {
    for (final r in kQuranReadings) {
      await db.insert('quran_readings', {
        'id': r.id, 'code': r.code, 'name': r.name, 'script': r.script,
        'riwayah': r.riwayah, 'description': r.description,
        'source': r.source, 'version': r.version, 'license': r.license,
        'font_family': null, 'is_default': r.isDefault ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedV2(Database db) async {
    await _seedReadings(db);
    final c = await db.rawQuery(
        'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=?', ['hafs-madinah']);
    if (((c.first['c'] as int?) ?? 0) == 0) {
      final batch = db.batch();
      for (final d in buildSeedDetails()) {
        batch.insert('ayah_texts', {
          'reading_id': 'hafs-madinah',
          'surah': d.surah, 'ayah': d.ayah,
          'arabic': d.arabic, 'tajwid': d.arabic,
          'normalized': null, 'page': null, 'juz': d.juz,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> _seedIfNeeded(Database db) async {
    final count =
        (await db.rawQuery('SELECT COUNT(*) c FROM surahs')).first['c'] as int;
    if (count >= 114) return;
    final batch = db.batch();
    for (final s in kSurahs) {
      batch.insert('surahs', {
        'number': s.number, 'latin': s.latin, 'arabic': s.arabic,
        'ayahs': s.ayahs, 'revelation': s.revelation,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final t in kTranslationSources) {
      batch.insert('translation_languages', {
        'code': t.code, 'language': t.language, 'title': t.title,
        'license': t.license, 'version': t.version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final d in buildSeedDetails()) {
      batch.insert('ayahs', {
        'surah': d.surah, 'ayah': d.ayah, 'juz': d.juz, 'arabic': d.arabic,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (d.idTranslation != null) {
        batch.insert('translations', {
          'surah': d.surah, 'ayah': d.ayah, 'lang': 'id',
          'source': 'id_sample', 'text': d.idTranslation!,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (d.enTranslation != null) {
        batch.insert('translations', {
          'surah': d.surah, 'ayah': d.ayah, 'lang': 'en',
          'source': 'en_sample', 'text': d.enTranslation!,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (d.transliteration != null) {
        batch.insert('translations', {
          'surah': d.surah, 'ayah': d.ayah, 'lang': 'tr',
          'source': 'tr_sample', 'text': d.transliteration!,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Startup integrity check per reading + legacy tables.
  Future<DbHealth> checkHealth() async {
    final d = await db;
    final issues = <String>[];
    final surahs = await d.query('surahs');
    if (surahs.length != 114) issues.add('surahs=${surahs.length}, expected 114');
    for (final row in surahs) {
      final n = row['number'] as int;
      if (n < 1 || n > 114) {
        issues.add('invalid surah number $n');
      } else if ((row['ayahs'] as int) <= 0) {
        issues.add('surah $n has no ayah count');
      }
    }
    int hafsCount = 0, warshCount = 0;
    try {
      hafsCount = ((await d.rawQuery(
              'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=?', ['hafs-madinah']))
          .first['c'] as int?) ?? 0;
      warshCount = ((await d.rawQuery(
              'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=?', ['warsh-madinah']))
          .first['c'] as int?) ?? 0;
    } catch (e) {
      issues.add('ayah_texts missing: $e');
    }
    final ayahRows = await d.rawQuery('SELECT COUNT(*) c FROM ayahs');
    final ayahCount = (ayahRows.first['c'] as int?) ?? 0;
    final langs = await d.query('translation_languages');
    if (langs.isEmpty) issues.add('no translation languages');
    return DbHealth(
      surahCount: surahs.length,
      seededAyahCount: ayahCount,
      languageCount: langs.length,
      issues: issues,
      fullCoverage: ayahCount >= 6236 || hafsCount >= 6236,
      hafsAyahCount: hafsCount,
      warshAyahCount: warshCount,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class DbHealth {
  final int surahCount;
  final int seededAyahCount;
  final int languageCount;
  final List<String> issues;
  final bool fullCoverage;
  final int hafsAyahCount;
  final int warshAyahCount;
  const DbHealth({
    required this.surahCount,
    required this.seededAyahCount,
    required this.languageCount,
    required this.issues,
    required this.fullCoverage,
    this.hafsAyahCount = 0,
    this.warshAyahCount = 0,
  });
  bool get ok => issues.isEmpty;
}
