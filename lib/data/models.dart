// Data models (plain Dart, SQLite-backed via repository).
class AyahRef {
  final int surah;
  final int ayah;
  const AyahRef(this.surah, this.ayah);
  String get key => '$surah:$ayah';
  @override
  bool operator ==(Object other) => other is AyahRef && other.surah == surah && other.ayah == ayah;
  @override
  int get hashCode => surah * 1000 + ayah;
}

class AyahDetail {
  final int surah;
  final int ayah;
  final int juz;
  final int? page;
  final String readingId;
  final String arabic;
  final String? tajwid;
  final String? transliteration;
  final String? idTranslation;
  final String? enTranslation;
  final String? translationSource;
  final String? tafsir;
  final String? tafsirScholar;
  const AyahDetail({
    required this.surah,
    required this.ayah,
    required this.juz,
    this.page,
    this.readingId = 'hafs-madinah',
    required this.arabic,
    this.tajwid,
    this.transliteration,
    this.idTranslation,
    this.enTranslation,
    this.translationSource,
    this.tafsir,
    this.tafsirScholar,
  });
  String get key => '$surah:$ayah';
  String? translationFor(String lang) =>
      lang == 'en' ? enTranslation : idTranslation;
}

class Bookmark {
  final int? id;
  final int surah;
  final int ayah;
  final int? folderId;
  final bool favorite;
  final int createdAt;
  const Bookmark({this.id, required this.surah, required this.ayah, this.folderId, this.favorite = false, required this.createdAt});
}

class BookmarkFolder {
  final int? id;
  final String name;
  final int createdAt;
  const BookmarkFolder({this.id, required this.name, required this.createdAt});
}

class Note {
  final int? id;
  final int surah;
  final int ayah;
  final String text;
  final int updatedAt;
  const Note({this.id, required this.surah, required this.ayah, required this.text, required this.updatedAt});
}

class HistoryEntry {
  final int? id;
  final int surah;
  final int ayah;
  final String date; // yyyy-MM-dd
  final int openedAt;
  const HistoryEntry({this.id, required this.surah, required this.ayah, required this.date, required this.openedAt});
}

// ---- v2: readings / reciters / audio / tafsir ----

/// Audio download state machine (persisted in audio_files.status).
enum AudioStatus {
  notDownloaded,
  queued,
  downloading,
  paused,
  failed,
  verifying,
  ready, // downloaded + verified, playable offline
}

AudioStatus audioStatusFrom(String? s) => switch (s) {
      'queued' => AudioStatus.queued,
      'downloading' => AudioStatus.downloading,
      'paused' => AudioStatus.paused,
      'failed' => AudioStatus.failed,
      'verifying' => AudioStatus.verifying,
      'ready' => AudioStatus.ready,
      _ => AudioStatus.notDownloaded,
    };

String audioStatusName(AudioStatus s) => s.name;

class ReciterInfo {
  final String id;
  final String name;
  final String language;
  final String country;
  final String description;
  final String? imageUrl;
  final String source;
  final String license;
  const ReciterInfo({
    required this.id,
    required this.name,
    required this.language,
    required this.country,
    required this.description,
    this.imageUrl,
    required this.source,
    required this.license,
  });
}

class AudioFileInfo {
  final int surah;
  final int ayah;
  final String readingId;
  final String reciterId;
  final String? remoteUrl;
  final String? localPath;
  final int? fileSize;
  final int downloadedBytes;
  final String? checksum;
  final int? durationMs;
  final AudioStatus status;
  final int progress; // 0..100
  const AudioFileInfo({
    required this.surah,
    required this.ayah,
    required this.readingId,
    required this.reciterId,
    this.remoteUrl,
    this.localPath,
    this.fileSize,
    this.downloadedBytes = 0,
    this.checksum,
    this.durationMs,
    this.status = AudioStatus.notDownloaded,
    this.progress = 0,
  });
}

class DownloadScope {
  final String kind; // ayat|surah|juz|quran
  final int? surah;
  final int? ayah;
  final int? juz;
  const DownloadScope.single(this.surah, this.ayah)
      : kind = 'ayat',
        juz = null;
  const DownloadScope.surah(this.surah)
      : kind = 'surah',
        juz = null,
        ayah = null;
  const DownloadScope.juz(this.juz)
      : kind = 'juz',
        surah = null,
        ayah = null;
  const DownloadScope.quran()
      : kind = 'quran',
        surah = null,
        juz = null,
        ayah = null;
}
