import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/core/constants.dart';
import 'package:oneayat/data/seed_data.dart';

void main() {
  test('seed search matching is case-insensitive and finds known ayat', () {
    const q = 'kemudahan';
    final hits = kSeedAyahs.where((s) =>
        s.$5.toLowerCase().contains(q) || s.$6.toLowerCase().contains(q));
    expect(hits, isNotEmpty);
    expect(hits.any((s) => s.$1 == 94 && s.$2 == 5), isTrue);
  });

  test('seed daily rotation deterministic', () {
    final keys = seedKeys.toList()..sort();
    String pick(DateTime d) =>
        keys[AppConstants.dayIndexFor(d) % keys.length];
    expect(pick(DateTime.utc(2026, 10, 5)),
        pick(DateTime.utc(2026, 10, 5, 15, 30)));
    expect(pick(DateTime.utc(2026, 10, 5)) != pick(DateTime.utc(2026, 10, 6)) ||
        keys.length == 1, isTrue);
  });
}
