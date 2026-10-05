// User progress repository: history, daily done, streaks, notes, bookmarks.
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/models.dart';
import 'progress_logic.dart';

class ProgressRepository {
  final QuranDatabase qdb;
  ProgressRepository(this.qdb);
  Future<Database> get _d async => qdb.db;

  Future<void> markDailyDone(DateTime dateUtc, AyahRef ref) async {
    final d = await _d;
    final key = dateKey(DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day));
    await d.insert('daily_progress', {
      'date': key, 'surah': ref.surah, 'ayah': ref.ayah, 'done': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await d.insert('reading_history', {
      'surah': ref.surah, 'ayah': ref.ayah, 'date': key,
      'opened_at': DateTime.now().millisecondsSinceEpoch,
    });
    // Streak continuity includes frozen days (done=2); ayat count stays done=1.
    await _recomputeStreak(d, key);
  }

  Future<bool> isDailyDone(String key) async {
    final d = await _d;
    final r = await d.query('daily_progress',
        where: 'date=? AND done=1', whereArgs: [key], limit: 1);
    return r.isNotEmpty;
  }

  /// Freeze a missed day: done=2 keeps streak continuity without ayat count.
  Future<void> freezeDay(String key, AyahRef ref) async {
    final d = await _d;
    await d.insert('daily_progress', {
      'date': key, 'surah': ref.surah, 'ayah': ref.ayah, 'done': 2,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _recomputeStreak(d, key);
  }

  Future<void> _recomputeStreak(Database d, String key) async {
    final rows = await d.query('daily_progress',
        columns: ['date'], where: 'done IN (1,2)');
    final set = {for (final r in rows) r['date'] as String};
    final (current: cur, longest: lon) = computeStreaks(set, key);
    final prev = await d.query('streaks', where: 'id=1');
    final prevLongest = (prev.first['longest'] as int?) ?? 0;
    await d.update('streaks', {
      'current': cur,
      'longest': lon > prevLongest ? lon : prevLongest,
      'last_date': key,
    }, where: 'id=1');
  }

  Future<int> daysCompleted() async {
    final d = await _d;
    final r = await d.rawQuery('SELECT COUNT(*) c FROM daily_progress WHERE done=1');
    return ((r.first['c'] as int?) ?? 0);
  }

  Future<(int current, int longest)> streaks() async {
    final d = await _d;
    final r = await d.query('streaks', where: 'id=1', limit: 1);
    if (r.isEmpty) return (0, 0);
    return ((r.first['current'] as int?) ?? 0, (r.first['longest'] as int?) ?? 0);
  }

  Future<List<HistoryEntry>> history({int limit = 60}) async {
    final d = await _d;
    final rows = await d.query('reading_history', orderBy: 'opened_at DESC', limit: limit);
    return [
      for (final r in rows)
        HistoryEntry(
          id: r['id'] as int?, surah: r['surah'] as int, ayah: r['ayah'] as int,
          date: r['date'] as String, openedAt: r['opened_at'] as int,
        ),
    ];
  }

  // ---- bookmarks ----
  Future<List<BookmarkFolder>> folders() async {
    final d = await _d;
    var rows = await d.query('bookmark_folders', orderBy: 'created_at ASC');
    if (rows.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await d.insert('bookmark_folders', {'name': 'Favorites', 'created_at': now});
      rows = await d.query('bookmark_folders', orderBy: 'created_at ASC');
    }
    return [for (final r in rows) BookmarkFolder(id: r['id'] as int?, name: r['name'] as String, createdAt: r['created_at'] as int)];
  }

  Future<int> createFolder(String name) async {
    final d = await _d;
    return d.insert('bookmark_folders', {'name': name.trim(), 'created_at': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> renameFolder(int id, String name) async {
    final d = await _d;
    await d.update('bookmark_folders', {'name': name.trim()}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteFolder(int id) async {
    final d = await _d;
    await d.delete('bookmarks', where: 'folder_id=?', whereArgs: [id]);
    await d.delete('bookmark_folders', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Bookmark>> bookmarks({int? folderId}) async {
    final d = await _d;
    final rows = await d.query('bookmarks',
        where: folderId == null ? null : 'folder_id=?',
        whereArgs: folderId == null ? null : [folderId],
        orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        Bookmark(
          id: r['id'] as int?, surah: r['surah'] as int, ayah: r['ayah'] as int,
          folderId: r['folder_id'] as int?,
          favorite: ((r['favorite'] as int?) ?? 0) == 1,
          createdAt: r['created_at'] as int,
        ),
    ];
  }

  Future<bool> isBookmarked(int s, int a) async {
    final d = await _d;
    final r = await d.query('bookmarks', where: 'surah=? AND ayah=?', whereArgs: [s, a], limit: 1);
    return r.isNotEmpty;
  }

  Future<void> toggleBookmark(int s, int a, {int? folderId}) async {
    final d = await _d;
    final existing = await d.query('bookmarks', where: 'surah=? AND ayah=?', whereArgs: [s, a]);
    if (existing.isEmpty) {
      int? fid = folderId;
      fid ??= (await folders()).first.id;
      await d.insert('bookmarks', {
        'surah': s, 'ayah': a, 'folder_id': fid, 'favorite': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await d.delete('bookmarks', where: 'surah=? AND ayah=?', whereArgs: [s, a]);
    }
  }

  Future<void> moveBookmark(int id, int? folderId) async {
    final d = await _d;
    await d.update('bookmarks', {'folder_id': folderId}, where: 'id=?', whereArgs: [id]);
  }

  // ---- notes ----
  Future<String?> noteFor(int s, int a) async {
    final d = await _d;
    final r = await d.query('notes', where: 'surah=? AND ayah=?', whereArgs: [s, a], limit: 1);
    return r.isEmpty ? null : r.first['text'] as String?;
  }

  Future<void> saveNote(int s, int a, String text) async {
    final d = await _d;
    final t = text.trim();
    if (t.isEmpty) {
      await d.delete('notes', where: 'surah=? AND ayah=?', whereArgs: [s, a]);
      return;
    }
    await d.insert('notes', {
      'surah': s, 'ayah': a, 'text': t,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> noteCount() async {
    final d = await _d;
    final r = await d.rawQuery('SELECT COUNT(*) c FROM notes');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<Map<String, dynamic>> exportJson() async {
    final d = await _d;
    Future<List<Map<String, Object?>>> all(String t) => d.query(t);
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'bookmark_folders': await all('bookmark_folders'),
      'bookmarks': await all('bookmarks'),
      'notes': await all('notes'),
      'daily_progress': await all('daily_progress'),
      'reading_history': await all('reading_history'),
      'streaks': await all('streaks'),
      'settings': await all('settings'),
    };
  }

  Future<void> importJson(Map<String, dynamic> json) async {
    final d = await _d;
    await d.transaction((txn) async {
      for (final table in ['bookmark_folders', 'bookmarks', 'notes', 'daily_progress', 'reading_history', 'settings']) {
        final rows = (json[table] as List?) ?? [];
        for (final row in rows) {
          await txn.insert(table, Map<String, Object?>.from(row as Map),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
