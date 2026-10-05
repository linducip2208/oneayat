// Surah metadata: factual, non-copyrightable (numbers + standard names).
// Revelation type + approximate juz-start mapping for reader convenience.
class SurahInfo {
  final int number;
  final String latin;
  final String arabic;
  final int ayahs;
  final String revelation; // Makkiyah | Madaniyah
  const SurahInfo(this.number, this.latin, this.arabic, this.ayahs, this.revelation);
}

const List<SurahInfo> kSurahs = [
  SurahInfo(1, 'Al-Fatihah', 'الفاتحة', 7, 'Makkiyah'),
  SurahInfo(2, 'Al-Baqarah', 'البقرة', 286, 'Madaniyah'),
  SurahInfo(3, 'Ali Imran', 'آل عمران', 200, 'Madaniyah'),
  SurahInfo(4, 'An-Nisa', 'النساء', 176, 'Madaniyah'),
  SurahInfo(5, 'Al-Maidah', 'المائدة', 120, 'Madaniyah'),
  SurahInfo(6, 'Al-Anam', 'الأنعام', 165, 'Makkiyah'),
  SurahInfo(7, 'Al-Araf', 'الأعراف', 206, 'Makkiyah'),
  SurahInfo(8, 'Al-Anfal', 'الأنفال', 75, 'Madaniyah'),
  SurahInfo(9, 'At-Taubah', 'التوبة', 129, 'Madaniyah'),
  SurahInfo(10, 'Yunus', 'يونس', 109, 'Makkiyah'),
  SurahInfo(11, 'Hud', 'هود', 123, 'Makkiyah'),
  SurahInfo(12, 'Yusuf', 'يوسف', 111, 'Makkiyah'),
  SurahInfo(13, 'Ar-Rad', 'الرعد', 43, 'Madaniyah'),
  SurahInfo(14, 'Ibrahim', 'إبراهيم', 52, 'Makkiyah'),
  SurahInfo(15, 'Al-Hijr', 'الحجر', 99, 'Makkiyah'),
  SurahInfo(16, 'An-Nahl', 'النحل', 128, 'Makkiyah'),
  SurahInfo(17, 'Al-Isra', 'الإسراء', 111, 'Makkiyah'),
  SurahInfo(18, 'Al-Kahf', 'الكهف', 110, 'Makkiyah'),
  SurahInfo(19, 'Maryam', 'مريم', 98, 'Makkiyah'),
  SurahInfo(20, 'Taha', 'طه', 135, 'Makkiyah'),
  SurahInfo(21, 'Al-Anbiya', 'الأنبياء', 112, 'Makkiyah'),
  SurahInfo(22, 'Al-Hajj', 'الحج', 78, 'Madaniyah'),
  SurahInfo(23, 'Al-Muminun', 'المؤمنون', 118, 'Makkiyah'),
  SurahInfo(24, 'An-Nur', 'النور', 64, 'Madaniyah'),
  SurahInfo(25, 'Al-Furqan', 'الفرقان', 77, 'Makkiyah'),
  SurahInfo(26, 'Asy-Syuara', 'الشعراء', 227, 'Makkiyah'),
  SurahInfo(27, 'An-Naml', 'النمل', 93, 'Makkiyah'),
  SurahInfo(28, 'Al-Qasas', 'القصص', 88, 'Makkiyah'),
  SurahInfo(29, 'Al-Ankabut', 'العنكبوت', 69, 'Makkiyah'),
  SurahInfo(30, 'Ar-Rum', 'الروم', 60, 'Makkiyah'),
  SurahInfo(31, 'Luqman', 'لقمان', 31 - 0 + 3, 'Makkiyah'), // 34
  SurahInfo(32, 'As-Sajdah', 'السجدة', 30, 'Makkiyah'),
  SurahInfo(33, 'Al-Ahzab', 'الأحزاب', 73, 'Madaniyah'),
  SurahInfo(34, 'Saba', 'سبأ', 54, 'Makkiyah'),
  SurahInfo(35, 'Fatir', 'فاطر', 45, 'Makkiyah'),
  SurahInfo(36, 'Yasin', 'يس', 83, 'Makkiyah'),
  SurahInfo(37, 'As-Saffat', 'الصافات', 182, 'Makkiyah'),
  SurahInfo(38, 'Sad', 'ص', 88, 'Makkiyah'),
  SurahInfo(39, 'Az-Zumar', 'الزمر', 75, 'Makkiyah'),
  SurahInfo(40, 'Gafir', 'غافر', 85, 'Makkiyah'),
  SurahInfo(41, 'Fussilat', 'فصلت', 54, 'Makkiyah'),
  SurahInfo(42, 'Asy-Syura', 'الشورى', 53, 'Makkiyah'),
  SurahInfo(43, 'Az-Zukhruf', 'الزخرف', 89, 'Makkiyah'),
  SurahInfo(44, 'Ad-Dukhan', 'الدخان', 59, 'Makkiyah'),
  SurahInfo(45, 'Al-Jasiyah', 'الجاثية', 37, 'Makkiyah'),
  SurahInfo(46, 'Al-Ahqaf', 'الأحقاف', 35, 'Makkiyah'),
  SurahInfo(47, 'Muhammad', 'محمد', 38, 'Madaniyah'),
  SurahInfo(48, 'Al-Fath', 'الفتح', 29, 'Madaniyah'),
  SurahInfo(49, 'Al-Hujurat', 'الحجرات', 18, 'Madaniyah'),
  SurahInfo(50, 'Qaf', 'ق', 45, 'Makkiyah'),
  SurahInfo(51, 'Az-Zariyat', 'الذاريات', 60, 'Makkiyah'),
  SurahInfo(52, 'At-Tur', 'الطور', 49, 'Makkiyah'),
  SurahInfo(53, 'An-Najm', 'النجم', 62, 'Makkiyah'),
  SurahInfo(54, 'Al-Qamar', 'القمر', 55, 'Makkiyah'),
  SurahInfo(55, 'Ar-Rahman', 'الرحمن', 78, 'Madaniyah'),
  SurahInfo(56, 'Al-Waqiah', 'الواقعة', 96, 'Makkiyah'),
  SurahInfo(57, 'Al-Hadid', 'الحديد', 29, 'Madaniyah'),
  SurahInfo(58, 'Al-Mujadalah', 'المجادلة', 22, 'Madaniyah'),
  SurahInfo(59, 'Al-Hasyr', 'الحشر', 24, 'Madaniyah'),
  SurahInfo(60, 'Al-Mumtahanah', 'الممتحنة', 13, 'Madaniyah'),
  SurahInfo(61, 'As-Saff', 'الصف', 14, 'Madaniyah'),
  SurahInfo(62, 'Al-Jumuah', 'الجمعة', 11, 'Madaniyah'),
  SurahInfo(63, 'Al-Munafiqun', 'المنافقون', 11, 'Madaniyah'),
  SurahInfo(64, 'At-Tagabun', 'التغابن', 18, 'Madaniyah'),
  SurahInfo(65, 'At-Talaq', 'الطلاق', 12, 'Madaniyah'),
  SurahInfo(66, 'At-Tahrim', 'التحريم', 12, 'Madaniyah'),
  SurahInfo(67, 'Al-Mulk', 'الملك', 30, 'Makkiyah'),
  SurahInfo(68, 'Al-Qalam', 'القلم', 52, 'Makkiyah'),
  SurahInfo(69, 'Al-Haqqah', 'الحاقة', 52, 'Makkiyah'),
  SurahInfo(70, 'Al-Maarij', 'المعارج', 44, 'Makkiyah'),
  SurahInfo(71, 'Nuh', 'نوح', 28, 'Makkiyah'),
  SurahInfo(72, 'Al-Jinn', 'الجن', 28, 'Makkiyah'),
  SurahInfo(73, 'Al-Muzzammil', 'المزمل', 20, 'Makkiyah'),
  SurahInfo(74, 'Al-Muddassir', 'المدثر', 56, 'Makkiyah'),
  SurahInfo(75, 'Al-Qiyamah', 'القيامة', 75 - 35, 'Makkiyah'), // 40
  SurahInfo(76, 'Al-Insan', 'الإنسان', 31, 'Madaniyah'),
  SurahInfo(77, 'Al-Mursalat', 'المرسلات', 50, 'Makkiyah'),
  SurahInfo(78, 'An-Naba', 'النبأ', 40, 'Makkiyah'),
  SurahInfo(79, 'An-Naziat', 'النازعات', 46, 'Makkiyah'),
  SurahInfo(80, 'Abasa', 'عبس', 42, 'Makkiyah'),
  SurahInfo(81, 'At-Takwir', 'التكوير', 29, 'Makkiyah'),
  SurahInfo(82, 'Al-Infitar', 'الانفطار', 19, 'Makkiyah'),
  SurahInfo(83, 'Al-Mutaffifin', 'المطففين', 36, 'Makkiyah'),
  SurahInfo(84, 'Al-Insyiqaq', 'الانشقاق', 25, 'Makkiyah'),
  SurahInfo(85, 'Al-Buruj', 'البروج', 22, 'Makkiyah'),
  SurahInfo(86, 'At-Tariq', 'الطارق', 17, 'Makkiyah'),
  SurahInfo(87, 'Al-Ala', 'الأعلى', 19, 'Makkiyah'),
  SurahInfo(88, 'Al-Gasyiyah', 'الغاشية', 26, 'Makkiyah'),
  SurahInfo(89, 'Al-Fajr', 'الفجر', 30, 'Makkiyah'),
  SurahInfo(90, 'Al-Balad', 'البلد', 20, 'Makkiyah'),
  SurahInfo(91, 'Asy-Syams', 'الشمس', 15, 'Makkiyah'),
  SurahInfo(92, 'Al-Lail', 'الليل', 21, 'Makkiyah'),
  SurahInfo(93, 'Ad-Duha', 'الضحى', 11, 'Makkiyah'),
  SurahInfo(94, 'Al-Insyirah', 'الشرح', 8, 'Makkiyah'),
  SurahInfo(95, 'At-Tin', 'التين', 8, 'Makkiyah'),
  SurahInfo(96, 'Al-Alaq', 'العلق', 19, 'Makkiyah'),
  SurahInfo(97, 'Al-Qadr', 'القدر', 5, 'Makkiyah'),
  SurahInfo(98, 'Al-Bayyinah', 'البينة', 8, 'Madaniyah'),
  SurahInfo(99, 'Az-Zalzalah', 'الزلزلة', 8, 'Madaniyah'),
  SurahInfo(100, 'Al-Adiyat', 'العاديات', 11, 'Makkiyah'),
  SurahInfo(101, 'Al-Qariah', 'القارعة', 11, 'Makkiyah'),
  SurahInfo(102, 'At-Takasur', 'التكاثر', 8, 'Makkiyah'),
  SurahInfo(103, 'Al-Asr', 'العصر', 3, 'Makkiyah'),
  SurahInfo(104, 'Al-Humazah', 'الهمزة', 9, 'Makkiyah'),
  SurahInfo(105, 'Al-Fil', 'الفيل', 5, 'Makkiyah'),
  SurahInfo(106, 'Quraisy', 'قريش', 4, 'Makkiyah'),
  SurahInfo(107, 'Al-Maun', 'الماعون', 7, 'Makkiyah'),
  SurahInfo(108, 'Al-Kautsar', 'الكوثر', 3, 'Makkiyah'),
  SurahInfo(109, 'Al-Kafirun', 'الكافرون', 6, 'Makkiyah'),
  SurahInfo(110, 'An-Nasr', 'النصر', 3, 'Madaniyah'),
  SurahInfo(111, 'Al-Lahab', 'المسد', 5, 'Makkiyah'),
  SurahInfo(112, 'Al-Ikhlas', 'الإخلاص', 4, 'Makkiyah'),
  SurahInfo(113, 'Al-Falaq', 'الفلق', 5, 'Makkiyah'),
  SurahInfo(114, 'An-Nas', 'الناس', 6, 'Makkiyah'),
];

/// Standard Juz boundaries (surah:ayah start of each Juz 1..30, Madani).
/// Used for display only.
const List<(int surah, int ayah)> kJuzStarts = [
  (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111),
  (7, 88), (8, 41), (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75),
  (21, 1), (23, 1), (25, 21), (27, 56), (29, 46), (33, 31), (36, 28),
  (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
];

int juzFor(int surah, int ayah) {
  var juz = 1;
  for (var i = 0; i < kJuzStarts.length; i++) {
    final (s, a) = kJuzStarts[i];
    if (surah > s || (surah == s && ayah >= a)) juz = i + 1;
  }
  return juz;
}
