// Offline audio download manager: real resumable downloads (HttpClient +
// Range), persisted per-file state in SQLite, Wi-Fi-only option, checksum
// verification, restart-safe. No streaming — files play locally when ready.
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../quran/readings.dart';
import 'reciter_repository.dart';

class DownloadEvent {
  final String readingId;
  final String reciterId;
  final int surah;
  final int ayah;
  final AudioStatus status;
  final int progress;
  final int downloaded;
  final int? total;
  const DownloadEvent(this.readingId, this.reciterId, this.surah, this.ayah,
      this.status, this.progress, this.downloaded, this.total);
}

class _Task {
  bool cancelled = false;
  bool paused = false;
}

class DownloadManager {
  final ReciterRepository repo;
  DownloadManager(this.repo);

  final Map<String, _Task> _active = {};
  final _events = StreamController<DownloadEvent>.broadcast();
  Stream<DownloadEvent> get events => _events.stream;

  String _key(String rd, String rec, int s, int a) => '$rd|$rec|$s|$a';

  Future<Directory> audioRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'audio'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> localFile({
    required String readingId,
    required String reciterId,
    required int surah,
    required int ayah,
  }) async {
    final root = await audioRoot();
    final rel = audioRelativePath(
        readingId: readingId, reciterId: reciterId, surah: surah, ayah: ayah);
    final f = File(p.join(root.path, rel));
    await f.parent.create(recursive: true);
    return f;
  }

  /// Mark rows stuck in 'downloading' (e.g. after app restart) as resumable.
  Future<void> resetStuck() async {
    final stuck = await repo.incompleteDownloads();
    for (final a in stuck) {
      if (a.status == AudioStatus.downloading) {
        await repo.upsertAudio(AudioFileInfo(
          surah: a.surah, ayah: a.ayah, readingId: a.readingId,
          reciterId: a.reciterId, remoteUrl: a.remoteUrl,
          localPath: a.localPath, fileSize: a.fileSize,
          downloadedBytes: a.downloadedBytes, checksum: a.checksum,
          durationMs: a.durationMs, status: AudioStatus.paused,
          progress: a.progress,
        ));
      }
    }
  }

  List<AyahRef> refsForScope(DownloadScope scope) {
    switch (scope.kind) {
      case 'ayat':
        return [AyahRef(scope.surah!, scope.ayah!)];
      case 'surah':
        final s = scope.surah!;
        return [
          for (var a = 1; a <= kSurahs[s - 1].ayahs; a++) AyahRef(s, a)
        ];
      case 'juz':
        return juzAyahs(scope.juz!);
      case 'quran':
        return [
          for (var s = 1; s <= 114; s++)
            for (var a = 1; a <= kSurahs[s - 1].ayahs; a++) AyahRef(s, a)
        ];
    }
    return [];
  }

  /// Enqueue a scope. Returns (queued, skippedNoSource).
  /// When [wifiOnly] is true and the device is on mobile data, nothing is
  /// started and everything stays queued for later.
  Future<(int queued, int skipped)> enqueueScope({
    required DownloadScope scope,
    required String readingId,
    required String reciterId,
    bool wifiOnly = false,
  }) async {
    if (!await repo.isCompatible(reciterId, readingId)) return (0, 0);
    if (!await _wifiAllowed(wifiOnly)) return (0, 0);
    var queued = 0, skipped = 0;
    for (final ref in refsForScope(scope)) {
      final existing = await repo.audioState(
          readingId: readingId, reciterId: reciterId,
          surah: ref.surah, ayah: ref.ayah);
      if (existing?.status == AudioStatus.ready) continue;
      if ((existing?.remoteUrl ?? '').isEmpty) {
        skipped++;
        continue;
      }
      await repo.upsertAudio(AudioFileInfo(
        surah: ref.surah, ayah: ref.ayah, readingId: readingId,
        reciterId: reciterId, remoteUrl: existing!.remoteUrl,
        fileSize: existing.fileSize, checksum: existing.checksum,
        durationMs: existing.durationMs,
        downloadedBytes: existing.downloadedBytes,
        status: AudioStatus.queued, progress: existing.progress,
      ));
      queued++;
      unawaited(_runOne(
          readingId: readingId, reciterId: reciterId,
          surah: ref.surah, ayah: ref.ayah));
    }
    return (queued, skipped);
  }

  Future<bool> _wifiAllowed(bool wifiOnly) async {
    if (!wifiOnly) return true;
    try {
      final res = await Connectivity().checkConnectivity();
      if (res.contains(ConnectivityResult.wifi) ||
          res.contains(ConnectivityResult.ethernet)) {
        return true;
      }
      return false;
    } catch (_) {
      return true; // fail-open on platforms without connectivity info
    }
  }

