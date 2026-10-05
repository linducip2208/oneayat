// Localization: minimal Map-based ID/EN, extensible to more languages.
class L10n {
  final String lang; // 'id' | 'en'
  const L10n(this.lang);
  bool get isId => lang != 'en';

  static const _t = <String, (String id, String en)>{
    'app_tagline': ('Satu Hari. Satu Ayat.', 'One Day. One Ayat.'),
    'ayat_today': ('AYAT HARI INI', "TODAY'S AYAT"),
    'play': ('Putar', 'Play'),
    'bookmark': ('Simpan', 'Bookmark'),
    'share': ('Bagikan', 'Share'),
    'prev': ('Sebelumnya', 'Previous'),
    'next': ('Berikutnya', 'Next'),
    'mark_done': ('Tandai sudah dibaca', 'Mark as read'),
    'done': ('Sudah dibaca ✓', 'Read ✓'),
    'streak_day': ('hari beruntun', 'day streak'),
    'journey': ('Perjalanan Quran', 'Quran journey'),
    'home': ('Beranda', 'Home'),
    'quran': ('Quran', 'Quran'),
    'saved': ('Simpanan', 'Saved'),
    'history': ('Riwayat', 'History'),
    'settings': ('Pengaturan', 'Settings'),
    'search_hint': ('Cari Arab, terjemah, surah…', 'Search Arabic, translation, surah…'),
    'notes_title': ('Renungan pribadiku', 'My private reflection'),
    'notes_hint': ('Apa makna ayat ini untukku hari ini?', 'What does this ayat mean to me today?'),
    'save': ('Simpan', 'Save'),
    'reminder': ('Pengingat harian', 'Daily reminder'),
    'reminder_time': ('Waktu pengingat', 'Reminder time'),
    'reading': ('Pengaturan bacaan', 'Reading settings'),
    'arabic_size': ('Ukuran Arab', 'Arabic size'),
    'translation_size': ('Ukuran terjemah', 'Translation size'),
    'show_tr': ('Tampilkan transliterasi', 'Show transliteration'),
    'show_tl': ('Tampilkan terjemah', 'Show translation'),
    'theme': ('Tema', 'Theme'),
    'data_full': ('Data lengkap', 'Full data'),
    'backup': ('Cadangan', 'Backup'),
    'stats': ('Statistik', 'Statistics'),
    'onboard_1': ('Satu Hari.\nSatu Ayat.', 'One Day.\nOne Ayat.'),
    'onboard_2': ('Pilih bahasa aplikasi', 'Choose app language'),
    'onboard_3': ('Pilih waktu pengingat', 'Choose reminder time'),
    'start': ('Mulai Perjalanan', 'Start Journey'),
    'ayat_notext': ('Teks lengkap belum diimpor. Lihat Pengaturan > Data untuk mengimpor paket Quran lengkap.', 'Full text not yet imported. See Settings > Data to import the full Quran pack.'),
  };

  String get(String key) {
    final v = _t[key];
    if (v == null) return key;
    return isId ? v.$1 : v.$2;
  }
}
