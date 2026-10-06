// Tanzil-format converter: plain-text Quran files -> dataset.json for
// tools/import_quran.dart. Passes text through VERBATIM (never edits,
// strips, or adds Bismillah). Validates 6236 lines + per-surah counts.
//
// Tanzil files (download yourself, only if the license fits your release):
//   arabic:      quran-uthmani.txt        ("surah|ayah|text", 6236 lines)
//   translation: e.g. id-indonesian.txt   (same 3-column format)
//
// Usage:
//   dart run tools/tanzil_import.dart --arabic quran-uthmani.txt \
//     --tr id:id-translation.txt --tr en:en-translation.txt \
//     --reading hafs-madinah --source "..." --license "..." \
//     --out dataset.json
// Then:
//   dart run tools/import_quran.dart --in dataset.json --reading hafs-madinah
//
// Licensing is YOUR responsibility: Tanzil data may be used freely but check
// https://tanzil.net/trans/terms for redistribution rules, and translation
// rights holders individually. When in doubt, do not ship it.
import 'dart:convert';
import 'dart:io';

import 'package:oneayat/core/constants.dart';
import 'package:oneayat/core/surah_metadata.dart';

void main(List<String> args) async {
  var arabic = '';
  var reading = 'hafs-madinah';
  var source = 'Tanzil-format import (verify license before release)';
  var license = 'UNVERIFIED — replace before release';
  var out = 'dataset.json';
  final trs = <String, String>{}; // lang -> path
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--arabic':
        arabic = args[++i];
      case '--tr':
        final kv = args[++i].split(':');
        if (kv.length != 2) {
          stderr.writeln('ERROR: --tr must be lang:path');
          exit(2);
        }
        trs[kv[0]] = kv[1];
      case '--reading':
        reading = args[++i];
      case '--source':
        source = args[++i];
      case '--license':
        license = args[++i];
      case '--out':
        out = args[++i];
    }
  }
  if (arabic.isEmpty || !File(arabic).existsSync()) {
    stderr.writeln('ERROR: --arabic <quran-uthmani.txt> required');
    exit(2);
  }
  final arabicRows = _readTable(arabic);
  final errors = <String>[];
  if (arabicRows.length != 6236) {
    errors.add('arabic lines ${arabicRows.length}, expected 6236');
  }
  final perSurah = <int, int>{};
  for (final r in arabicRows) {
    perSurah[r.surah] = (perSurah[r.surah] ?? 0) + 1;
  }
  for (var s = 1; s <= 114; s++) {
    if ((perSurah[s] ?? 0) != AppConstants.ayahCounts[s - 1]) {
      errors.add(
          'surah $s: got ${perSurah[s] ?? 0}, expected ${AppConstants.ayahCounts[s - 1]}');
    }
  }
  // translations: same refs, verbatim text
  final trData = <String, List<_Row>>{};
  for (final e in trs.entries) {
    final rows = _readTable(e.value);
    if (rows.length != 6236) {
      errors.add('[${e.key}] lines ${rows.length}, expected 6236');
    }
    trData[e.key] = rows;
  }
  if (errors.isNotEmpty) {
    for (final e in errors) {
      stderr.writeln('ERROR: $e');
    }
    exit(1);
  }
  final byKey = <String, String>{for (final r in arabicRows) '${r.surah}:${r.ayah}': r.text};
  final ayahs = <Map<String, dynamic>>[];
  for (final r in arabicRows) {
    ayahs.add({
      'surah': r.surah,
      'ayah': r.ayah,
      'juz': juzFor(r.surah, r.ayah),
      'arabic': r.text,
      'tajwid': r.text,
    });
  }
  final translations = <Map<String, dynamic>>[];
  for (final e in trData.entries) {
    for (final r in e.value) {
      final key = '${r.surah}:${r.ayah}';
      if (!byKey.containsKey(key)) {
        stderr.writeln('ERROR: [${e.key}] refs unknown ayah $key');
        exit(1);
      }
      translations.add({
        'surah': r.surah,
        'ayah': r.ayah,
        'lang': e.key,
        'translator': 'see source file header',
        'text': r.text,
        'source': source,
        'license': license,
      });
    }
  }
  final dataset = {
    'reading': reading,
    'sources': [
      {
        'code': '${reading}_tanzil',
        'language': 'ar',
        'title': 'Quran text ($reading) via Tanzil-format file',
        'license': license,
        'version': '1.0',
      },
    ],
    'ayahs': ayahs,
    'translations': translations,
  };
  File(out).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(dataset));
  stdout.writeln(
      'OK: wrote $out (${ayahs.length} ayahs, ${translations.length} translation rows).');
  stdout.writeln('Next: dart run tools/import_quran.dart --in $out --reading $reading');
}

class _Row {
  final int surah;
  final int ayah;
  final String text;
  _Row(this.surah, this.ayah, this.text);
}

List<_Row> _readTable(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    stderr.writeln('ERROR: file not found: $path');
    exit(2);
  }
  final out = <_Row>[];
  for (final raw in f.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('|');
    if (parts.length < 3) {
      stderr.writeln('ERROR: malformed line in $path: $line');
      exit(1);
    }
    final s = int.tryParse(parts[0].trim());
    final a = int.tryParse(parts[1].trim());
    if (s == null || a == null) {
      stderr.writeln('ERROR: bad ref in $path: $line');
      exit(1);
    }
    out.add(_Row(s, a, parts.sublist(2).join('|').trim()));
  }
  return out;
}
