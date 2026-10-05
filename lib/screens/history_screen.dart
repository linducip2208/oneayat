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
  Set<String> _frozenDates = {};
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
    final frozen = await p.frozenDays();
    // Merge frozen days (no history row) as ❄ entries, newest first.
    final have = {for (final h in items) h.date};
    final merged = [...items];
    for (final f in frozen) {
      if (!have.contains(f.date)) merged.add(f);
    }
    merged.sort((a, b) => b.date.compareTo(a.date));
    final days = await p.daysCompleted();
    final (cur, lon) = await p.streaks();
    final bm = (await p.bookmarks()).length;
    final notes = await p.noteCount();
    if (!mounted) return;
    setState(() {
      _items = merged;
      _frozenDates = {for (final f in frozen) f.date};
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
                    Builder(builder: (c) {
                      final frozen = _frozenDates.contains(h.date);
                      return ListTile(
                        leading: Icon(frozen
                            ? Icons.ac_unit
                            : Icons.check_circle_outline),
                        title: Text(
                            '${frozen ? '❄ ' : ''}${h.date} — ${kSurahs[h.surah - 1].latin} ${h.ayah}'),
                        subtitle: Text(frozen
                            ? 'Frozen (streak kept) • QS. ${h.surah}:${h.ayah}'
                            : 'QS. ${h.surah}:${h.ayah}'),
                      );
                    }),
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
