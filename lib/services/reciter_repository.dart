// Reciter catalog + audio-file state, backed by SQLite.
// Only reciter x reading combinations present in reciter_readings are shown.
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/models.dart';

class ReciterRepository {
  final QuranDatabase qdb;
  ReciterRepository(this.qdb);
  Future<Database> get _d async => qdb.db;

  /// Exposed for storage maintenance (delete/reset only — never user tables).
  Future<Database> dbForMaintenance() async => qdb.db;

  Future<List<ReciterInfo>> recitersFor(String readingId) async {
    final d = await _d;
    try {
      final rows = await d.rawQuery('''
        SELECT r.* FROM reciters r
        INNER JOIN reciter_readings rr
          ON rr.reciter_id = r.id AND rr.reading_id = ?
        ORDER BY r.name ASC''', [readingId]);
      return [
        for (final r in rows)
          ReciterInfo(
            id: r['id'] as String,
            name: r['name'] as String,
            language: (r['language'] as String?) ?? '',
            country: (r['country'] as String?) ?? '',
            description: (r['description'] as String?) ?? '',
            imageUrl: r['image_url'] as String?,
            source: (r['source'] as String?) ?? '',
            license: (r['license'] as String?) ?? '',
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> readingsForReciter(String reciterId) async {
    final d = await _d;
    try {
      final rows = await d.query('reciter_readings',
          where: 'reciter_id=?', whereArgs: [reciterId]);
      return [for (final r in rows) r['reading_id'] as String];
    } catch (_) {
      return [];
    }
  }

  Future<bool> isCompatible(String reciterId, String readingId) async {
    final d = await _d;
    try {
      final rows = await d.query('reciter_readings',
          where: 'reciter_id=? AND reading_id=?',
          whereArgs: [reciterId, readingId],
          limit: 1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> upsertReciter(ReciterInfo r, List<String> readingIds) async {
    final d = await _d;
    await d.insert('reciters', {
      'id': r.id, 'name': r.name, 'language': r.language,
      'country': r.country, 'description': r.description,
      'image_url': r.imageUrl, 'source': r.source, 'license': r.license,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await d.delete('reciter_readings', where: 'reciter_id=?', whereArgs: [r.id]);
    for (final rd in readingIds) {
      await d.insert('reciter_readings',
          {'reciter_id': r.id, 'reading_id': rd},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<AudioFileInfo?> audioState({
    required String readingId,
    required String reciterId,
    required int surah,
    required int ayah,
  }) async {
    final d = await _d;
    try {
      final rows = await d.query('audio_files',
          where: 'reading_id=? AND reciter_id=? AND surah=? AND ayah=?',
          whereArgs: [readingId, reciterId, surah, ayah],
          limit: 1);
      if (rows.isEmpty) return null;
      final r = rows.first;
      return AudioFileInfo(
        surah: surah, ayah: ayah, readingId: readingId, reciterId: reciterId,
        remoteUrl: r['remote_url'] as String?,
        localPath: r['local_path'] as String?,
        fileSize: r['file_size'] as int?,
        downloadedBytes: (r['downloaded_bytes'] as int?) ?? 0,
        checksum: r['checksum'] as String?,
        durationMs: r['duration_ms'] as int?,
        status: audioStatusFrom(r['status'] as String?),
        progress: (r['progress'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertAudio(AudioFileInfo a) async {
    final d = await _d;
    await d.insert('audio_files', {
      'reading_id': a.readingId, 'reciter_id': a.reciterId,
      'surah': a.surah, 'ayah': a.ayah,
      'remote_url': a.remoteUrl, 'local_path': a.localPath,
      'file_size': a.fileSize, 'downloaded_bytes': a.downloadedBytes,
      'checksum': a.checksum, 'duration_ms': a.durationMs,
      'version': null,
      'status': audioStatusName(a.status), 'progress': a.progress,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<(int ready, int total)> surahProgress({
    required String readingId,
    required String reciterId,
    required int surah,
    required int ayahCount,
  }) async {
    final d = await _d;
    try {
      final r = await d.rawQuery(
          "SELECT COUNT(*) c FROM audio_files WHERE reading_id=? AND reciter_id=? AND surah=? AND status='ready'",
          [readingId, reciterId, surah]);
      return (((r.first['c'] as int?) ?? 0), ayahCount);
    } catch (_) {
      return (0, ayahCount);
    }
  }

  Future<int> downloadedBytesForReciter(String reciterId) async {
    final d = await _d;
    try {
      final r = await d.rawQuery(
          "SELECT SUM(downloaded_bytes) s FROM audio_files WHERE reciter_id=? AND status='ready'",
          [reciterId]);
      return ((r.first['s'] as int?) ?? 0);
    } catch (_) {
      return 0;
    }
  }

  Future<List<AudioFileInfo>> incompleteDownloads() async {
    final d = await _d;
    try {
      final rows = await d.query('audio_files',
          where: "status IN ('queued','downloading','paused','failed')");
      return [
        for (final r in rows)
          AudioFileInfo(
            surah: r['surah'] as int, ayah: r['ayah'] as int,
            readingId: r['reading_id'] as String,
            reciterId: r['reciter_id'] as String,
            remoteUrl: r['remote_url'] as String?,
            localPath: r['local_path'] as String?,
            fileSize: r['file_size'] as int?,
            downloadedBytes: (r['downloaded_bytes'] as int?) ?? 0,
            checksum: r['checksum'] as String?,
            durationMs: r['duration_ms'] as int?,
            status: audioStatusFrom(r['status'] as String?),
            progress: (r['progress'] as int?) ?? 0,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteAudioForReciter(String reciterId, {String? readingId}) async {
    final d = await _d;
    await d.delete('audio_files',
        where: readingId == null
            ? 'reciter_id=?'
            : 'reciter_id=? AND reading_id=?',
        whereArgs:
            readingId == null ? [reciterId] : [reciterId, readingId]);
  }
}
