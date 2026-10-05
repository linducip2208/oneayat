// Surah reader: Mushaf-first (Arabic dominant), reading-aware,
// per-ayat offline audio status, tafsir on demand.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../quran/mushaf_config.dart';
import '../quran/readings.dart';
import '../services/providers.dart';
import '../services/share_service.dart';

class SurahDetailScreen extends ConsumerStatefulWidget {
  final int surah;
  const SurahDetailScreen({super.key, required this.surah});
  @override
  ConsumerState<SurahDetailScreen> createState() => _SurahDetailState();
}

class _SurahDetailState extends ConsumerState<SurahDetailScreen> {
  List<AyahDetail> _ayahs = [];
  bool _loading = true;
  Map<String, AudioStatus> _audio = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    final list = await ref.read(quranRepoProvider).ayahsOfSurah(widget.surah,
        readingId: settings.readingId, lang: settings.trLang);
    Map<String, AudioStatus> audio = {};
    if (settings.reciterId != null) {
      for (final d in list) {
        final st = await ref.read(reciterRepoProvider).audioState(
            readingId: settings.readingId,
            reciterId: settings.reciterId!,
            surah: d.surah,
            ayah: d.ayah);
        audio['${d.surah}:${d.ayah}'] =
            st?.status ?? AudioStatus.notDownloaded;
      }
    }
    if (!mounted) return;
    setState(() {
      _ayahs = list;
      _audio = audio;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = kSurahs[widget.surah - 1];
    final settings = ref.watch(settingsProvider);
    final readingName = kQuranReadings
            .where((r) => r.id == settings.readingId)
            .map((r) => r.name)
            .firstOrNull ??
        settings.readingId;
    return Scaffold(
      appBar: AppBar(title: Text('${info.number}. ${info.latin}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Surah header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                  child: Column(
                    children: [
                      Text(info.arabic,
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(
                          '${info.latin} • ${info.ayahs} ayat • ${info.revelation} • $readingName',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: _ayahs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              settings.readingId == 'warsh-madinah'
                                  ? 'Warsh text for ${info.latin} is not installed yet.\nImport a licensed Warsh dataset via Settings > Quran > Reading.'
                                  : 'Full text for ${info.latin} is not in the bundled seed yet.\nImport the full Quran pack via Settings > Data.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _ayahs.length,
                          itemBuilder: (c, i) {
                            final d = _ayahs[i];
                            final tr = d.translationFor(settings.trLang);
                            final ast = _audio['${d.surah}:${d.ayah}'] ??
                                AudioStatus.notDownloaded;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    MushafText(
                                      text:
                                          '${d.tajwid ?? d.arabic}  ${ayahMarker(d.ayah)}',
                                      readingId: d.readingId,
                                      fontSize: settings.arabicSize - 4,
                                      height: settings.lineHeight,
                                    ),
                                    if (settings.showTranslation &&
                                        tr != null) ...[
                                      const SizedBox(height: 8),
                                      Text('${d.ayah}. $tr',
                                          style: const TextStyle(
                                              height: 1.5)),
                                    ],
                                    if (settings.showTafsir &&
                                        d.tafsir != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                          'Tafsir${d.tafsirScholar != null ? ' — ${d.tafsirScholar}' : ''}: ${d.tafsir!}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: ast ==
                                                  AudioStatus.ready
                                              ? 'Play offline'
                                              : 'Audio: ${ast.name}',
                                          icon: Icon(ast ==
                                                  AudioStatus.ready
                                              ? Icons.play_arrow
                                              : Icons
                                                  .download_outlined),
                                          onPressed: () =>
                                              _onAudio(d, ast),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.share_outlined),
                                          onPressed: () =>
                                              ShareService.shareText(
                                                  d, info.latin),
                                        ),
                                        const Spacer(),
                                        if (d.page != null)
                                          Text('p.${d.page}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _onAudio(AyahDetail d, AudioStatus st) async {
    final settings = ref.read(settingsProvider);
    if (settings.reciterId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('No reciter selected — see Settings > Audio.')));
      return;
    }
    if (st == AudioStatus.ready) {
      final dm = ref.read(downloadManagerProvider);
      final file = await dm.localFile(
          readingId: settings.readingId,
          reciterId: settings.reciterId!,
          surah: d.surah,
          ayah: d.ayah);
      final ok = await ref
          .read(audioProvider)
          .playFile(file.path, speed: settings.audioSpeed);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file missing.')));
      }
    } else {
      final dm = ref.read(downloadManagerProvider);
      await dm.enqueueScope(
        scope: DownloadScope.single(d.surah, d.ayah),
        readingId: settings.readingId,
        reciterId: settings.reciterId!,
        wifiOnly: settings.wifiOnly,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download queued.')));
      }
    }
  }
}
