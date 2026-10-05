// Quran reader: surah list + search.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../services/providers.dart';
import '../widgets/ayat_card.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});
  @override
  ConsumerState<QuranScreen> createState() => _QuranState();
}

class _QuranState extends ConsumerState<QuranScreen> {
  final _q = TextEditingController();
  List<AyahDetail> _results = [];
  bool _searching = false;
  String _filter = '';

  Future<void> _search(String v) async {
    setState(() => _searching = true);
    final settings = ref.read(settingsProvider);
    final r = await ref.read(quranRepoProvider).search(v,
        readingId: settings.readingId, lang: settings.trLang, limit: 40);
    if (!mounted) return;
    setState(() {
      _results = r;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = kSurahs.where((s) =>
        _filter.isEmpty ||
        s.latin.toLowerCase().contains(_filter.toLowerCase()) ||
        '${s.number}' == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Quran')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              controller: _q,
              hintText: 'Search Arabic, translation, surah…',
              leading: const Icon(Icons.search),
              onChanged: (v) {
                if (v.trim().length >= 2) {
                  _search(v);
                } else {
                  setState(() {
                    _results = [];
                    _filter = v.trim();
                  });
                }
              },
              onSubmitted: _search,
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          Expanded(
            child: _q.text.trim().length >= 2
                ? (_results.isEmpty && !_searching
                    ? const EmptyState(icon: Icons.search_off, message: 'No results. Try another word.')
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (c, i) {
                          final d = _results[i];
                          final settings = ref.read(settingsProvider);
                          return ListTile(
                            title: Text('QS. ${kSurahs[d.surah - 1].latin} : ${d.ayah} [${d.readingId}]',
                                textDirection: TextDirection.ltr),
                            subtitle: Text(
                              (settings.trLang == 'en'
                                      ? d.enTranslation
                                      : d.idTranslation) ??
                                  d.arabic,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/quran/${d.surah}'),
                          );
                        },
                      ))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final s = list[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${s.number}')),
                        title: Text(s.latin),
                        subtitle: Text('${s.ayahs} ayat • ${s.revelation}'),
                        trailing: Text(s.arabic,
                            style: const TextStyle(fontSize: 20)),
                        onTap: () => context.go('/quran/${s.number}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
