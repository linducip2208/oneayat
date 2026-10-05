// Settings → Storage: sizes + per-reciter cleanup. Never touches Quran
// text, bookmarks, notes, history or progress.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../services/providers.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});
  @override
  ConsumerState<StorageScreen> createState() => _StorageState();
}

class _StorageState extends ConsumerState<StorageScreen> {
  bool _loading = true;
  int _audioBytes = 0;
  int _tafsirRows = 0;
  int _hafs = 0;
  int _warsh = 0;
  List<ReciterInfo> _hafsRec = [];
  List<ReciterInfo> _warshRec = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dm = ref.read(downloadManagerProvider);
    final db = await ref.read(dbProvider).db;
    int tafsir = 0, hafs = 0, warsh = 0;
    try {
      tafsir = ((await db.rawQuery('SELECT COUNT(*) c FROM tafsirs')).first['c'] as int?) ?? 0;
      hafs = ((await db.rawQuery(
                  'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=?', ['hafs-madinah']))
              .first['c'] as int?) ?? 0;
      warsh = ((await db.rawQuery(
                  'SELECT COUNT(*) c FROM ayah_texts WHERE reading_id=?', ['warsh-madinah']))
              .first['c'] as int?) ?? 0;
    } catch (_) {}
    final audio = await dm.audioBytesOnDisk();
    final hr = await ref.read(reciterRepoProvider).recitersFor('hafs-madinah');
    final wr = await ref.read(reciterRepoProvider).recitersFor('warsh-madinah');
    if (!mounted) return;
    setState(() {
      _audioBytes = audio;
      _tafsirRows = tafsir;
      _hafs = hafs;
      _warsh = warsh;
      _hafsRec = hr;
      _warshRec = wr;
      _loading = false;
    });
  }

  String _mb(int b) => '${(b / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _row('Quran database (Hafs text)', '$_hafs / 6236 ayat'),
                _row('Quran database (Warsh text)', '$_warsh / 6236 ayat'),
                _row('Tafsir entries', '$_tafsirRows'),
                _row('Audio downloads', _mb(_audioBytes)),
                _row('Total (DB + audio)',
                    '${_mb(_audioBytes)} + bundled DB'),
                const SizedBox(height: 16),
                Text('AUDIO PER RECITER',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(letterSpacing: 1.5)),
                for (final r in [..._hafsRec, ..._warshRec])
                  ListTile(
                    title: Text(r.name),
                    subtitle: FutureBuilder<int>(
                      future: ref
                          .read(reciterRepoProvider)
                          .downloadedBytesForReciter(r.id),
                      builder: (c, s) => Text(
                          '${_mb(s.data ?? 0)} downloaded • ${r.license}'),
                    ),
                    trailing: TextButton(
                      onPressed: () => _delete(r.id, r.name),
                      child: const Text('DELETE AUDIO'),
                    ),
                  ),
                if (_hafsRec.isEmpty && _warshRec.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No reciters registered — nothing to clean.'),
                    ),
                  ),
                const SizedBox(height: 8),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Delete removes audio files only. Quran text, translations, '
                      'tafsir, bookmarks, notes, history and streaks are never deleted here.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, String value) => ListTile(
        title: Text(label),
        trailing:
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Future<void> _delete(String reciterId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete audio — $name?'),
        content: const Text('Audio files only. Everything else stays.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(downloadManagerProvider).deleteLocalForReciter(reciterId);
    await _load();
  }
}
