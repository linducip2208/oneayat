// Seed Quran content bundled with the app (offline-first).
// Arabic: Uthmani-inspired standard text (divine text, not copyrightable).
// Translations: concise community sample meanings, verified against well-known
// meanings. Marked as "sample" in translation_sources; replace/extend via
// tools/import_quran.dart with a licensed translation for full coverage.
// Full 114-surah structure (6236 ayahs) is always available via metadata;
// this seed bundles frequently-read surahs so Day-1 experience works offline.

import '../core/surah_metadata.dart';
import 'models.dart';

class TranslationSource {
  final String code; // e.g. 'id_sample', 'en_sample'
  final String language; // 'id' | 'en'
  final String title;
  final String license;
  final String version;
  const TranslationSource(this.code, this.language, this.title, this.license, this.version);
}

const List<TranslationSource> kTranslationSources = [
  TranslationSource('ar_uthmani', 'ar', 'Quran Arabic (Uthmani standard text)', 'Divine text — free to distribute', '1.0'),
  TranslationSource('id_sample', 'id', 'ONE AYAT Indonesian sample meanings', 'Community sample — verify before wide redistribution; replace with licensed Kemenag text via importer', '1.0'),
  TranslationSource('en_sample', 'en', 'ONE AYAT English sample meanings', 'Community sample — verify before wide redistribution; replace with licensed text via importer', '1.0'),
  TranslationSource('tr_sample', 'tr', 'Transliteration sample (Latin)', 'Community sample', '1.0'),
];

