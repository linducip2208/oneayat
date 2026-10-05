// Settings → Quran → Reading / Riwayah. Switches display text only;
// daily identity (surah+ayah), progress, bookmarks stay intact.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quran/readings.dart';
import '../services/providers.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});
  @override
  ConsumerState<ReadingScreen> createState() => _ReadingState();
}

class _ReadingState extends ConsumerState<ReadingScreen> {
  List<Map<String, Object?>> _rows = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final quran = ref.read(quranRepoProvider);
    final rows = await quran.readingRows();
    final counts = <String, int>{};
    for (final r in rows) {
      final id = r['id'] as String;
      var total = 0;
      // count via per-surah? cheap: single count query through repo helper
      // (sum over surahs would be 114 queries — instead raw count here)
      total = await _countReading(id);
      counts[id] = total;
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _counts = counts;
      _loading = false;
    });
  }

  Future<int> _countReading(String id) async {
    try {
      final db = await ref.read(dbProvider).db;
      final r = await db.rawQuery(
          'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=?', [id]);
      return (r.first['c'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Quran Reading / Riwayah')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in _rows.isEmpty
                    ? [
                        for (final k in kQuranReadings)
                          {'id': k.id, 'name': k.name, 'riwayah': k.riwayah, 'description': k.description, 'source': k.source, 'license': k.license}
                      ]
                    : _rows)
                  _tile(context, r,
                      _counts[r['id']] ?? 0, settings.readingId),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Bookmarks, history, streak and daily progress are keyed by '
                      'surah + ayah, so switching Hafs ↔ Warsh never loses them.\n\n'
                      'Warsh text requires a licensed dataset: '
                      'tools/import_quran.dart --reading warsh-madinah --in warsh.json',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, Map<String, Object?> r, int count,
      String selected) {
    final id = r['id'] as String;
    final sel = selected == id;
    final complete = count >= 6236;
    return Card(
      child: RadioListTile<String>(
        value: id,
        groupValue: selected,
        title: Text('${r['name']}'),
        subtitle: Text(
            '${r['description']}\nText installed: $count / 6236 ${complete ? '✓ complete' : '(sample/partial)'}\nSource: ${r['source']}\nLicense: ${r['license']}'),
        isThreeLine: false,
        selected: sel,
        onChanged: (v) async {
          if (v == null) return;
          if (count == 0) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '${r['name']}: no text installed yet — licensed dataset required. Stayed on current reading.')));
            return;
          }
          final s = ref.read(settingsProvider);
          await s.setReading(v);
          // Drop incompatible reciter automatically (never mix).
          if (s.reciterId != null) {
            final ok = await ref
                .read(reciterRepoProvider)
                .isCompatible(s.reciterId!, v);
            if (!ok) await s.setReciter(null);
          }
          ref.read(settingsTickProvider.notifier).state++;
          ref.read(refreshTickProvider.notifier).state++;
          setState(() {});
        },
      ),
    );
  }
}
