import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/services/daily_reminder.dart';

void main() {
  test('body carries snippet + ref', () {
    final b = reminderBody(
      translation: 'Sesungguhnya beserta kesulitan ada kemudahan.',
      surahName: 'Al-Insyirah',
      surah: 94,
      ayah: 5,
      lang: 'id',
      missedYesterday: false,
      streak: 3,
    );
    expect(b, contains('QS. Al-Insyirah (94:5)'));
    expect(b, contains('kemudahan'));
  });

  test('long translation truncated', () {
    final long = List.filled(50, 'kata').join(' ');
    final b = reminderBody(
      translation: long,
      surahName: 'X',
      surah: 1,
      ayah: 1,
      lang: 'id',
      missedYesterday: false,
      streak: 0,
    );
    expect(b.length, lessThan(long.length));
    expect(b, contains('…'));
  });

  test('missed yesterday gets gentle tone, no guilt-tripping streak reset', () {
    final b = reminderBody(
      translation: 'Teks.',
      surahName: 'X',
      surah: 1,
      ayah: 1,
      lang: 'id',
      missedYesterday: true,
      streak: 0,
    );
    expect(b, contains('tidak apa-apa'));
  });

  test('milestone streak celebrated', () {
    final b = reminderBody(
      translation: 'Teks.',
      surahName: 'X',
      surah: 1,
      ayah: 1,
      lang: 'id',
      missedYesterday: false,
      streak: 7,
    );
    expect(b, contains('7 hari'));
  });

  test('empty translation falls back to generic line + ref', () {
    final b = reminderBody(
      translation: null,
      surahName: 'Al-Fatihah',
      surah: 1,
      ayah: 1,
      lang: 'en',
      missedYesterday: false,
      streak: 0,
    );
    expect(b, contains('ready'));
    expect(b, contains('QS. Al-Fatihah (1:1)'));
  });
}
