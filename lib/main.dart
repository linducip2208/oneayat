// ONE AYAT — entry point. Offline-first, fast startup, lazy DB.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'services/providers.dart';

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
    await container.read(notifProvider).scheduleDaily(
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      enabled: settings.reminderEnabled,
      lang: settings.appLang,
    );
  } catch (_) {}
  try {
    await container.read(adsProvider).init(premiumUser: settings.premium);
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
    return MaterialApp.router(
      title: 'ONE AYAT',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      routerConfig: buildRouter(onboarded: onboarded),
    );
  }
}