/// (surah, ayah, arabic, transliteration, id, en)
const List<(int, int, String, String, String, String)> kSeedAyahs = [
  (1, 1, 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', 'Bismillāhir-raḥmānir-raḥīm', 'Dengan nama Allah Yang Maha Pengasih lagi Maha Penyayang.', 'In the name of Allah, the Most Gracious, the Most Merciful.'),
  (1, 2, 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ', 'Al-ḥamdu lillāhi rabbil-ʿālamīn', 'Segala puji bagi Allah, Tuhan seluruh alam.', 'All praise belongs to Allah, Lord of the worlds.'),
  (1, 3, 'الرَّحْمَٰنِ الرَّحِيمِ', 'Ar-raḥmānir-raḥīm', 'Yang Maha Pengasih lagi Maha Penyayang.', 'The Most Gracious, the Most Merciful.'),
  (1, 4, 'مَالِكِ يَوْمِ الدِّينِ', 'Māliki yaumid-dīn', 'Pemilik hari pembalasan.', 'Master of the Day of Judgment.'),
  (1, 5, 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 'Iyyāka naʿbudu wa iyyāka nastaʿīn', 'Hanya kepada-Mu kami menyembah dan hanya kepada-Mu kami memohon pertolongan.', 'You alone we worship, and You alone we ask for help.'),
  (1, 6, 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ', 'Ihdinaṣ-ṣirāṭal-mustaqīm', 'Tunjukilah kami jalan yang lurus.', 'Guide us along the straight path.'),
  (1, 7, 'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ', 'Ṣirāṭallażīna anʿamta ʿalaihim gairil-magḍūbi ʿalaihim wa laḍ-ḍāllīn', '(Yaitu) jalan orang-orang yang telah Engkau beri nikmat, bukan (jalan) mereka yang dimurkai dan bukan (pula jalan) mereka yang sesat.', 'The path of those You have blessed, not of those who earned anger, nor of those who went astray.'),
  (94, 1, 'أَلَمْ نَشْرَحْ لَكَ صَدْرَكَ', 'Alam nasyraḥ laka ṣadrak', 'Bukankah Kami telah melapangkan dadamu (Muhammad)?', 'Did We not expand your chest for you?'),
  (94, 2, 'وَوَضَعْنَا عَنْكَ وِزْرَكَ', 'Wa waḍaʿnā ʿanka wizrak', 'Dan Kami telah menghilangkan bebanmu.', 'And We removed your burden.'),
  (94, 3, 'الَّذِي أَنْقَضَ ظَهْرَكَ', 'Allażī anqaḍa ẓahrak', 'Yang memberatkan punggungmu.', 'Which weighed heavily on your back.'),
  (94, 4, 'وَرَفَعْنَا لَكَ ذِكْرَكَ', 'Wa rafaʿnā laka żikrak', 'Dan Kami tinggikan sebutan (nama)mu.', 'And We raised high your renown.'),
  (94, 5, 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا', 'Fa inna maʿal-ʿusri yusrā', 'Maka sesungguhnya beserta kesulitan ada kemudahan.', 'So indeed, with hardship comes ease.'),
  (94, 6, 'إِنَّ مَعَ الْعُسْرِ يُسْرًا', 'Inna maʿal-ʿusri yusrā', 'Sesungguhnya beserta kesulitan itu ada kemudahan.', 'Indeed, with hardship comes ease.'),
  (94, 7, 'فَإِذَا فَرَغْتَ فَانْصَبْ', 'Fa iżā faragta fanṣab', 'Maka apabila engkau telah selesai (dari suatu urusan), tetaplah bekerja keras (untuk urusan yang lain).', 'So when you are free, devote yourself to worship.'),
  (94, 8, 'وَإِلَىٰ رَبِّكَ فَارْغَبْ', 'Wa ilā rabbika fargab', 'Dan hanya kepada Tuhanmulah engkau berharap.', 'And to your Lord turn your longing.'),
  (103, 1, 'وَالْعَصْرِ', 'Wal-ʿaṣr', 'Demi masa.', 'By time.'),
  (103, 2, 'إِنَّ الْإِنْسَانَ لَفِي خُسْرٍ', 'Innal-insāna lafī khusr', 'Sesungguhnya manusia benar-benar dalam kerugian.', 'Indeed, mankind is in loss.'),
  (103, 3, 'إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّبْرِ', 'Illallażīna āmanū wa ʿamiluṣ-ṣāliḥāti wa tawāṣau bil-ḥaqqi wa tawāṣau biṣ-ṣabr', 'Kecuali orang-orang yang beriman dan beramal saleh serta saling menasihati dalam kebenaran dan kesabaran.', 'Except those who believe, do righteous deeds, and advise one another to truth and patience.'),
  (108, 1, 'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ', 'Innā aʿṭainākal-kauṡar', 'Sesungguhnya Kami telah memberimu (Muhammad) nikmat yang banyak.', 'Indeed, We have granted you al-Kawthar.'),
  (108, 2, 'فَصَلِّ لِرَبِّكَ وَانْحَرْ', 'Fa ṣalli lirabbika wanḥar', 'Maka laksanakanlah salat karena Tuhanmu dan berkurbanlah.', 'So pray to your Lord and sacrifice.'),
  (108, 3, 'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ', 'Inna syāni-aka huwal-abtar', 'Sesungguhnya orang yang membencimu, dialah yang terputus (dari rahmat Allah).', 'Indeed, your enemy is the one cut off.'),
  (112, 1, 'قُلْ هُوَ اللَّهُ أَحَدٌ', 'Qul huwallāhu aḥad', 'Katakanlah (Muhammad): Dialah Allah Yang Maha Esa.', 'Say: He is Allah, the One.'),
  (112, 2, 'اللَّهُ الصَّمَدُ', 'Allāhuṣ-ṣamad', 'Allah tempat meminta segala sesuatu.', 'Allah, the Eternal Refuge.'),
  (112, 3, 'لَمْ يَلِدْ وَلَمْ يُولَدْ', 'Lam yalid wa lam yūlad', 'Dia tidak beranak dan tidak pula diperanakkan.', 'He neither begets nor is born.'),
  (112, 4, 'وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ', 'Wa lam yakul lahū kufuwan aḥad', 'Dan tidak ada sesuatu pun yang setara dengan Dia.', 'And there is none comparable to Him.'),
  (113, 1, 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ', 'Qul aʿūżu birabbil-falaq', 'Katakanlah: Aku berlindung kepada Tuhan yang (menjaga) fajar.', 'Say: I seek refuge with the Lord of the daybreak.'),
  (113, 2, 'مِنْ شَرِّ مَا خَلَقَ', 'Min syarri mā khalaq', 'Dari kejahatan (makhluk) yang Dia ciptakan.', 'From the evil of what He created.'),
  (113, 3, 'وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ', 'Wa min syarri gāsiqin iżā waqab', 'Dan dari kejahatan malam apabila telah gelap gulita.', 'And from the evil of darkness when it settles.'),
  (113, 4, 'وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ', 'Wa min syarrin-naffāṡāti fil-ʿuqad', 'Dan dari kejahatan (perempuan-perempuan) penyihir yang meniup pada buhul-buhul (talinya).', 'And from the evil of the blowers in knots.'),
  (113, 5, 'وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ', 'Wa min syarri ḥāsidin iżā ḥasad', 'Dan dari kejahatan orang yang dengki apabila dia dengki.', 'And from the evil of the envier when he envies.'),
  (114, 1, 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ', 'Qul aʿūżu birabbin-nās', 'Katakanlah: Aku berlindung kepada Tuhan manusia.', 'Say: I seek refuge with the Lord of mankind.'),
  (114, 2, 'مَلِكِ النَّاسِ', 'Malikin-nās', 'Raja manusia.', 'The King of mankind.'),
  (114, 3, 'إِلَٰهِ النَّاسِ', 'Ilāhin-nās', 'Sembahan manusia.', 'The God of mankind.'),
  (114, 4, 'مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ', 'Min syarril-waswāsil-khannās', 'Dari kejahatan (bisikan) setan yang bersembunyi.', 'From the evil of the retreating whisperer.'),
  (114, 5, 'الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ', 'Allażī yuwaswisu fī ṣudūrin-nās', 'Yang membisikkan (kejahatan) ke dalam dada manusia.', 'Who whispers into the chests of mankind.'),
  (114, 6, 'مِنَ الْجِنَّةِ وَالنَّاسِ', 'Minal-jinnati wan-nās', 'Dari (golongan) jin dan manusia.', 'From among jinn and mankind.'),
  (93, 1, 'وَالضُّحَىٰ', 'Waḍ-ḍuḥā', 'Demi waktu duha.', 'By the morning brightness.'),
  (93, 2, 'وَاللَّيْلِ إِذَا سَجَىٰ', 'Wal-laili iżā sajā', 'Dan demi malam apabila telah sunyi.', 'And by the night when it covers.'),
  (93, 3, 'مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ', 'Mā waddaʿaka rabbuka wa mā qalā', 'Tuhanmu tidak meninggalkanmu dan tidak (pula) membencimu.', 'Your Lord has not forsaken you, nor does He hate you.'),
  (93, 4, 'وَلَلْآخِرَةُ خَيْرٌ لَكَ مِنَ الْأُولَىٰ', 'Wa lal-ākhiratu khairul laka minal-ūlā', 'Dan sungguh akhirat itu lebih baik bagimu daripada dunia.', 'And the Hereafter is better for you than the first life.'),
  (93, 5, 'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ', 'Wa lasaufa yuʿṭīka rabbuka fa tarḍā', 'Dan sungguh kelak Tuhanmu pasti memberimu (karunia) hingga engkau rida.', 'And your Lord will surely give you, and you will be satisfied.'),
  (93, 6, 'أَلَمْ يَجِدْكَ يَتِيمًا فَآوَىٰ', 'Alam yajidka yatīman fa āwā', 'Bukankah Dia mendapatimu sebagai yatim, lalu Dia melindungimu?', 'Did He not find you an orphan and shelter you?'),
  (93, 7, 'وَوَجَدَكَ ضَالًّا فَهَدَىٰ', 'Wa wajadaka ḍāllan fa hadā', 'Dan Dia mendapatimu tersesat (jalan), lalu Dia memberimu petunjuk.', 'And He found you lost and guided you.'),
  (93, 8, 'وَوَجَدَكَ عَائِلًا فَأَغْنَىٰ', 'Wa wajadaka ʿā-ilan fa agnā', 'Dan Dia mendapatimu kekurangan, lalu Dia mencukupkanmu.', 'And He found you poor and made you self-sufficient.'),
  (93, 9, 'فَأَمَّا الْيَتِيمَ فَلَا تَقْهَرْ', 'Fa ammal-yatīma fa lā taqhar', 'Maka terhadap anak yatim, janganlah engkau berlaku sewenang-wenang.', 'So do not oppress the orphan.'),
  (93, 10, 'وَأَمَّا السَّائِلَ فَلَا تَنْهَرْ', 'Wa ammas-sā-ila fa lā tanhar', 'Dan terhadap orang yang meminta-minta, janganlah engkau menghardik.', 'And do not repel the beggar.'),
  (93, 11, 'وَأَمَّا بِنِعْمَةِ رَبِّكَ فَحَدِّثْ', 'Wa ammā biniʿmati rabbika fa ḥaddiṡ', 'Dan terhadap nikmat Tuhanmu, nyatakanlah (dengan bersyukur).', 'And proclaim the blessing of your Lord.'),
];

List<AyahDetail> buildSeedDetails() => [
  for (final s in kSeedAyahs)
    AyahDetail(
      surah: s.$1, ayah: s.$2, juz: juzFor(s.$1, s.$2),
      arabic: s.$3, transliteration: s.$4,
      idTranslation: s.$5, enTranslation: s.$6,
    ),
];

/// Keys bundled in seed (for deterministic daily rotation pre-full-import).
Set<String> get seedKeys => {for (final s in kSeedAyahs) '${s.$1}:${s.$2}'};
