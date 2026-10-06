// Home: daily ayat (reading-aware), streak, journey progress, prev/next.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/surah_metadata.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../quran/readings.dart';
import '../services/progress_logic.dart';
import '../services/ad_service.dart';
import '../services/app_day.dart';
import '../services/hijri.dart';
import '../services/prayer_times.dart';
import '../services/providers.dart';
import '../services/share_service.dart';
import '../services/streak_freeze.dart';
import '../services/widget_service.dart';
import '../widgets/ayat_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _shareKey = GlobalKey();
  AyahDetail? _detail;
  AyahRef? _ref;
  bool _loading = true;
  bool _bookmarked = false;
  bool _done = false;
  bool _fullCoverage = false;
  int _days = 0;
  int _streak = 0;
  int _longest = 0;
  int _freezeLeft = 2;
  HistoryEntry? _repay; // latest frozen day awaiting repay
  int? _suggestHour;
  String? _annivNote;
  String? _note;
  AudioStatus _audioStatus = AudioStatus.notDownloaded;
  int _audioProgress = 0;
  bool _playing = false;
  BannerAd? _banner;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(DateTime.now().toUtc());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _banner?.dispose();
    _playerSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Silent refresh: notification actions may have changed progress.
    if (state == AppLifecycleState.resumed && mounted) {
      _load(DateTime.now().toUtc(), silent: true);
    }
  }

  Future<void> _load(DateTime dateUtc, {bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final quran = ref.read(quranRepoProvider);
    final progress = ref.read(progressRepoProvider);
    final settings = ref.read(settingsProvider);
    final health = await ref.read(dbProvider).checkHealth();
    _fullCoverage = health.fullCoverage;
    final refDaily =
        await quran.dailyRef(dateUtc, fullCoverage: _fullCoverage);
    // Daily identity = (surah, ayah); displayed text follows selected reading.
    final det = await quran.ayahDetail(refDaily.surah, refDaily.ayah,
        readingId: settings.readingId, lang: settings.trLang);
    final key = settings.currentAppDayKey();
    final done = await progress.isDailyDone(key);
    final days = await progress.daysCompleted();
    final (cur, lon) = await progress.streaks();
    final bm = det == null
        ? false
        : await progress.isBookmarked(det.surah, det.ayah);
    final note =
        det == null ? null : await progress.noteFor(det.surah, det.ayah);
    var aStatus = AudioStatus.notDownloaded;
    var aProg = 0;
    final reciter = settings.reciterId;
    if (det != null && reciter != null) {
      final st = await ref.read(reciterRepoProvider).audioState(
          readingId: settings.readingId,
          reciterId: reciter,
          surah: det.surah,
          ayah: det.ayah);
      aStatus = st?.status ?? AudioStatus.notDownloaded;
      aProg = st?.progress ?? 0;
    }
    if (!mounted) return;
    var freezeLeft = _freezeLeft;
    HistoryEntry? repay = _repay;
    int? suggest = _suggestHour;
    try {
      freezeLeft = (await getFreezeStatus()).remaining;
      final frozen = await progress.frozenDays(limit: 1);
      repay = frozen.isEmpty ? null : frozen.first;
      final hours = await progress.readHours();
      final cand = suggestReminderHour(hours, settings.reminderHour);
      if (cand != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('suggested_$cand') ?? false)) {
          suggest = cand;
        } else {
          suggest = null;
        }
      } else {
        suggest = null;
      }
      // Anniversary: same ayat read exactly one year ago (+ its note).
      try {
        final ago = DateTime.now().subtract(const Duration(days: 365));
        final agoKey =
            '${ago.year.toString().padLeft(4, '0')}-${ago.month.toString().padLeft(2, '0')}-${ago.day.toString().padLeft(2, '0')}';
        final hist = await progress.history(limit: 400);
        final match = hist.where((h) =>
            h.date == agoKey &&
            h.surah == refDaily.surah &&
            h.ayah == refDaily.ayah);
        if (match.isNotEmpty) {
          _annivNote =
              await progress.noteFor(refDaily.surah, refDaily.ayah);
        } else {
          _annivNote = null;
        }
      } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _ref = refDaily;
      _detail = det;
      _done = done;
      _days = days;
      _streak = cur;
      _longest = lon;
      _freezeLeft = freezeLeft;
      _repay = repay;
      _suggestHour = suggest;
      _bookmarked = bm;
      _note = note;
      _audioStatus = aStatus;
      _audioProgress = aProg;
      _loading = false;
    });
    if (det != null) {
      WidgetService.updateDaily(
        arabic: det.arabic,
        ref: 'QS. ${quran.surahName(det.surah)} : ${det.ayah}',
      );
      _maybeBanner(settings.premium);
    }
  }

  void _maybeBanner(bool premium) {
    final ads = ref.read(adsProvider);
    if (!ads.bannerEnabled || _banner != null) return;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdService.bannerTestId,
      request: const AdRequest(),
      listener: BannerAdListener(onAdFailedToLoad: (a, _) => a.dispose()),
    )..load();
    setState(() => _banner = ad);
  }

  String _readingLabel(String id) =>
      kQuranReadings
          .where((r) => r.id == id)
          .map((r) => r.name)
          .firstOrNull ??
      id;

  int _repeatCount(String mode) => switch (mode) {
        '1' => 1,
        '3' => 3,
        '5' => 5,
        '10' => 10,
        _ => 0,
      };

  Future<void> _play() async {
    final det = _detail;
    if (det == null) return;
    final audio = ref.read(audioProvider);
    if (_playing) {
      await audio.pause();
      return;
    }
    final settings = ref.read(settingsProvider);
    final reciter = settings.reciterId;
    if (reciter == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No reciter selected — choose one in Settings > Audio.')),
      );
      return;
    }
    final dm = ref.read(downloadManagerProvider);
    final file = await dm.localFile(
        readingId: settings.readingId,
        reciterId: reciter,
        surah: det.surah,
        ayah: det.ayah);
    final ok = await audio.playFile(file.path,
        speed: settings.audioSpeed,
        repeatCount: _repeatCount(settings.repeatMode));
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not downloaded. Tap download first.')),
      );
      return;
    }
    await _playerSub?.cancel();
    // Home is locked to today's ayat for 24h: no auto-advance.
    // Repeat (1x/3x/5x/10x) is handled inside the audio controller.
    _playerSub = audio.stateStream.listen((st) {
      if (mounted) {
        setState(() {
          _playing = st.playing;
        });
      }
    });
  }

  Future<void> _download() async {
    final det = _detail;
    if (det == null) return;
    final settings = ref.read(settingsProvider);
    final reciter = settings.reciterId;
    if (reciter == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No reciter selected — choose one in Settings > Audio.')),
      );
      return;
    }
    final dm = ref.read(downloadManagerProvider);
    final (queued, skipped) = await dm.enqueueScope(
      scope: DownloadScope.single(det.surah, det.ayah),
      readingId: settings.readingId,
      reciterId: reciter,
      wifiOnly: settings.wifiOnly,
    );
    if (!mounted) return;
    if (queued == 0 && skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No licensed audio source registered for this reciter yet.')),
      );
    } else {
      setState(() {
        _audioStatus = AudioStatus.queued;
      });
      dm.events.listen((e) {
        if (mounted &&
            e.surah == det.surah &&
            e.ayah == det.ayah &&
            e.reciterId == reciter) {
          setState(() {
            _audioStatus = e.status;
            _audioProgress = e.progress;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    ref.watch(refreshTickProvider);
    ref.watch(settingsTickProvider);
    ref.listen<int>(homeReloadProvider, (_, __) {
      if (mounted) _load(DateTime.now().toUtc(), silent: true);
    });
    final t = L10n(settings.appLang);
    final stats = journeyStats(
        daysCompleted: _days,
        currentStreak: _streak,
        longestStreak: _longest,
        pacePerDay: settings.pacePerDay);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ONE AYAT'),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.go('/quran')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(DateTime.now().toUtc()),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(t.get('app_tagline'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(t.get('ayat_today'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(_readingLabel(settings.readingId),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 12),
                  if (_detail == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.readingId == 'warsh-madinah'
                                  ? 'Warsh text for this ayat is not installed yet. Import a licensed Warsh dataset (Settings > Quran > Reading), or switch back to Hafs.'
                                  : t.get('ayat_notext'),
                            ),
                            const SizedBox(height: 12),
                            if (settings.readingId != 'hafs-madinah')
                              OutlinedButton(
                                onPressed: () async {
                                  await settings.setReading('hafs-madinah');
                                  ref
                                      .read(settingsTickProvider.notifier)
                                      .state++;
                                  await _load(DateTime.now().toUtc());
                                },
                                child: const Text('Switch to Hafs'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    AyatCard(
                      detail: _detail!,
                      surahName: kSurahs[_detail!.surah - 1].latin,
                      readingLabel: _readingLabel(settings.readingId),
                      settings: settings,
                      shareKey: _shareKey,
                      bookmarked: _bookmarked,
                      audioStatus: _audioStatus,
                      audioProgress: _audioProgress,
                      isPlaying: _playing,
                      note: _note,
                      onEditNote: () => _editNote(),
                      onMore: () => _moreSheet(),
                      onToggleBookmark: () async {
                        await ref
                            .read(progressRepoProvider)
                            .toggleBookmark(
                                _detail!.surah, _detail!.ayah);
                        final bm = await ref
                            .read(progressRepoProvider)
                            .isBookmarked(_detail!.surah, _detail!.ayah);
                        setState(() => _bookmarked = bm);
                      },
                      onShare: () async {
                        await ShareService.captureAndShare(_shareKey,
                            'oneayat_${_detail!.surah}_${_detail!.ayah}');
                        if (_detail != null) {
                          await ShareService.shareText(_detail!,
                              kSurahs[_detail!.surah - 1].latin);
                        }
                      },
                      onPlay: _play,
                      onDownloadAudio: _download,
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _done
                        ? null
                        : () async {
                            if (_ref == null) return;
                            final sNow = ref.read(settingsProvider);
                            await ref
                                .read(progressRepoProvider)
                                .markDailyDone(
                                    sNow.currentAppDayKey(), _ref!);
                            // Re-run smart reminder: today's slot cancels
                            // automatically now that it is read.
                            final health =
                                await ref.read(dbProvider).checkHealth();
                            await ref
                                .read(dailyReminderProvider)
                                .reschedule(
                                    ref.read(settingsProvider),
                                    fullCoverage: health.fullCoverage);
                            ref
                                .read(refreshTickProvider.notifier)
                                .state++;
                            await _load(DateTime.now().toUtc());
                          },
                    icon: Icon(_done
                        ? Icons.check_circle
                        : Icons.check_circle_outline),
                    label: Text(_done ? t.get('done') : t.get('mark_done')),
                  ),
                  const SizedBox(height: 16),
                  if (_suggestHour != null) _suggestCard(context, settings),
                  if (_repay != null) _repayCard(context, settings),
                  if (_annivNote != null && _annivNote!.isNotEmpty)
                    _annivCard(context),
                  _ramadanCard(context, settings, stats.totalAyatRead),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🔥',
                                  style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Text('$_streak ${t.get('streak_day')}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(
                                  '$_days days · ${_days * settings.pacePerDay} ayat',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (stats.progressPct / 100)
                                .clamp(0.0, 1.0),
                            borderRadius: BorderRadius.circular(8),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${stats.progressPct.toStringAsFixed(2)}% ${t.get('journey')} · longest $_longest',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            settings.appLang == 'en'
                                ? '❄ Streak-freeze: $_freezeLeft left this month'
                                : '❄ Beku streak: tersisa $_freezeLeft bulan ini',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_banner != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(height: 50, child: AdWidget(ad: _banner!)),
                  ],
                  if (settings.showPrayerCard) ...[
                    const SizedBox(height: 12),
                    _prayerCard(context, settings),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _suggestCard(BuildContext context, dynamic settings) {
    final h = _suggestHour!;
    final label =
        '${h.toString().padLeft(2, '0')}:00';
    final isId = (settings.appLang as String) != 'en';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isId
                  ? 'Kamu biasanya membaca sekitar $label. Pindah reminder ke jam itu?'
                  : 'You usually read around $label. Move the reminder there?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: () => _acceptSuggestion(h),
                  child: Text(isId ? 'Ya, pindah' : 'Yes, move'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _dismissSuggestion(h),
                  child: Text(isId ? 'Nanti' : 'Later'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptSuggestion(int h) async {
    final s = ref.read(settingsProvider);
    await s.setReminder(s.reminderEnabled, h, 0);
    final health = await ref.read(dbProvider).checkHealth();
    await ref.read(dailyReminderProvider).reschedule(s,
        fullCoverage: health.fullCoverage);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('suggested_$h', true);
    if (mounted) {
      setState(() => _suggestHour = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reminder moved to ${h.toString().padLeft(2, '0')}:00')));
    }
  }

  Future<void> _dismissSuggestion(int h) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('suggested_$h', true);
    if (mounted) setState(() => _suggestHour = null);
  }

  Widget _repayCard(BuildContext context, dynamic settings) {
    final r = _repay!;
    final isId = (settings.appLang as String) != 'en';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isId
                  ? '❄ ${r.date} dibekukan — lunasi dengan membaca QS. ${kSurahs[r.surah - 1].latin} : ${r.ayah}?'
                  : '❄ ${r.date} was frozen — repay by reading ${kSurahs[r.surah - 1].latin} : ${r.ayah}?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: () => _repaySheet(r),
                  child: Text(isId ? 'Baca & lunasi' : 'Read & repay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _repaySheet(HistoryEntry r) async {
    final settings = ref.read(settingsProvider);
    final det = await ref.read(quranRepoProvider).ayahDetail(
        r.surah, r.ayah,
        readingId: settings.readingId, lang: settings.trLang);
    if (!mounted) return;
    final tr = det?.translationFor(settings.trLang);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'QS. ${kSurahs[r.surah - 1].latin} : ${r.ayah} (${r.date})',
                style: Theme.of(c)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (det != null)
                Text(det.arabic,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 24, height: 2.0)),
              if (tr != null) ...[
                const SizedBox(height: 12),
                Text(tr, style: const TextStyle(height: 1.6)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Tandai sudah dibaca (lunasi)'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await ref.read(progressRepoProvider).repayFrozen(r.date);
      final health = await ref.read(dbProvider).checkHealth();
      await ref.read(dailyReminderProvider).reschedule(
          ref.read(settingsProvider),
          fullCoverage: health.fullCoverage);
      ref.read(refreshTickProvider.notifier).state++;
      await _load(DateTime.now().toUtc());
    }
  }

  /// Anniversary: this same ayat was read exactly one year ago.
  Widget _annivCard(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🕰 Setahun lalu kamu membaca ayat ini',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('🖊 $_annivNote',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Ramadan mode: khatam target + manual juz checklist. Only in Ramadan.
  Widget _ramadanCard(
      BuildContext context, dynamic settings, int ayatRead) {
    final now = DateTime.now();
    final day = ramadanDay(now);
    if (day == 0) return const SizedBox.shrink();
    final left = ramadanRemaining(now);
    final perDay = khatamPerDay(ayatRead, now);
    final done = (settings.ramadanJuzDone as Set<int>).length;
    final isId = (settings.appLang as String) != 'en';
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isId
                      ? '🌙 Ramadan hari $day/30 • tersisa $left hari'
                      : '🌙 Ramadan day $day/30 • $left days left',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  isId
                      ? 'Target khatam: ~$perDay ayat/hari • Juz selesai: $done/30'
                      : 'Khatam pace: ~$perDay ayat/day • Juz done: $done/30',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (done / 30).clamp(0.0, 1.0),
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var j = 1; j <= 30; j++)
                      ChoiceChip(
                        label: Text('$j'),
                        selected: (settings.ramadanJuzDone as Set<int>)
                            .contains(j),
                        onSelected: (_) async {
                          await settings.toggleRamadanJuz(j);
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _prayerCard(BuildContext context, dynamic settings) {    final now = DateTime.now();
    final day = computePrayerDay(
      localDay: now,
      lat: settings.latitude as double,
      lon: settings.longitude as double,
      method: prayerMethodById(settings.prayerMethod as String),
      tzOffsetHours: now.timeZoneOffset.inMinutes.toDouble() / 60.0,
    );
    final next = day.nextFrom(now);
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    next == null
                        ? 'Prayer times • ${settings.adhanCity}'
                        : 'Next: ${prayerName(next.$1, settings.appLang as String)} ${hm(next.$2)} • ${settings.adhanCity}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final k in kAdhanKeys)
                  Text(
                    '${prayerName(k, settings.appLang as String)} ${hm(day.timeOf(k))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moreSheet() async {    if (_detail == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(
                  'Open ${kSurahs[_detail!.surah - 1].latin} in reader'),
              onTap: () {
                Navigator.pop(c);
                context.go('/quran/${_detail!.surah}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('Hafalan 1 menit'),
              onTap: () {
                Navigator.pop(c);
                context.go('/memorize');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Reading / Riwayah settings'),
              onTap: () {
                Navigator.pop(c);
                context.go('/settings/reading');
              },
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: const Text('Audio / Reciter settings'),
              onTap: () {
                Navigator.pop(c);
                context.go('/settings/audio');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote() async {
    if (_detail == null) return;
    final ctrl = TextEditingController(text: _note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reflection'),
        content: TextField(
            controller: ctrl,
            maxLines: 5,
            decoration: const InputDecoration(
                hintText: 'What does this ayat mean to me today?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(progressRepoProvider)
          .saveNote(_detail!.surah, _detail!.ayah, ctrl.text);
      final n = await ref
          .read(progressRepoProvider)
          .noteFor(_detail!.surah, _detail!.ayah);
      setState(() => _note = n);
    }
  }
}
