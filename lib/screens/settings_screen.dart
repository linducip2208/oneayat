// Settings: language, theme, reading, reminder, pace, data, backup, about.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
import '../l10n/strings.dart';
import '../quran/readings.dart';
import '../services/providers.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SetState();
}

class _SetState extends ConsumerState<SettingsScreen> {
  DbHealth? _health;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await ref.read(dbProvider).checkHealth();
    if (!mounted) return;
    setState(() {
      _health = h;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    ref.watch(settingsTickProvider);
    final t = L10n(s.appLang);
    return Scaffold(
      appBar: AppBar(title: Text(t.get('settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(context, 'Language / Bahasa'),
                ListTile(
                  title: const Text('App language'),
                  trailing: DropdownButton<String>(
                    value: s.appLang,
                    items: const [
                      DropdownMenuItem(value: 'id', child: Text('Indonesia')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setAppLang(v);
                      ref.read(settingsTickProvider.notifier).state++;
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Quran translation'),
                  trailing: DropdownButton<String>(
                    value: s.trLang,
                    items: const [
                      DropdownMenuItem(value: 'id', child: Text('Indonesia')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setTrLang(v);
                      ref.read(settingsTickProvider.notifier).state++;
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Tafsir language'),
                  trailing: DropdownButton<String>(
                    value: s.tafsirLang,
                    items: const [
                      DropdownMenuItem(value: 'id', child: Text('Indonesia')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setTafsirLang(v);
                      ref.read(settingsTickProvider.notifier).state++;
                    },
                  ),
                ),
                SwitchListTile(
                  title: const Text('Show tafsir in reader'),
                  value: s.showTafsir,
                  onChanged: (v) async {
                    await s.setShowTafsir(v);
                    ref.read(settingsTickProvider.notifier).state++;
                  },
                ),
                _section(context, 'Quran'),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Reading / Riwayah'),
                  subtitle: Text(kQuranReadings
                          .where((r) => r.id == s.readingId)
                          .map((r) => r.name)
                          .firstOrNull ??
                      s.readingId),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/reading'),
                ),
                _section(context, t.get('theme')),
                ListTile(
                  title: Text(t.get('theme')),
                  trailing: DropdownButton<String>(
                    value: s.themeMode,
                    items: const [
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                      DropdownMenuItem(value: 'system', child: Text('System')),
                      DropdownMenuItem(value: 'amoled', child: Text('AMOLED')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setTheme(v);
                      ref.read(settingsTickProvider.notifier).state++;
                    },
                  ),
                ),
                _section(context, t.get('reading')),
                _slider(context, t.get('arabic_size'), s.arabicSize, 20, 44, (v) async {
                  await s.setArabicSize(v);
                  ref.read(settingsTickProvider.notifier).state++;
                }),
                _slider(context, t.get('translation_size'), s.trSize, 12, 24, (v) async {
                  await s.setTrSize(v);
                  ref.read(settingsTickProvider.notifier).state++;
                }),
                SwitchListTile(
                  title: Text(t.get('show_tr')),
                  value: s.showTransliteration,
                  onChanged: (v) async {
                    await s.setShowTransliteration(v);
                    ref.read(settingsTickProvider.notifier).state++;
                  },
                ),
                SwitchListTile(
                  title: Text(t.get('show_tl')),
                  value: s.showTranslation,
                  onChanged: (v) async {
                    await s.setShowTranslation(v);
                    ref.read(settingsTickProvider.notifier).state++;
                  },
                ),
                ListTile(
                  title: const Text('Reading pace (future-ready)'),
                  trailing: DropdownButton<int>(
                    value: s.pacePerDay,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 ayat/day')),
                      DropdownMenuItem(value: 3, child: Text('3 ayat/day')),
                      DropdownMenuItem(value: 5, child: Text('5 ayat/day')),
                      DropdownMenuItem(value: 10, child: Text('10 ayat/day')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setPace(v);
                      ref.read(refreshTickProvider.notifier).state++;
                      setState(() {});
                    },
                  ),
                ),
                _section(context, t.get('reminder')),
                ListTile(
                  leading: const Icon(Icons.mosque_outlined),
                  title: const Text('Prayer / Adzan alarms'),
                  subtitle: Text(s.adhanEnabled
                      ? 'On • ${s.adhanCity}'
                      : 'Off'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/prayer'),
                ),
                SwitchListTile(
                  title: Text(t.get('reminder')),
                  value: s.reminderEnabled,
                  onChanged: (v) async {
                    await s.setReminder(v, s.reminderHour, s.reminderMinute);
                    await _rescheduleReminder();
                    setState(() {});
                  },
                ),
                ListTile(
                  title: Text(t.get('reminder_time')),
                  trailing: Text(
                      '${s.reminderHour.toString().padLeft(2, '0')}:${s.reminderMinute.toString().padLeft(2, '0')}'),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
                    );
                    if (picked == null) return;
                    await s.setReminder(s.reminderEnabled, picked.hour, picked.minute);
                    await _rescheduleReminder();
                    setState(() {});
                  },
                ),
                _section(context, t.get('data_full')),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Surahs: ${_health?.surahCount ?? 0}/114\n'
                      'Hafs text: ${_health?.hafsAyahCount ?? 0} / 6236\n'
                      'Warsh text: ${_health?.warshAyahCount ?? 0} / 6236\n'
                      'Full Quran coverage: ${(_health?.fullCoverage ?? false) ? 'YES' : 'NOT YET — import via tools/import_quran.dart'}\n'
                      'Translation sources: ${_health?.languageCount ?? 0}',
                    ),
                  ),
                ),
                _section(context, 'Audio & Storage'),
                ListTile(
                  leading: const Icon(Icons.audio_file_outlined),
                  title: const Text('Audio / Reciter'),
                  subtitle: Text(s.reciterId ?? 'No reciter selected'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/audio'),
                ),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Storage'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/storage'),
                ),
                _section(context, t.get('backup')),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _backup,
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Backup JSON'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Restore: place backup JSON in app docs, then use importer (docs in README).'))),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Restore'),
                      ),
                    ),
                  ],
                ),
                _section(context, 'Audio'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Audio is optional and downloadable (Settings > Audio / Reciter).\n'
                      'Files live in app storage as audio/<reading>/<reciter>/<surah>/<ayah>.mp3 and play fully offline.\n'
                      'Reciter names appear only when a licensed dataset is registered.',
                    ),
                  ),
                ),
                _section(context, 'About'),
                ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: const Text('Quran Sources & Licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/sources'),
                ),
                _section(context, 'Privacy'),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No account. No cloud. All bookmarks, notes, history stay on-device.\n'
                      'Ads use Google test IDs until you configure real AdMob IDs.'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('ONE AYAT 1.0.0 • One Day. One Ayat. • com.oneayat.app',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _section(BuildContext c, String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(title,
            style: Theme.of(c).textTheme.labelLarge?.copyWith(
                color: Theme.of(c).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );

  Widget _slider(BuildContext c, String label, double v, double min, double max,
      Future<void> Function(double) onChanged) {
    return ListTile(
      title: Text('$label (${v.toStringAsFixed(0)})'),
      subtitle: Slider(value: v, min: min, max: max, onChanged: (x) => onChanged(x)),
    );
  }

  Future<void> _rescheduleReminder() async {
    final s = ref.read(settingsProvider);
    final health = await ref.read(dbProvider).checkHealth();
    await ref.read(dailyReminderProvider).reschedule(s,
        fullCoverage: health.fullCoverage);
  }

  Future<void> _backup() async {
    final data = await ref.read(progressRepoProvider).exportJson();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/oneayat_backup.json');
    await f.writeAsString(jsonEncode(data));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path)],
      text: 'ONE AYAT backup',
    ));
  }
}
