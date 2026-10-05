// Mushaf rendering configuration.
//
// The app NEVER claims a generic Arabic font *is* Mushaf Madinah.
// Each reading declares an ordered font stack + optional licensed font asset.
// To install a properly licensed Madinah font WITHOUT rewriting the app:
//   1. Drop the licensed .ttf under assets/fonts/ (with its license file)
//   2. Register family name in pubspec.yaml
//   3. Set `licensedFamily` for the reading below (or via quran_readings.font_family)
// Until then the reader uses the honest fallback stack and labels the
// rendering accordingly (see MushafText attribution line).
import 'package:flutter/material.dart';

class MushafFontConfig {
  final String readingId;
  final String? licensedFamily;
  final List<String> fallbackStack;
  final double arabicScale;
  const MushafFontConfig({
    required this.readingId,
    this.licensedFamily,
    required this.fallbackStack,
    this.arabicScale = 1.0,
  });

  List<String> get families => [
        ?licensedFamily,
        ...fallbackStack,
      ];
}

/// Asset-swappable per-reading config. No Quran text lives here.
const Map<String, MushafFontConfig> kMushafConfigs = {
  'hafs-madinah': MushafFontConfig(
    readingId: 'hafs-madinah',
    licensedFamily: null, // e.g. 'KFGQPC-Hafs' once a licensed asset is added
    fallbackStack: ['Amiri', 'Scheherazade New', 'Noto Naskh Arabic', 'serif'],
  ),
  'warsh-madinah': MushafFontConfig(
    readingId: 'warsh-madinah',
    licensedFamily: null, // e.g. 'KFGQPC-Warsh' once a licensed asset is added
    fallbackStack: ['Amiri', 'Scheherazade New', 'Noto Naskh Arabic', 'serif'],
  ),
};

MushafFontConfig mushafConfigFor(String readingId) =>
    kMushafConfigs[readingId] ?? kMushafConfigs['hafs-madinah']!;

/// Reading-aware Quran text widget. Renders stored text VERBATIM
/// (diacritics, waqf, tajwid, madd marks preserved — no normalization,
/// no cleaning, selectable for copy).
class MushafText extends StatelessWidget {
  final String text;
  final String readingId;
  final double fontSize;
  final double height;
  final TextAlign align;
  const MushafText({
    super.key,
    required this.text,
    required this.readingId,
    required this.fontSize,
    this.height = 2.0,
    this.align = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = mushafConfigFor(readingId);
    return SelectableText(
      text,
      textDirection: TextDirection.rtl,
      textAlign: align,
      style: TextStyle(
        fontSize: fontSize * cfg.arabicScale,
        height: height,
        fontFamilyFallback: cfg.families,
      ),
    );
  }
}
