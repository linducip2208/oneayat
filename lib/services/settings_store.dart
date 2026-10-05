// Simple settings store (SharedPreferences): app lang, translation lang,
// theme, fonts, reminder, pace, premium flag, onboarding.
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _appLang = 'app_lang';
  static const _trLang = 'tr_lang';
  static const _theme = 'theme_mode'; // light|dark|system|amoled
  static const _arabicSize = 'arabic_size';
  static const _trSize = 'tr_size';
  static const _lineHeight = 'line_height';
  static const _showTr = 'show_transliteration';
  static const _showTl = 'show_translation';
  static const _reminderOn = 'reminder_enabled';
  static const _reminderH = 'reminder_hour';
  static const _reminderM = 'reminder_minute';
  static const _onboarded = 'onboarded';
  static const _pace = 'pace_per_day';
  static const _premium = 'premium';
  // v2: readings / reciter / audio / tafsir / storage
  static const _reading = 'reading_id';
  static const _tafsirLang = 'tafsir_lang';
  static const _showTafsir = 'show_tafsir';
  static const _reciter = 'reciter_id';
  static const _repeat = 'repeat_mode'; // off|1|3|5|10
  static const _speed = 'audio_speed'; // 0.75|1|1.25|1.5
  static const _autoplay = 'autoplay_next';
  static const _wifiOnly = 'wifi_only';

  String appLang = 'id';
  String trLang = 'id';
  String themeMode = 'system';
  double arabicSize = 30;
  double trSize = 16;
  double lineHeight = 1.9;
  bool showTransliteration = true;
  bool showTranslation = true;
  bool reminderEnabled = true;
  int reminderHour = 8;
  int reminderMinute = 0;
  bool onboarded = false;
  int pacePerDay = 1;
  bool premium = false;
  String readingId = 'hafs-madinah';
  String tafsirLang = 'id';
  bool showTafsir = false;
  String? reciterId;
  String repeatMode = 'off';
  double audioSpeed = 1.0;
  bool autoplayNext = false;
  bool wifiOnly = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    appLang = p.getString(_appLang) ?? 'id';
    trLang = p.getString(_trLang) ?? (appLang == 'en' ? 'en' : 'id');
    themeMode = p.getString(_theme) ?? 'system';
    arabicSize = p.getDouble(_arabicSize) ?? 30;
    trSize = p.getDouble(_trSize) ?? 16;
    lineHeight = p.getDouble(_lineHeight) ?? 1.9;
    showTransliteration = p.getBool(_showTr) ?? true;
    showTranslation = p.getBool(_showTl) ?? true;
    reminderEnabled = p.getBool(_reminderOn) ?? true;
    reminderHour = p.getInt(_reminderH) ?? 8;
    reminderMinute = p.getInt(_reminderM) ?? 0;
    onboarded = p.getBool(_onboarded) ?? false;
    pacePerDay = p.getInt(_pace) ?? 1;
    premium = p.getBool(_premium) ?? false;
    readingId = p.getString(_reading) ?? 'hafs-madinah';
    tafsirLang = p.getString(_tafsirLang) ?? (appLang == 'en' ? 'en' : 'id');
    showTafsir = p.getBool(_showTafsir) ?? false;
    reciterId = p.getString(_reciter);
    repeatMode = p.getString(_repeat) ?? 'off';
    audioSpeed = p.getDouble(_speed) ?? 1.0;
    autoplayNext = p.getBool(_autoplay) ?? false;
    wifiOnly = p.getBool(_wifiOnly) ?? true;
  }

  Future<void> _set<T>(Future<bool> Function(SharedPreferences) fn) async {
    final p = await SharedPreferences.getInstance();
    await fn(p);
  }

  Future<void> setAppLang(String v) async { appLang = v; await _set((p) async => p.setString(_appLang, v)); }
  Future<void> setTrLang(String v) async { trLang = v; await _set((p) async => p.setString(_trLang, v)); }
  Future<void> setTheme(String v) async { themeMode = v; await _set((p) async => p.setString(_theme, v)); }
  Future<void> setArabicSize(double v) async { arabicSize = v; await _set((p) async => p.setDouble(_arabicSize, v)); }
  Future<void> setTrSize(double v) async { trSize = v; await _set((p) async => p.setDouble(_trSize, v)); }
  Future<void> setLineHeight(double v) async { lineHeight = v; await _set((p) async => p.setDouble(_lineHeight, v)); }
  Future<void> setShowTransliteration(bool v) async { showTransliteration = v; await _set((p) async => p.setBool(_showTr, v)); }
  Future<void> setShowTranslation(bool v) async { showTranslation = v; await _set((p) async => p.setBool(_showTl, v)); }
  Future<void> setReminder(bool on, int h, int m) async {
    reminderEnabled = on; reminderHour = h; reminderMinute = m;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_reminderOn, on);
    await p.setInt(_reminderH, h);
    await p.setInt(_reminderM, m);
  }

  Future<void> setOnboarded() async { onboarded = true; await _set((p) async => p.setBool(_onboarded, true)); }
  Future<void> setPace(int v) async { pacePerDay = v; await _set((p) async => p.setInt(_pace, v)); }
  Future<void> setReading(String v) async { readingId = v; await _set((p) async => p.setString(_reading, v)); }
  Future<void> setTafsirLang(String v) async { tafsirLang = v; await _set((p) async => p.setString(_tafsirLang, v)); }
  Future<void> setShowTafsir(bool v) async { showTafsir = v; await _set((p) async => p.setBool(_showTafsir, v)); }
  Future<void> setReciter(String? v) async {
    reciterId = v;
    final p = await SharedPreferences.getInstance();
    if (v == null) {
      await p.remove(_reciter);
    } else {
      await p.setString(_reciter, v);
    }
  }

  Future<void> setRepeat(String v) async { repeatMode = v; await _set((p) async => p.setString(_repeat, v)); }
  Future<void> setSpeed(double v) async { audioSpeed = v; await _set((p) async => p.setDouble(_speed, v)); }
  Future<void> setAutoplay(bool v) async { autoplayNext = v; await _set((p) async => p.setBool(_autoplay, v)); }
  Future<void> setWifiOnly(bool v) async { wifiOnly = v; await _set((p) async => p.setBool(_wifiOnly, v)); }
}
