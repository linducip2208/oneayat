// Validator + integrity tests (fast: error paths only, no 6236-row fixtures).
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../tools/import_quran.dart' as imp;

void main() {
  test('empty ayahs rejected', () {
    final errs = imp.validateDataset({'ayahs': [], 'sources': []}, 'hafs-madinah');
    expect(errs, isNotEmpty);
  });

  test('missing sources rejected', () {
    final errs = imp.validateDataset({
      'ayahs': [
        {'surah': 1, 'ayah': 1, 'arabic': 'x'}
      ],
      'sources': [],
    }, 'hafs-madinah');
    expect(errs.any((e) => e.contains('sources')), isTrue);
  });

  test('duplicate ayah rejected', () {
    final errs = imp.validateDataset({
      'sources': [
        {'code': 's'}
      ],
      'ayahs': [
        {'surah': 1, 'ayah': 1, 'arabic': 'a'},
        {'surah': 1, 'ayah': 1, 'arabic': 'b'},
      ],
    }, 'hafs-madinah');
    expect(errs.any((e) => e.contains('duplicate')), isTrue);
  });

  test('invalid ayah number rejected', () {
    final errs = imp.validateDataset({
      'sources': [
        {'code': 's'}
      ],
      'ayahs': [
        {'surah': 1, 'ayah': 99, 'arabic': 'a'},
      ],
    }, 'hafs-madinah');
    expect(errs.any((e) => e.contains('invalid ayah')), isTrue);
  });

  test('tafsir without scholar rejected', () {
    final errs = imp.validateDataset({
      'sources': [
        {'code': 's'}
      ],
      'ayahs': [
        {'surah': 112, 'ayah': 1, 'arabic': 'a'},
      ],
      'tafsirs': [
        {'surah': 112, 'ayah': 1, 'lang': 'id', 'text': 't'},
      ],
    }, 'hafs-madinah');
    expect(errs.any((e) => e.contains('scholar')), isTrue);
  });

  test('reciter with unknown reading rejected', () {
    final errs = imp.validateDataset({
      'sources': [
        {'code': 's'}
      ],
      'ayahs': [
        {'surah': 112, 'ayah': 1, 'arabic': 'a'},
      ],
      'reciters': [
        {'id': 'r1', 'readings': ['no-such-reading'], 'license': 'L'},
      ],
    }, 'hafs-madinah');
    expect(errs.any((e) => e.contains('unknown reading')), isTrue);
  });

  test('audio file refs unknown ayah rejected', () {
    final errs = imp.validateDataset({
      'sources': [
        {'code': 's'}
      ],
      'ayahs': [
        {'surah': 112, 'ayah': 1, 'arabic': 'a'},
      ],
      'reciters': [
        {
          'id': 'r1',
          'readings': ['hafs-madinah'],
          'license': 'L',
          'files': [
            {'surah': 2, 'ayah': 999, 'url': 'https://x/y.mp3'}
          ],
        },
      ],
    }, 'hafs-madinah');
    expect(errs.any((e) => e.contains('unknown ayah')), isTrue);
  });
}
