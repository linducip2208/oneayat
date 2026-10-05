// Settings → Audio: reciter picker (compatible only), repeat, speed,
// autoplay, wi-fi only, download scopes (ayat/surah/juz/quran), progress.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../services/providers.dart';

class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});
  @override
  ConsumerState<AudioSettingsScreen> createState() => _AudioState();
}

class _AudioState extends ConsumerState<AudioSettingsScreen> {
  List<ReciterInfo> _reciters = [];
  bool _loading = true;
  StreamSubscription? _sub;
  (int, int)? _surahProg;
  int? _surahSel = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ref.read(downloadManagerProvider).events.listen((_) {
      if (mounted) _refreshProg();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    final reciters = await ref
        .read(reciterRepoProvider)
        .recitersFor(settings.readingId);
    if (!mounted) return;
    setState(() {
      _reciters = reciters;
      _loading = false;
    });
    await _refreshProg();
  }

  Future<void> _refreshProg() async {
    final settings = ref.read(settingsProvider);
    if (settings.reciterId == null || _surahSel == null) return;
    final p = await ref.read(reciterRepoProvider).surahProgress(
        readingId: settings.readingId,
        reciterId: settings.reciterId!,
        surah: _surahSel!,
        ayahCount: kSurahs[_surahSel! - 1].ayahs);
    if (mounted) setState(() => _surahProg = p);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Audio / Reciter')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('RECITER — ${s.readingId}',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(letterSpacing: 1.5)),
                const SizedBox(height: 8),
                if (_reciters.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'No reciter installed for this reading yet.\n\n'
                        'Reciter names appear here only when a licensed audio '
                        'dataset is registered. Import via reciter catalog '
                        '(see tools/README_IMPORT.md).'),
                    ),
                  )
                else
                  for (final r in _reciters)
                    RadioListTile<String>(
                      value: r.id,
                      groupValue: s.reciterId,
                      title: Text(r.name),
                      subtitle: Text(
                          '${r.language} ${r.country}\n${r.description}\nSource: ${r.source}\nLicense: ${r.license}'),
                      onChanged: (v) async {
                        await s.setReciter(v);
                        ref.read(settingsTickProvider.notifier).state++;
                        setState(() {});
                        await _refreshProg();
                      },
                    ),
                const Divider(height: 32),
                Text('PLAYBACK',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(letterSpacing: 1.5)),
                ListTile(
                  title: const Text('Repeat'),
                  trailing: DropdownButton<String>(
                    value: s.repeatMode,
                    items: const [
                      DropdownMenuItem(value: 'off', child: Text('Off')),
                      DropdownMenuItem(value: '1', child: Text('1x')),
                      DropdownMenuItem(value: '3', child: Text('3x')),
                      DropdownMenuItem(value: '5', child: Text('5x')),
                      DropdownMenuItem(value: '10', child: Text('10x')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setRepeat(v);
                      setState(() {});
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Playback speed'),
                  trailing: DropdownButton<double>(
                    value: s.audioSpeed,
                    items: const [
                      DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                      DropdownMenuItem(value: 1.0, child: Text('1x')),
                      DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                      DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setSpeed(v);
                      setState(() {});
                    },
                  ),
                ),
                SwitchListTile(
                  title: const Text('Auto play next ayat'),
                  value: s.autoplayNext,
                  onChanged: (v) async {
                    await s.setAutoplay(v);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Wi-Fi only downloads'),
                  value: s.wifiOnly,
                  onChanged: (v) async {
                    await s.setWifiOnly(v);
                    setState(() {});
                  },
                ),
                const Divider(height: 32),
                Text('OFFLINE AUDIO',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(letterSpacing: 1.5)),
                const SizedBox(height: 8),
                if (s.reciterId == null)
                  const Text('Select a reciter first to manage downloads.')
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _surahSel,
                          decoration: const InputDecoration(
                              labelText: 'Surah', border: OutlineInputBorder()),
                          items: [
                            for (var i = 1; i <= 114; i++)
                              DropdownMenuItem(
                                  value: i,
                                  child: Text('$i. ${kSurahs[i - 1].latin}',
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) async {
                            setState(() => _surahSel = v);
                            await _refreshProg();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _downloadSurah,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('This Surah'),
                        ),
                      ),
                    ],
                  ),
                  if (_surahProg != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _surahProg!.$2 == 0
                          ? 0
                          : _surahProg!.$1 / _surahProg!.$2,
                    ),
                    Text(
                        'Downloaded: ${_surahProg!.$1}/${_surahProg!.$2} (${_surahProg!.$2 == 0 ? 0 : ((_surahProg!.$1 / _surahProg!.$2) * 100).floor()}%)'),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                          onPressed: _downloadJuz1Demo,
                          child: const Text('This Juz (Juz 30)')),
                      OutlinedButton(
                          onPressed: _downloadQuran,
                          child: const Text('Entire Quran')),
                      OutlinedButton(
                          onPressed: _deleteReciter,
                          child: const Text('Delete downloads')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Audio plays from local files only. Items without a '
                    'registered source are skipped honestly (never streamed).',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _downloadSurah() async {
    final s = ref.read(settingsProvider);
    if (s.reciterId == null || _surahSel == null) return;
    final dm = ref.read(downloadManagerProvider);
    final (q, skipped) = await dm.enqueueScope(
      scope: DownloadScope.surah(_surahSel!),
      readingId: s.readingId,
      reciterId: s.reciterId!,
      wifiOnly: s.wifiOnly,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(skipped > 0 && q == 0
            ? 'No licensed audio source registered for this reciter yet.'
            : 'Queued $q file(s)${skipped > 0 ? ', $skipped without source skipped' : ''}.')));
    await _refreshProg();
  }

  Future<void> _downloadJuz1Demo() async {
    final s = ref.read(settingsProvider);
    if (s.reciterId == null) return;
    final dm = ref.read(downloadManagerProvider);
    final (q, skipped) = await dm.enqueueScope(
      scope: const DownloadScope.juz(30),
      readingId: s.readingId,
      reciterId: s.reciterId!,
      wifiOnly: s.wifiOnly,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(skipped > 0 && q == 0
            ? 'No licensed audio source registered for this reciter yet.'
            : 'Juz 30: queued $q file(s).')));
  }

  Future<void> _downloadQuran() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Download entire Quran?'),
        content: const Text(
            'This queues ~6236 files per reciter. Only files with a registered licensed source will download. Continue on Wi-Fi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Download')),
        ],
      ),
    );
    if (ok != true) return;
    final s = ref.read(settingsProvider);
    if (s.reciterId == null) return;
    final dm = ref.read(downloadManagerProvider);
    final (q, skipped) = await dm.enqueueScope(
      scope: const DownloadScope.quran(),
      readingId: s.readingId,
      reciterId: s.reciterId!,
      wifiOnly: s.wifiOnly,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Queued $q file(s)${skipped > 0 ? ', $skipped skipped (no source)' : ''}.')));
  }

  Future<void> _deleteReciter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete downloaded audio?'),
        content: const Text(
            'Only audio files are removed. Quran text, bookmarks and progress are never touched.'),
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
    final s = ref.read(settingsProvider);
    if (s.reciterId == null) return;
    final freed = await ref
        .read(downloadManagerProvider)
        .deleteLocalForReciter(s.reciterId!, readingId: s.readingId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Freed ${(freed / 1048576).toStringAsFixed(1)} MB.')));
    await _refreshProg();
  }
}
