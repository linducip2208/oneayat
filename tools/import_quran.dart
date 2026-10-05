// Quran dataset pipeline: validates licensed JSON for readings,
// translations, tafsir and reciter/audio catalogs.
// Run with: dart run tools/import_quran.dart --in quran.json [--reading hafs-madinah]
// Full-dataset JSON:
// {
//   "reading": "hafs-madinah",
//   "sources": [{"code":"...","language":"...","title":"...","license":"...","version":"..."}],
//   "ayahs": [{"surah":1,"ayah":1,"juz":1,"page":1,"arabic":"...","tajwid":"..."}],
//   "translations": [{"surah":1,"ayah":1,"lang":"id","translator":"...","text":"...","source":"...","license":"..."}],
//   "tafsirs": [{"surah":1,"ayah":1,"lang":"id","scholar":"...","title":"...","text":"...","source":"...","license":"..."}],
//   "reciters": [{"id":"...","name":"...","readings":["hafs-madinah"],"source":"...","license":"...",
//                 "files":[{"surah":1,"ayah":1,"url":"https://...","bytes":123,"sha256":"...","ms":1000}]}]
// }
// Validation: per-reading 114 surahs, exact ayah counts, no dupes/missing,
// valid refs, translation/tafsir/audio refs resolve to real ayahs, reciter x
// reading compatibility explicit. Fails loudly — never invents content.
import 'dart:convert';
import 'dart:io';

import 'package:oneayat/core/constants.dart';
import 'package:oneayat/quran/readings.dart';

void main(List<String> args) async {
  var input = '';
  var reading = 'hafs-madinah';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--in' && i + 1 < args.length) input = args[i + 1];
    if (args[i] == '--reading' && i + 1 < args.length) reading = args[i + 1];
  }
  if (input.isEmpty || !File(input).existsSync()) {
    stderr.writeln(
        'Usage: dart run tools/import_quran.dart --in <dataset.json> [--reading hafs-madinah|warsh-madinah]');
    stderr.writeln('See tools/README_IMPORT.md for format + licensing rules.');
    exit(2);
  }
  if (!isKnownReading(reading)) {
    stderr.writeln('ERROR: unknown reading "$reading" (known: hafs-madinah, warsh-madinah)');
    exit(2);
  }
  final json =
      jsonDecode(File(input).readAsStringSync()) as Map<String, dynamic>;
  final errors = validateDataset(json, reading);
  if (errors.isNotEmpty) {
    for (final e in errors) {
      stderr.writeln('ERROR: $e');
    }
    exit(1);
  }
  final ayahs = (json['ayahs'] as List).length;
  stdout.writeln('OK [$reading]: $ayahs ayahs validated '
      '(114 surahs, counts match, no dupes/missing).');
  stdout.writeln('Refs validated: translations, tafsirs, audio files, reciter compat.');
  stdout.writeln('Next: insert into SQLite (tables ayah_texts/translations/tafsirs/'
      'reciters/reciter_readings/audio_files) or bundle under assets/seed/<reading>/');
}

