// Settings → About → Quran Sources & Licenses. Nothing hidden.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quran/mushaf_config.dart';
import '../quran/readings.dart';
import '../services/providers.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});
  @override
  ConsumerState<SourcesScreen> createState() => _SrcState();
}

class _SrcState extends ConsumerState<SourcesScreen> {
  List<Map<String, Object?>> _readings = [];
  List<Map<String, Object?>> _langs = [];
  List<Map<String, Object?>> _reciters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await ref.read(dbProvider).db;
    List<Map<String, Object?>> rd = [], lg = [], rc = [];
    try {
      rd = await db.query('quran_readings');
      lg = await db.query('translation_languages');
      rc = await db.query('reciters');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _readings = rd.isEmpty
          ? [
              for (final r in kQuranReadings)
                {'name': r.name, 'source': r.source, 'version': r.version, 'license': r.license}
            ]
          : rd;
      _langs = lg;
      _reciters = rc;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quran Sources & Licenses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _h(context, 'QURAN TEXT'),
                for (final r in _readings)
                  _card('${r['name'] ?? r['id']}',
                      'Source: ${r['source']}\nVersion: ${r['version']}\nLicense: ${r['license']}'),
                _h(context, 'RENDERING / FONT'),
                _card('Madinah-oriented rendering',
                    'Hafs font stack: ${mushafConfigFor('hafs-madinah').families.join(', ')}\n'
                    'Warsh font stack: ${mushafConfigFor('warsh-madinah').families.join(', ')}\n'
                    'Licensed Madinah font: ${mushafConfigFor('hafs-madinah').licensedFamily ?? 'not installed (fallback stack in use)'} — drop a licensed .ttf under assets/fonts/ to enable without code changes.'),
                _h(context, 'TRANSLATIONS'),
                if (_langs.isEmpty)
                  _card('Bundled samples', 'Community sample meanings (see lib/data/seed_data.dart). Replace with licensed translations via tools/import_quran.dart.')
                else
                  for (final l in _langs)
                    _card('${l['title'] ?? l['code']}',
                        'Language: ${l['language']}\nLicense: ${l['license']}\nVersion: ${l['version']}'),
                _h(context, 'TAFSIR'),
                _card('Scholarly tafsir only',
                    'Only licensed tafsir datasets are shown in the reader with scholar + source attribution. No AI-generated tafsir is presented as scholarly tafsir. Import via tools/import_quran.dart (tafsirs section).'),
                _h(context, 'RECITERS / AUDIO'),
                if (_reciters.isEmpty)
                  _card('No reciter bundled',
                      'Audio is optional and downloadable. Reciter names appear only when a licensed dataset is registered, with source + license shown.')
                else
                  for (final r in _reciters)
                    _card('${r['name']}',
                        'Source: ${r['source']}\nLicense: ${r['license']}'),
              ],
            ),
    );
  }

  Widget _h(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t,
            style: Theme.of(c).textTheme.labelLarge?.copyWith(
                letterSpacing: 1.5,
                color: Theme.of(c).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );

  Widget _card(String title, String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(body),
            ],
          ),
        ),
      );
}
