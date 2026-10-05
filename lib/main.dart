// ONE AYAT — entry point. Offline-first, fast startup, lazy DB.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'services/app_router_holder.dart';
import 'services/launch_action.dart';
import 'services/notification_service.dart';
import 'services/providers.dart';
import 'services/streak_freeze.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  final settings = container.read(settingsProvider);
  try {
    await settings.load();
  } catch (_) {}
  // Warm DB (seeds 114 surahs + bundled ayat on first run; migrates v1->v2).
  try {
    await container.read(dbProvider).checkHealth();
  } catch (_) {}
  // Interrupted downloads become resumable (never auto-restart).
  try {
    await container.read(downloadManagerProvider).resetStuck();
  } catch (_) {}
  try {
    await container.read(notifProvider).init();
    final health = await container.read(dbProvider).checkHealth();
    // Smart daily reminder (ayat snippet + auto-skip read days).
    await container.read(dailyReminderProvider).reschedule(settings,
        fullCoverage: health.fullCoverage);
    // Refresh adzan alarms (7 days ahead) on every start.
    await container.read(adhanProvider).reschedule(settings);
  } catch (_) {}
  try {
    await container.read(adsProvider).init(premiumUser: settings.premium);
  } catch (_) {}
  // Notification action handled in main isolate (mark-read / freeze):
  // refresh Home + reschedule smart reminder.
  NotificationService.onActionHandled = () async {
    try {
      container.read(homeReloadProvider.notifier).state++;
      final health = await container.read(dbProvider).checkHealth();
      await container.read(dailyReminderProvider).reschedule(
          container.read(settingsProvider),
          fullCoverage: health.fullCoverage);
    } catch (_) {}
  };
  // Widget "Tandai dibaca" button: mark today's ayat without opening reader.
  try {
    if (await LaunchAction.consume() == 'mark') {
      await handleWidgetMarkRead();
    }
  } catch (_) {}
  runApp(UncontrolledProviderScope(
    container: container,
    child: OneAyatApp(onboarded: settings.onboarded),
  ));
}

class OneAyatApp extends ConsumerWidget {
  final bool onboarded;
  const OneAyatApp({super.key, required this.onboarded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    ref.watch(settingsTickProvider);
    final mode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final amoled = settings.themeMode == 'amoled';
    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C5B)),
    );
    var dark = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7C5B), brightness: Brightness.dark),
    );
    if (amoled) {
      dark = dark.copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: dark.colorScheme.copyWith(surface: Colors.black),
      );
    }
    final router = buildRouter(onboarded: onboarded);
    AppRouterHolder.router = router;
    return MaterialApp.router(
      title: 'ONE AYAT',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      routerConfig: router,
    );
  }
}
