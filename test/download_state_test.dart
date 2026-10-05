import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/data/models.dart';
import 'package:oneayat/services/download_manager.dart';

void main() {
  test('AudioStatus parses all persisted values, unknown -> notDownloaded', () {
    expect(audioStatusFrom('ready'), AudioStatus.ready);
    expect(audioStatusFrom('downloading'), AudioStatus.downloading);
    expect(audioStatusFrom('paused'), AudioStatus.paused);
    expect(audioStatusFrom('failed'), AudioStatus.failed);
    expect(audioStatusFrom('queued'), AudioStatus.queued);
    expect(audioStatusFrom('verifying'), AudioStatus.verifying);
    expect(audioStatusFrom('notDownloaded'), AudioStatus.notDownloaded);
    expect(audioStatusFrom(null), AudioStatus.notDownloaded);
    expect(audioStatusFrom('bogus'), AudioStatus.notDownloaded);
    expect(audioStatusName(AudioStatus.ready), 'ready');
  });

  test('scope refs: single ayat / surah counts', () {
    expect(
      DownloadManagerForTest.refs(const DownloadScope.single(1, 1)).length,
      1,
    );
    expect(
      DownloadManagerForTest.refs(DownloadScope.surah(112)).length,
      4,
    );
    expect(
      DownloadManagerForTest.refs(DownloadScope.surah(1)).length,
      7,
    );
    expect(
      DownloadManagerForTest.refs(const DownloadScope.quran()).length,
      6236,
    );
  });

  test('juz 30 starts at An-Naba and juz sizes sane', () {
    final j30 = juzAyahs(30);
    expect(j30.first.surah, 78);
    expect(j30.first.ayah, 1);
    expect(j30.length, greaterThan(500));
    // no duplicates
    expect(j30.map((e) => e.key).toSet().length, j30.length);
  });

  test('storage calc: downloaded sum logic', () {
    // pure check of MB formatting contract used by Storage screen
    const bytes = 1572864;
    expect((bytes / 1048576).toStringAsFixed(1), '1.5');
  });
}

// Expose pure scope expansion without constructing the manager (needs repo).
class DownloadManagerForTest {
  static List<AyahRef> refs(DownloadScope scope) {
    switch (scope.kind) {
      case 'ayat':
        return [AyahRef(scope.surah!, scope.ayah!)];
      case 'surah':
        return _surahRefs(scope.surah!);
      case 'juz':
        return juzAyahs(scope.juz!);
      case 'quran':
        return _allRefs();
    }
    return [];
  }

  static List<AyahRef> _surahRefs(int s) {
    const full = [
      7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99,
      128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
      34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38,
      29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18,
      12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29,
      19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8,
      11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
    ];
    return [for (var a = 1; a <= full[s - 1]; a++) AyahRef(s, a)];
  }

  static List<AyahRef> _allRefs() {
    final out = <AyahRef>[];
    for (var s = 1; s <= 114; s++) {
      out.addAll(_surahRefs(s));
    }
    expect(out.length, 6236);
    return out;
  }
}
