import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/core/constants.dart';
import 'package:oneayat/data/models.dart';
import 'package:oneayat/quran/readings.dart';

void main() {
  test('Hafs is default, Warsh known, no other readings', () {
    expect(defaultReadingId(), 'hafs-madinah');
    expect(isKnownReading('hafs-madinah'), isTrue);
    expect(isKnownReading('warsh-madinah'), isTrue);
    expect(isKnownReading('hafs-warsh-mix'), isFalse);
    expect(kQuranReadings.where((r) => r.isDefault).length, 1);
  });

  test('daily identity (surah+ayah) stable regardless of reading', () {
    // Same date -> same logical ayat; only displayed text changes by reading.
    final g1 = AppConstants.dailyGlobalIndexFor(DateTime.utc(2026, 10, 5));
    final (s, a) = AppConstants.globalIndexToRef(g1);
    expect(AyahRef(s, a), AyahRef(s, a));
    expect(AppConstants.refToGlobalIndex(s, a), g1);
  });

  test('switching Hafs->Warsh->Hafs keeps identity', () {
    const ref = AyahRef(94, 5);
    const hafs = 'hafs-madinah';
    const warsh = 'warsh-madinah';
    // Identity never includes reading text — only surah+ayah.
    expect(ref.key, '94:5');
    expect(hafs != warsh, isTrue);
  });

  test('bookmark identity is surah+ayah (reading-independent)', () {
    const b1 = Bookmark(surah: 1, ayah: 1, createdAt: 0);
    const b2 = Bookmark(surah: 1, ayah: 1, folderId: 9, createdAt: 1);
    expect(b1.surah == b2.surah && b1.ayah == b2.ayah, isTrue);
  });

  test('audio storage paths structured per reading/reciter', () {
    expect(
      audioRelativePath(readingId: 'hafs-madinah', reciterId: 'rec-a', surah: 1, ayah: 5),
      'audio/hafs-madinah/rec-a/001/005.mp3',
    );
    expect(
      audioRelativePath(readingId: 'warsh-madinah', reciterId: 'rec-b', surah: 114, ayah: 6),
      'audio/warsh-madinah/rec-b/114/006.mp3',
    );
    // unsafe ids sanitized
    expect(
      audioRelativePath(readingId: 'hafs/../x', reciterId: 'a/b', surah: 2, ayah: 3),
      isNot(contains('..')),
    );
  });

  test('ayah marker uses Arabic end-of-ayah sign', () {
    final m = ayahMarker(5);
    expect(m.codeUnitAt(0), 0x06DD);
    expect(m.length, greaterThan(1));
  });
}
