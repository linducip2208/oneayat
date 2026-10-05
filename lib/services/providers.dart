// Riverpod providers (simple, no codegen).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/quran_repository.dart';
import 'ad_service.dart';
import 'adhan_scheduler.dart';
import 'audio_service.dart';
import 'daily_reminder.dart';
import 'download_manager.dart';
import 'notification_service.dart';
import 'progress_repository.dart';
import 'reciter_repository.dart';
import 'settings_store.dart';

final dbProvider = Provider<QuranDatabase>((_) => QuranDatabase());
final quranRepoProvider =
    Provider<QuranRepository>((ref) => QuranRepository(ref.watch(dbProvider)));
final progressRepoProvider =
    Provider<ProgressRepository>((ref) => ProgressRepository(ref.watch(dbProvider)));
final reciterRepoProvider =
    Provider<ReciterRepository>((ref) => ReciterRepository(ref.watch(dbProvider)));
final downloadManagerProvider =
    Provider<DownloadManager>((ref) => DownloadManager(ref.watch(reciterRepoProvider)));
final settingsProvider = Provider<AppSettings>((_) => AppSettings());
final notifProvider = Provider<NotificationService>((_) => NotificationService());
final adhanProvider =
    Provider<AdhanScheduler>((ref) => AdhanScheduler(ref.watch(notifProvider)));
final dailyReminderProvider = Provider<DailyReminderScheduler>((ref) =>
    DailyReminderScheduler(ref.watch(notifProvider),
        ref.watch(quranRepoProvider), ref.watch(progressRepoProvider)));
final audioProvider = Provider<AyatAudioService>((_) => AyatAudioService());
final adsProvider = Provider<AdService>((_) => AdService());

/// Bump to refresh daily/home after actions.
final refreshTickProvider = StateProvider<int>((_) => 0);
final settingsTickProvider = StateProvider<int>((_) => 0);
