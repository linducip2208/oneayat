import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/core/surah_metadata.dart';
import 'package:oneayat/data/seed_data.dart';
import 'package:oneayat/l10n/strings.dart';

void main() {
  test('114 surahs with valid counts summing to 6236', () {
    expect(kSurahs.length, 114);
    final sum = kSurahs.fold<int>(0, (a, s) => a + s.ayahs);
    expect(sum, 6236);
    for (var i = 0; i < 114; i++) {
      expect(kSurahs[i].number, i + 1);
      expect(kSurahs[i].ayahs, greaterThan(0));
    }
  });

  test('seed data: no dupes, valid refs, non-empty text', () {
    final seen = <String>{};
    for (final s in kSeedAyahs) {
      final key = '${s.$1}:${s.$2}';
      expect(seen.add(key), isTrue, reason: 'duplicate $key');
      expect(s.$1, inInclusiveRange(1, 114));
      expect(s.$2, inInclusiveRange(1, kSurahs[s.$1 - 1].ayahs));
      expect(s.$3.trim(), isNotEmpty);
      expect(s.$5.trim(), isNotEmpty);
      expect(s.$6.trim(), isNotEmpty);
    }
  });

  test('juz mapping sane', () {
    expect(juzFor(1, 1), 1);
    expect(juzFor(114, 6), 30);
    expect(juzFor(2, 142), 2);
  });

  test('localization covers keys in both languages', () {
    const keys = ['app_tagline', 'ayat_today', 'mark_done', 'settings', 'reminder'];
    for (final k in keys) {
      expect(const L10n('id').get(k).isNotEmpty, isTrue);
      expect(const L10n('en').get(k).isNotEmpty, isTrue);
      expect(const L10n('id').get(k) == k, isFalse);
    }
  });

  test('translation sources metadata present', () {
    expect(kTranslationSources.length, greaterThanOrEqualTo(3));
    for (final s in kTranslationSources) {
      expect(s.license.trim(), isNotEmpty);
    }
  });
}
