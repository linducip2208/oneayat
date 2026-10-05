# Quran data import — readings, translations, tafsir, reciters

The app ships with:

- `lib/core/surah_metadata.dart` — 114 surahs, ayah counts, juz starts (facts).
- `lib/data/seed_data.dart` — bundled **Hafs** sample (Al-Fatihah, Ad-Duha,
  Asy-Syarh, Al-Asr, Al-Kautsar, Al-Ikhlas, Al-Falaq, An-Nas) with community
  sample translations. Works offline on Day 1. Stored verbatim in
  `ayah_texts` under `reading_id = hafs-madinah`.
- `assets/seed/` — portable JSON mirrors for external tooling.

**Warsh is intentionally NOT bundled.** A `warsh-madinah` reading row exists
with zero ayahs; the UI shows an honest "not installed" state and never
mixes Hafs text into Warsh views.

## Full import (licensed data only)

1. Obtain Quran text + translations + tafsir + audio file lists you have the
   right to redistribute (your own work, public-domain, or written permission).
2. Build `dataset.json`:

```json
{
  "reading": "hafs-madinah",
  "sources": [
    {"code":"...","language":"ar","title":"...","license":"...","version":"1.0"}
  ],
  "ayahs": [
    {"surah":1,"ayah":1,"juz":1,"page":1,"arabic":"...","tajwid":"..."}
  ],
  "translations": [
    {"surah":1,"ayah":1,"lang":"id","translator":"...","text":"...","source":"...","license":"..."}
  ],
  "tafsirs": [
    {"surah":1,"ayah":1,"lang":"id","scholar":"...","title":"...","text":"...","source":"...","license":"..."}
  ],
  "reciters": [
    {"id":"reciter-a","name":"...","readings":["hafs-madinah"],"source":"...","license":"...",
     "files":[{"surah":1,"ayah":1,"url":"https://.../001_001.mp3","bytes":123,"sha256":"...","ms":1000}]}
  ]
}
```

3. Validate (per reading, independently):

```
dart run tools/import_quran.dart --in hafs.json --reading hafs-madinah
dart run tools/import_quran.dart --in warsh.json --reading warsh-madinah
```

Enforced: exactly 114 surahs, exact ayah counts (6236), no dupes/missing,
valid refs, translation/tafsir/audio refs resolve, reciter x reading
compatibility explicit, licenses present, tafsir scholar required.

4. Load into SQLite tables `ayah_texts / translations / tafsirs / reciters /
   reciter_readings / audio_files` (schema in `lib/data/db.dart`), or bundle
   under `assets/seed/<reading>/`.

## Madinah font asset (optional, licensed only)

1. Place the licensed `.ttf` + its license file under `assets/fonts/`
   (never commit a font you have no rights to).
2. Register the family in `pubspec.yaml`.
3. Set `licensedFamily` in `lib/quran/mushaf_config.dart`
   (or `quran_readings.font_family`). No app rewrite needed.

## Audio

Audio is NEVER bundled in the APK. Downloads go to app storage:
`audio/<reading>/<reciter>/<surah3>/<ayah3>.mp3`, resumable via HTTP Range,
SHA-256 verified when `sha256` is provided, playable fully offline.
