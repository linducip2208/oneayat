// Settings → Prayer / Adzan: offline alarms. Manual city or one-tap GPS
// (permission asked only when GPS is tapped), method choice, per-prayer
// toggles. Schedules 7 days ahead.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/prayer_times.dart';
import '../services/providers.dart';

class PrayerSettingsScreen extends ConsumerStatefulWidget {
  const PrayerSettingsScreen({super.key});
  @override
  ConsumerState<PrayerSettingsScreen> createState() => _PrayerState();
}

class _PrayerState extends ConsumerState<PrayerSettingsScreen> {
  PrayerDay? _today;
  bool _gpsBusy = false;

  @override
  void initState() {
    super.initState();
    _preview();
  }

  Future<void> _preview() async {
    final s = ref.read(settingsProvider);
    final now = DateTime.now();
    final day = computePrayerDay(
      localDay: now,
      lat: s.latitude,
      lon: s.longitude,
      method: prayerMethodById(s.prayerMethod),
      tzOffsetHours: now.timeZoneOffset.inMinutes.toDouble() / 60.0,
    );
    if (mounted) setState(() => _today = day);
  }

  Future<void> _reschedule() async {
    await ref.read(adhanProvider).reschedule(ref.read(settingsProvider));
    await _preview();
  }

  Future<void> _useGps() async {
    setState(() => _gpsBusy = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'GPS permission denied — manual city still works fine.')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final near = nearestCity(pos.latitude, pos.longitude);
      final s = ref.read(settingsProvider);
      await s.setAdhanCity(
          'GPS · near ${near.name}', pos.latitude, pos.longitude);
      await _reschedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Location set: GPS near ${near.name}. Prayer times updated.')));
      }
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not get GPS fix — try again or pick a city.')));
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer / Adzan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Adzan alarms'),
            subtitle: const Text('Offline • no location permission needed'),
            value: s.adhanEnabled,
            onChanged: (v) async {
              await s.setAdhanEnabled(v);
              await _reschedule();
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('City'),
            subtitle: Text(s.adhanCity,
                style: Theme.of(context).textTheme.bodySmall),
            trailing: DropdownButton<String>(
              value: kPrayerCities.any((c) => c.name == s.adhanCity)
                  ? s.adhanCity
                  : kPrayerCities.first.name,
              items: [
                for (final c in kPrayerCities)
                  DropdownMenuItem(value: c.name, child: Text(c.name)),
              ],
              onChanged: (v) async {
                if (v == null) return;
                final c = kPrayerCities.firstWhere((e) => e.name == v);
                await s.setAdhanCity(c.name, c.lat, c.lon);
                await _reschedule();
                setState(() {});
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.my_location_outlined),
            title: const Text('Use my GPS location'),
            subtitle: const Text(
                'One-tap fix. Nearest city is shown; coordinates are used for math.'),
            trailing: _gpsBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _gpsBusy ? null : _useGps,
          ),
          ListTile(
            title: const Text('Method'),
            trailing: DropdownButton<String>(
              value: s.prayerMethod,
              items: [
                for (final m in kPrayerMethods)
                  DropdownMenuItem(value: m.id, child: Text(m.name)),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await s.setPrayerMethod(v);
                await _reschedule();
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('ALARM PER PRAYER',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(letterSpacing: 1.5)),
          for (final k in kAdhanKeys)
            SwitchListTile(
              title: Text(prayerName(k, s.appLang)),
              subtitle: _today == null
                  ? null
                  : Text('Today ${_hm(_today!.timeOf(k))}'),
              value: s.adhanFor(k),
              onChanged: !s.adhanEnabled
                  ? null
                  : (v) async {
                      await s.setAdhanPrayer(k, v);
                      await _reschedule();
                      setState(() {});
                    },
            ),
          SwitchListTile(
            title: const Text('Show prayer card on Home'),
            value: s.showPrayerCard,
            onChanged: (v) async {
              await s.setShowPrayerCard(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Alarms are local notifications scheduled 7 days ahead and '
                'refreshed on every app start. No bundled adzan audio: the '
                'alarm uses the default notification sound. A licensed adzan '
                'recording can later be added as res/raw/adhan.mp3.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