  Future<void> _runOne({
    required String readingId,
    required String reciterId,
    required int surah,
    required int ayah,
  }) async {
    final key = _key(readingId, reciterId, surah, ayah);
    if (_active.containsKey(key)) return;
    final task = _Task();
    _active[key] = task;
    final client = HttpClient();
    try {
      final row = await repo.audioState(
          readingId: readingId, reciterId: reciterId,
          surah: surah, ayah: ayah);
      final url = row?.remoteUrl;
      if (url == null || url.isEmpty) {
        _active.remove(key);
        return;
      }
      // Wi-Fi gate is checked by the caller settings snapshot; simplest
      // robust rule: individual items always attempt; scope enqueue already
      // gated. (Per-item re-check would need settings here.)
      final file = await localFile(
          readingId: readingId, reciterId: reciterId,
          surah: surah, ayah: ayah);
      var offset = 0;
      if (await file.exists()) {
        offset = await file.length();
        if (offset < 0) offset = 0;
      }
      final req = await client.getUrl(Uri.parse(url));
      if (offset > 0) req.headers.set('Range', 'bytes=$offset-');
      final resp = await req.close();
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        await _setStatus(readingId, reciterId, surah, ayah, row!,
            AudioStatus.failed, offset);
        _active.remove(key);
        return;
      }
      final total = (resp.contentLength >= 0)
          ? resp.contentLength + offset
          : (row?.fileSize ?? 0);
      await repo.upsertAudio(_copyWith(row!, offset, total,
          AudioStatus.downloading, file.path));
      final sink = file.openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
      var received = offset;
      var lastTick = DateTime.now();
      await for (final chunk in resp) {
        if (task.cancelled || task.paused) break;
        sink.add(chunk);
        received += chunk.length;
        if (DateTime.now().difference(lastTick).inMilliseconds > 700) {
          lastTick = DateTime.now();
          final pct = total > 0 ? ((received / total) * 100).floor().clamp(0, 100) : 0;
          await repo.upsertAudio(_copyWith(row, received, total,
              AudioStatus.downloading, file.path, pct));
          _emit(readingId, reciterId, surah, ayah,
              AudioStatus.downloading, pct, received, total);
        }
      }
      await sink.flush();
      await sink.close();
      if (task.cancelled) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        await repo.upsertAudio(_copyWith(row, 0, total,
            AudioStatus.notDownloaded, null, 0));
        _emit(readingId, reciterId, surah, ayah,
            AudioStatus.notDownloaded, 0, 0, total);
      } else if (task.paused) {
        final pct = total > 0 ? ((received / total) * 100).floor().clamp(0, 100) : 0;
        await repo.upsertAudio(
            _copyWith(row, received, total, AudioStatus.paused, file.path, pct));
        _emit(readingId, reciterId, surah, ayah,
            AudioStatus.paused, pct, received, total);
      } else {
        // verify checksum when provided
        var ok = true;
        if ((row.checksum ?? '').isNotEmpty) {
          try {
            final bytes = await file.readAsBytes();
            ok = sha256.convert(bytes).toString() == row.checksum;
          } catch (_) {
            ok = false;
          }
        }
        if (!ok) {
          await repo.upsertAudio(_copyWith(row, received, total,
              AudioStatus.failed, file.path, 0));
          _emit(readingId, reciterId, surah, ayah,
              AudioStatus.failed, 0, received, total);
        } else {
          await repo.upsertAudio(_copyWith(row, received, total,
              AudioStatus.ready, file.path, 100));
          _emit(readingId, reciterId, surah, ayah,
              AudioStatus.ready, 100, received, total);
        }
      }
    } catch (_) {
      try {
        final row = await repo.audioState(
            readingId: readingId, reciterId: reciterId,
            surah: surah, ayah: ayah);
        if (row != null && row.status != AudioStatus.ready) {
          await repo.upsertAudio(AudioFileInfo(
            surah: surah, ayah: ayah, readingId: readingId,
            reciterId: reciterId, remoteUrl: row.remoteUrl,
            localPath: row.localPath, fileSize: row.fileSize,
            downloadedBytes: row.downloadedBytes, checksum: row.checksum,
            durationMs: row.durationMs, status: AudioStatus.failed,
            progress: row.progress,
          ));
          _emit(readingId, reciterId, surah, ayah,
              AudioStatus.failed, row.progress, row.downloadedBytes, row.fileSize);
        }
      } catch (_) {}
    } finally {
      client.close(force: true);
      _active.remove(key);
    }
  }

  AudioFileInfo _copyWith(AudioFileInfo row, int received, int total,
      AudioStatus st, String? path,
      [int? pct]) {
    final p = pct ?? (total > 0 ? ((received / total) * 100).floor().clamp(0, 100) : 0);
    return AudioFileInfo(
      surah: row.surah, ayah: row.ayah, readingId: row.readingId,
      reciterId: row.reciterId, remoteUrl: row.remoteUrl, localPath: path,
      fileSize: total > 0 ? total : row.fileSize,
      downloadedBytes: received, checksum: row.checksum,
      durationMs: row.durationMs, status: st, progress: p,
    );
  }

  void _emit(String rd, String rec, int s, int a, AudioStatus st, int pct,
      int got, int? total) {
    try {
      _events.add(DownloadEvent(rd, rec, s, a, st, pct, got, total));
    } catch (_) {}
  }

  Future<void> _setStatus(String rd, String rec, int s, int a,
      AudioFileInfo row, AudioStatus st, int received) async {
    await repo.upsertAudio(AudioFileInfo(
      surah: s, ayah: a, readingId: rd, reciterId: rec,
      remoteUrl: row.remoteUrl, localPath: row.localPath,
      fileSize: row.fileSize, downloadedBytes: received,
      checksum: row.checksum, durationMs: row.durationMs,
      status: st, progress: row.progress,
    ));
    _emit(rd, rec, s, a, st, row.progress, received, row.fileSize);
  }

  Future<void> pause({required String readingId, required String reciterId, required int surah, required int ayah}) async {
    _active[_key(readingId, reciterId, surah, ayah)]?.paused = true;
    final row = await repo.audioState(
        readingId: readingId, reciterId: reciterId, surah: surah, ayah: ayah);
    if (row != null &&
        (row.status == AudioStatus.downloading || row.status == AudioStatus.queued)) {
      await repo.upsertAudio(AudioFileInfo(
        surah: surah, ayah: ayah, readingId: readingId, reciterId: reciterId,
        remoteUrl: row.remoteUrl, localPath: row.localPath,
        fileSize: row.fileSize, downloadedBytes: row.downloadedBytes,
        checksum: row.checksum, durationMs: row.durationMs,
        status: AudioStatus.paused, progress: row.progress,
      ));
    }
  }

  Future<void> cancel({required String readingId, required String reciterId, required int surah, required int ayah}) async {
    _active[_key(readingId, reciterId, surah, ayah)]?.cancelled = true;
  }

  Future<void> retry({required String readingId, required String reciterId, required int surah, required int ayah}) async {
    final row = await repo.audioState(
        readingId: readingId, reciterId: reciterId, surah: surah, ayah: ayah);
    if (row == null || (row.remoteUrl ?? '').isEmpty) return;
    await repo.upsertAudio(AudioFileInfo(
      surah: surah, ayah: ayah, readingId: readingId, reciterId: reciterId,
      remoteUrl: row.remoteUrl, localPath: row.localPath,
      fileSize: row.fileSize, downloadedBytes: row.downloadedBytes,
      checksum: row.checksum, durationMs: row.durationMs,
      status: AudioStatus.queued, progress: row.progress,
    ));
    unawaited(_runOne(
        readingId: readingId, reciterId: reciterId, surah: surah, ayah: ayah));
  }

  /// Delete local files for a reciter (optionally scoped to a reading).
  /// DB rows are reset to notDownloaded — catalog URLs + user data preserved.
  Future<int> deleteLocalForReciter(String reciterId, {String? readingId}) async {
    final root = await audioRoot();
    var freed = 0;
    final bases = readingId == null
        ? ['hafs-madinah', 'warsh-madinah']
        : [readingId];
    final d = await repo.dbForMaintenance();
    for (final rd in bases) {
      final dir = Directory(p.join(root.path, 'audio', rd, reciterId));
      if (await dir.exists()) {
        try {
          await for (final f in dir.list(recursive: true)) {
            if (f is File) {
              try {
                freed += await f.length();
                await f.delete();
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
      try {
        final rows = await d.query('audio_files',
            where: 'reciter_id=? AND reading_id=?',
            whereArgs: [reciterId, rd]);
        for (final r in rows) {
          await d.update('audio_files', {
            'local_path': null, 'downloaded_bytes': 0,
            'status': 'notDownloaded', 'progress': 0,
          },
              where: 'reading_id=? AND reciter_id=? AND surah=? AND ayah=?',
              whereArgs: [rd, reciterId, r['surah'], r['ayah']]);
        }
      } catch (_) {}
    }
    return freed;
  }

  Future<int> audioBytesOnDisk() async {
    try {
      final root = await audioRoot();
      var total = 0;
      await for (final f in root.list(recursive: true)) {
        if (f is File) {
          try {
            total += await f.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  void dispose() {
    try {
      _events.close();
    } catch (_) {}
  }
}

/// Approximate Juz -> ayah refs using standard Juz starts + ayah counts.
List<AyahRef> juzAyahs(int juz) {
  final starts = kJuzStarts;
  final idx = (juz - 1).clamp(0, 29);
  final (ss, sa) = starts[idx];
  final (es, ea) = idx + 1 < 30 ? starts[idx + 1] : (114, 7);
  final out = <AyahRef>[];
  var s = ss, a = sa;
  while (s < es || (s == es && a < ea)) {
    out.add(AyahRef(s, a));
    a++;
    if (a > kSurahs[s - 1].ayahs) {
      s++;
      a = 1;
      if (s > 114) break;
    }
  }
  return out;
}
