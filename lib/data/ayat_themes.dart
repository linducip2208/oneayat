// Curated themes for bundled sample ayat (keys 'surah:ayah').
// Full-dataset themes can be added via importer later; unknown keys = untagged.
const Map<String, List<String>> kAyatThemes = {
  'sabar': ['94:5', '94:6', '103:3'],
  'syukur': ['93:11', '108:1', '93:5'],
  'gelisah': ['93:3', '94:1', '94:2', '113:1', '114:1'],
  'ikhlas': ['112:1', '112:2', '108:2'],
  'waktu': ['103:1', '103:2'],
  'yatim': ['93:9', '93:6'],
  'tauhid': ['112:1', '112:4', '114:1', '114:2', '114:3'],
  'doa': ['1:5', '1:6', '113:1', '114:1'],
  'syukur-nikmat': ['93:5', '93:8'],
};

/// Themes for one ayat key.
List<String> themesOf(String key) => [
      for (final e in kAyatThemes.entries)
        if (e.value.contains(key)) e.key,
    ];

/// Count theme hits across history keys (pure, tested).
Map<String, int> themeCounts(Iterable<String> keys) {
  final out = <String, int>{};
  for (final k in keys) {
    for (final t in themesOf(k)) {
      out[t] = (out[t] ?? 0) + 1;
    }
  }
  return out;
}
