# ONE AYAT — One Day. One Ayat.

Offline-first daily Quran companion (Flutter + SQLite, no backend, no account).

Every day the app presents **one** Quran verse: Arabic (Madinah-oriented
rendering, Hafs default / Warsh optional), translation, transliteration,
optional tafsir, offline audio, private reflection note, and shareable card.

## Features

- **Daily ayat (locked 24h)** — deterministic schedule, one-tap listen,
  tap-to-open tafsir, mark-as-read, streak + journey progress (x/6236)
- **Smart reminder** — notification carries the ayat snippet, auto-skips read
  days, gentle tone after a miss, streak milestones, tap opens today's ayat,
  actions: ✓ mark-read, ⏰ snooze 1h (2x/day), ❄ freeze yesterday (2x/month)
- **Streak-freeze + repay** — frozen days keep streak without ayat count;
  repay by reading the missed ayat; ❄ marker in History
- **Adzan alarms (offline)** — computed on-device (Kemenag default), 18 cities
  or one-tap GPS, per-prayer toggles, 7-day schedule, Home prayer card
- **Quran reader** — surah list/detail, reading-aware search, bookmarks with
  folders, notes, history, statistics, JSON backup/restore
- **Audio (optional download)** — per-reciter, resumable, checksum-verified,
  Wi-Fi-only option, plays fully offline; no streaming, no bundled audio
- **Widget** — today's ayat on the home screen; tap opens app, button marks read
- **Weekly recap** (Friday), **smart hour suggestion**, onboarding, ID/EN UI,
  Light/Dark/AMOLED, AdMob (test IDs; premium-ready abstraction)

## Offline & privacy

Core Quran features work with zero network. No account, no cloud, no tracking.
Location permission is optional (GPS prayer fix only); manual city works
without it. See `store/privacy-policy.md`.

## Build

```sh
flutter pub get
dart analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

App ID `com.oneayat.app`, version in `pubspec.yaml`.

## Quran data

- Bundled: Hafs sample (47 ayat: Al-Fatihah, Ad-Duha, Asy-Syarh, Al-Asr,
  Al-Kautsar, Al-Ikhlas, Al-Falaq, An-Nas) + community sample translations.
- Full 6236-ayah import: `dart run tools/import_quran.dart --in dataset.json
  --reading hafs-madinah` (Warsh independently). Only licensed/redistributable
  datasets — see `tools/README_IMPORT.md`. Never invent Quran text.
- Audio/translation/tafsir/reciter licensing shown in-app:
  Settings → About → Quran Sources & Licenses.

## Project layout

- `lib/core` — constants, 114-surah metadata (facts, 6236 total)
- `lib/quran` — readings catalog, Mushaf rendering config (font swappable)
- `lib/data` — SQLite (v2, non-destructive migrations), repositories
- `lib/services` — prayer math, schedulers, downloads, audio, share, streak
- `lib/screens`, `lib/widgets`, `lib/l10n` — Material 3 UI, ID/EN
- `tools/` — dataset validator/importer docs
- `store/` — Play listing (ID/EN) + privacy policy
- `test/` — 56+ unit & widget tests