List<String> validateDataset(Map<String, dynamic> json, String reading) {
  final errors = <String>[];
  final ayahs = json['ayahs'];
  if (ayahs is! List) return ['"ayahs" must be a list'];
  final seen = <String>{};
  final perSurah = <int, int>{};
  for (final e in ayahs) {
    if (e is! Map) {
      errors.add('invalid ayah entry (not an object)');
      continue;
    }
    final s = e['surah'];
    final a = e['ayah'];
    final ar = e['arabic'];
    if (s is! int || s < 1 || s > 114) {
      errors.add('invalid surah ref: $s');
      continue;
    }
    final expected = AppConstants.ayahCounts[s - 1];
    if (a is! int || a < 1 || a > expected) {
      errors.add('invalid ayah number $a for surah $s (expected 1..$expected)');
      continue;
    }
    if (ar is! String || ar.trim().isEmpty) {
      errors.add('missing arabic text for $s:$a');
      continue;
    }
    final key = '$s:$a';
    if (!seen.add(key)) errors.add('duplicate ayah $key');
    perSurah[s] = (perSurah[s] ?? 0) + 1;
  }
  if (perSurah.length != 114) {
    errors.add('[$reading] surah coverage ${perSurah.length}/114 (need exactly 114)');
  }
  for (var s = 1; s <= 114; s++) {
    final got = perSurah[s] ?? 0;
    if (got != AppConstants.ayahCounts[s - 1]) {
      errors.add('[$reading] surah $s: got $got ayahs, expected ${AppConstants.ayahCounts[s - 1]}');
    }
  }
  final sources = json['sources'];
  if (sources is! List || sources.isEmpty) {
    errors.add('missing "sources" dataset metadata (source + license required)');
  }
  bool validRef(dynamic s, dynamic a) {
    if (s is! int || a is! int || s < 1 || s > 114) return false;
    if (a < 1 || a > AppConstants.ayahCounts[s - 1]) return false;
    return seen.contains('$s:$a');
  }

  final translations = json['translations'];
  if (translations is List) {
    for (final t in translations) {
      if (t is! Map) {
        errors.add('invalid translation entry');
        continue;
      }
      if (!validRef(t['surah'], t['ayah'])) {
        errors.add('translation refs unknown ayah ${t['surah']}:${t['ayah']}');
      }
      if ((t['text'] as String?)?.trim().isEmpty ?? true) {
        errors.add('translation empty text ${t['surah']}:${t['ayah']}');
      }
      if ((t['source'] as String?)?.trim().isEmpty ?? true) {
        errors.add('translation missing source ${t['surah']}:${t['ayah']}');
      }
    }
  }
  final tafsirs = json['tafsirs'];
  if (tafsirs is List) {
    for (final t in tafsirs) {
      if (t is! Map) {
        errors.add('invalid tafsir entry');
        continue;
      }
      if (!validRef(t['surah'], t['ayah'])) {
        errors.add('tafsir refs unknown ayah ${t['surah']}:${t['ayah']}');
      }
      if ((t['scholar'] as String?)?.trim().isEmpty ?? true) {
        errors.add('tafsir missing scholar ${t['surah']}:${t['ayah']} (no anonymous tafsir)');
      }
      if ((t['text'] as String?)?.trim().isEmpty ?? true) {
        errors.add('tafsir empty text ${t['surah']}:${t['ayah']}');
      }
    }
  }
  final reciters = json['reciters'];
  if (reciters is List) {
    for (final r in reciters) {
      if (r is! Map) {
        errors.add('invalid reciter entry');
        continue;
      }
      final rid = r['id'];
      if ((rid as String?)?.trim().isEmpty ?? true) {
        errors.add('reciter missing id');
        continue;
      }
      final rds = r['readings'];
      if (rds is! List || rds.isEmpty) {
        errors.add('reciter $rid: missing readings[] compatibility');
        continue;
      }
      for (final rd in rds) {
        if (!isKnownReading(rd as String)) {
          errors.add('reciter $rid: unknown reading $rd');
        }
      }
      if ((r['license'] as String?)?.trim().isEmpty ?? true) {
        errors.add('reciter $rid: missing license');
      }
      final files = r['files'];
      if (files is List) {
        for (final f in files) {
          if (f is! Map) {
            errors.add('reciter $rid: invalid file entry');
            continue;
          }
          if (!validRef(f['surah'], f['ayah'])) {
            errors.add('reciter $rid: file refs unknown ayah ${f['surah']}:${f['ayah']}');
          }
          if ((f['url'] as String?)?.trim().isEmpty ?? true) {
            errors.add('reciter $rid: file missing url ${f['surah']}:${f['ayah']}');
          }
        }
      }
    }
  }
  return errors;
}

/// Backwards-compatible single-dataset validator used by tests.
List<String> validate(Map<String, dynamic> json) =>
    validateDataset(json, (json['reading'] as String?) ?? 'hafs-madinah');
