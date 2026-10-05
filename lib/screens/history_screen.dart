// History + simple statistics.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../services/progress_logic.dart';
import '../services/providers.dart';
import '../widgets/ayat_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistState();
}

class _HistState extends ConsumerState<HistoryScreen> {
  List<HistoryEntry> _items = [];
  bool _loading = true;
  int _days = 0, _streak = 0, _longest = 0, _bm = 0, _notes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = ref.read(progressRepoProvider);
    final items = await p.history();
    final days = await p.daysCompleted();
    final (cur, lon) = await p.streaks();
    final bm = (await p.bookmarks()).length;
    final notes = await p.noteCount();
    if (!mounted) return;
    setState(() {
      _items = items;
      _days = days;
      _streak = cur;
      _longest = lon;
      _bm = bm;
      _notes = notes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final stats = journeyStats(daysCompleted: _days, currentStreak: _streak, longestStreak: _longest, pacePerDay: settings.pacePerDay);
    return Scaffold(
      appBar: AppBar(title: const Text('History & Stats')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 16, runSpacing: 12,
                      children: [
                        _stat(context, 'Ayat read', '${stats.totalAyatRead}'),
                        _stat(context, 'Days active', '$_days'),
                        _stat(context, 'Streak', '$_streak'),
                        _stat(context, 'Longest', '$_longest'),
                        _stat(context, 'Bookmarks', '$_bm'),
                        _stat(context, 'Notes', '$_notes'),
                        _stat(context, 'Journey', '${stats.progressPct.toStringAsFixed(2)}%'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  const EmptyState(icon: Icons.history, message: 'No history yet.\nYour read ayat will appear here.')
                else
                  for (final h in _items)
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text('${h.date} — ${kSurahs[h.surah - 1].latin} ${h.ayah}'),
                      subtitle: Text('QS. ${h.surah}:${h.ayah}'),
                    ),
              ],
            ),
    );
  }

  Widget _stat(BuildContext c, String label, String value) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(c).textTheme.bodySmall),
        ],
      ),
    );
  }
}
