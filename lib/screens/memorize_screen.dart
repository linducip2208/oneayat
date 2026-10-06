// Hafalan 1 menit: hide words, tap to peek, replay audio.
// Uses today's ayat; never alters stored Quran text.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../quran/readings.dart';
import '../services/providers.dart';

class MemorizeScreen extends ConsumerStatefulWidget {
  const MemorizeScreen({super.key});
  @override
  ConsumerState<MemorizeScreen> createState() => _MemState();
}

class _MemState extends ConsumerState<MemorizeScreen> {
  AyahDetail? _detail;
  bool _loading = true;
  int _level = 3; // hide every Nth word
  final _revealed = <int>{};
  bool _playing = false;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final quran = ref.read(quranRepoProvider);
    final settings = ref.read(settingsProvider);
    final health = await ref.read(dbProvider).checkHealth();
    final r =
        await quran.dailyRef(DateTime.now().toUtc(), fullCoverage: health.fullCoverage);
    final d = await quran.ayahDetail(r.surah, r.ayah,
        readingId: settings.readingId, lang: settings.trLang);
    if (!mounted) return;
    setState(() {
      _detail = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hafalan 1 menit')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final d = _detail;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hafalan 1 menit')),
        body: const Center(child: Text('Ayat hari ini belum tersedia.')),
      );
    }
    final words = d.arabic.split(RegExp(r'\s+'));
    return Scaffold(
      appBar: AppBar(title: const Text('Hafalan 1 menit')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('QS. ${kSurahs[d.surah - 1].latin} : ${d.ayah}',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(kQuranReadings
                  .where((r) => r.id == settings.readingId)
                  .map((r) => r.name)
                  .firstOrNull ??
              settings.readingId),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 12,
            textDirection: TextDirection.rtl,
            children: [
              for (var i = 0; i < words.length; i++)
                Builder(builder: (c) {
                  final hidden = i % _level == 0 && !_revealed.contains(i);
                  return InkWell(
                    onTap: () => setState(() {
                      if (!_revealed.remove(i)) _revealed.add(i);
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: hidden
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : null,
                      ),
                      child: Text(
                        hidden ? '•••' : words[i],
                        style: TextStyle(
                            fontSize: settings.arabicSize - 4, height: 2.0),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Level: '),
              DropdownButton<int>(
                value: _level,
                items: const [
                  DropdownMenuItem(value: 2, child: Text('Sulit (1/2)')),
                  DropdownMenuItem(value: 3, child: Text('Sedang (1/3)')),
                  DropdownMenuItem(value: 4, child: Text('Mudah (1/4)')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _level = v;
                    _revealed.clear();
                  });
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _revealed.clear()),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _playToggle,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            label: Text(_playing ? 'Jeda' : 'Putar ayat'),
          ),
          const SizedBox(height: 8),
          Text('Ketuk kata yang disembunyikan untuk mengintip.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _playToggle() async {
    final d = _detail;
    if (d == null) return;
    final audio = ref.read(audioProvider);
    if (_playing) {
      await audio.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final settings = ref.read(settingsProvider);
    if (settings.reciterId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih reciter dulu di Pengaturan > Audio.')));
      return;
    }
    final file = await ref.read(downloadManagerProvider).localFile(
        readingId: settings.readingId,
        reciterId: settings.reciterId!,
        surah: d.surah,
        ayah: d.ayah);
    final ok = await audio.playFile(file.path);
    if (mounted) setState(() => _playing = ok);
    await _playerSub?.cancel();
    _playerSub = audio.stateStream.listen((st) {
      if (mounted && !st.playing && _playing) {
        setState(() => _playing = false);
      }
    });
  }
}
