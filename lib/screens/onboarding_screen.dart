// Minimal 4-step onboarding, no account.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/strings.dart';
import '../services/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _ObState();
}

class _ObState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _idx = 0;
  String _lang = 'id';
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  @override
  Widget build(BuildContext context) {
    final t = L10n(_lang);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _idx = i),
                children: [
                  _step(
                    context,
                    title: 'ONE AYAT',
                    body: t.get('onboard_1'),
                    big: true,
                  ),
                  _step(
                    context,
                    title: t.get('onboard_2'),
                    body: '',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Indonesia'),
                          selected: _lang == 'id',
                          onSelected: (_) => setState(() => _lang = 'id'),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('English'),
                          selected: _lang == 'en',
                          onSelected: (_) => setState(() => _lang = 'en'),
                        ),
                      ],
                    ),
                  ),
                  _step(
                    context,
                    title: t.get('onboard_3'),
                    body: '',
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final p = await showTimePicker(context: context, initialTime: _time);
                        if (p != null) setState(() => _time = p);
                      },
                      child: Text('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  _step(
                    context,
                    title: t.get('start'),
                    body: t.get('app_tagline'),
                    child: FilledButton(
                      onPressed: _finish,
                      child: Text(t.get('start')),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.all(4),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _idx
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (_idx < 3) {
                        _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                      } else {
                        _finish();
                      }
                    },
                    child: Text(_idx < 3 ? 'Next' : t.get('start')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(BuildContext c, {required String title, required String body, bool big = false, Widget? child}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('ONE AYAT',
              style: Theme.of(c).textTheme.labelLarge?.copyWith(letterSpacing: 4)),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: big
                  ? Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)
                  : Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center),
          ],
          if (child != null) ...[const SizedBox(height: 24), child],
        ],
      ),
    );
  }

  Future<void> _finish() async {
    final s = ref.read(settingsProvider);
    await s.setAppLang(_lang);
    await s.setTrLang(_lang);
    await s.setReminder(true, _time.hour, _time.minute);
    final health = await ref.read(dbProvider).checkHealth();
    await ref.read(dailyReminderProvider).reschedule(s,
        fullCoverage: health.fullCoverage);
    await s.setOnboarded();
    if (mounted) context.go('/home');
  }
}
