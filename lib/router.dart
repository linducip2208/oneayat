// GoRouter: onboarding + 5-tab shell (Home, Quran, Saved, History, Settings).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/audio_settings_screen.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/prayer_settings_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sources_screen.dart';
import 'screens/storage_screen.dart';
import 'screens/surah_detail_screen.dart';

GoRouter buildRouter({required bool onboarded}) {
  return GoRouter(
    initialLocation: onboarded ? '/home' : '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, nav) => ScaffoldShell(nav: nav),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/quran', builder: (_, __) => const QuranScreen()),
            GoRoute(
              path: '/quran/:surah',
              builder: (_, st) => SurahDetailScreen(
                surah: int.parse(st.pathParameters['surah'] ?? '1')),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/saved', builder: (_, __) => const BookmarksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
            GoRoute(path: '/settings/reading', builder: (_, __) => const ReadingScreen()),
            GoRoute(path: '/settings/audio', builder: (_, __) => const AudioSettingsScreen()),
            GoRoute(path: '/settings/storage', builder: (_, __) => const StorageScreen()),
            GoRoute(path: '/settings/sources', builder: (_, __) => const SourcesScreen()),
            GoRoute(path: '/settings/prayer', builder: (_, __) => const PrayerSettingsScreen()),
          ]),
        ],
      ),
    ],
  );
}

class ScaffoldShell extends StatelessWidget {
  final StatefulNavigationShell nav;
  const ScaffoldShell({super.key, required this.nav});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: nav,
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.currentIndex,
        onDestinationSelected: (i) => nav.goBranch(i, initialLocation: i == nav.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Quran'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
