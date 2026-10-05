// Satu ayat, satu kartu: Arab dominan, satu tombol putar, tafsir ketuk-buka.
// Seluruh kartu scroll natural di dalam ListView bila teks panjang.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../quran/mushaf_config.dart';
import '../quran/readings.dart';
import '../services/settings_store.dart';

class AyatCard extends StatefulWidget {
  final AyahDetail detail;
  final String surahName;
  final String readingLabel;
  final AppSettings settings;
  final GlobalKey shareKey;
  final bool bookmarked;
  final AudioStatus audioStatus;
  final int audioProgress;
  final bool isPlaying;
  final VoidCallback onToggleBookmark;
  final VoidCallback onShare;
  final VoidCallback onPlay;
  final VoidCallback onDownloadAudio;
  final VoidCallback onMore;
  final String? note;
  final VoidCallback onEditNote;

  const AyatCard({
    super.key,
    required this.detail,
    required this.surahName,
    required this.readingLabel,
    required this.settings,
    required this.shareKey,
    required this.bookmarked,
    this.audioStatus = AudioStatus.notDownloaded,
    this.audioProgress = 0,
    this.isPlaying = false,
    required this.onToggleBookmark,
    required this.onShare,
    required this.onPlay,
    required this.onDownloadAudio,
    required this.onMore,
    required this.note,
    required this.onEditNote,
  });

  @override
  State<AyatCard> createState() => _AyatCardState();
}

class _AyatCardState extends State<AyatCard> {
  bool _tafsirOpen = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = widget.detail;
    final settings = widget.settings;
    final trText = d.translationFor(settings.trLang);
    return RepaintBoundary(
      key: widget.shareKey,
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'QS. ${widget.surahName} : ${d.ayah}  •  Juz ${d.juz}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: widget.onMore,
                    icon: const Icon(Icons.more_vert, size: 20),
                  ),
                ],
              ),
              Text(
                widget.readingLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant, letterSpacing: 0.6),
              ),
              const SizedBox(height: 16),
              MushafText(
                text:
                    '${d.tajwid ?? d.arabic}  ${ayahMarker(d.ayah)}',
                readingId: d.readingId,
                fontSize: settings.arabicSize,
                height: settings.lineHeight,
              ),
              if (settings.showTransliteration &&
                  d.transliteration != null) ...[
                const SizedBox(height: 12),
                Text(d.transliteration!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant)),
              ],
              if (settings.showTranslation && trText != null) ...[
                const SizedBox(height: 12),
                Text(trText,
                    style:
                        TextStyle(fontSize: settings.trSize, height: 1.6)),
                if ((d.translationSource ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('— ${d.translationSource}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ),
              ],
              // Tafsir: ketuk untuk buka/tutup.
              if (settings.showTafsir && d.tafsir != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () =>
                      setState(() => _tafsirOpen = !_tafsirOpen),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: scheme.surfaceContainerLow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tafsir${d.tafsirScholar != null ? ' — ${d.tafsirScholar}' : ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold),
                              ),
                            ),
                            Icon(_tafsirOpen
                                ? Icons.expand_less
                                : Icons.expand_more),
                          ],
                        ),
                        if (_tafsirOpen) ...[
                          const SizedBox(height: 6),
                          Text(d.tafsir!,
                              style: TextStyle(
                                  fontSize: settings.trSize - 1,
                                  height: 1.6)),
                        ] else
                          Text('Ketuk untuk membaca',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _audioBlock(context),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onToggleBookmark,
                      icon: Icon(
                          widget.bookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          size: 18),
                      label:
                          Text(widget.bookmarked ? 'Saved' : 'Save'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onShare,
                      icon:
                          const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: widget.onEditNote,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    (widget.note == null || widget.note!.isEmpty)
                        ? '“Apa makna ayat ini untukku hari ini?” — ketuk untuk merenung'
                        : '🖊 ${widget.note}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Satu blok audio: putar/jeda, unduh, atau progres — tinggal klik.
  Widget _audioBlock(BuildContext context) {
    switch (widget.audioStatus) {
      case AudioStatus.ready:
        return FilledButton.icon(
          onPressed: widget.onPlay,
          icon: Icon(
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 22),
          label: Text(widget.isPlaying ? 'Jeda' : 'Dengarkan',
              style: const TextStyle(fontSize: 16)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
      case AudioStatus.downloading:
      case AudioStatus.queued:
      case AudioStatus.verifying:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
                value: widget.audioProgress / 100),
            const SizedBox(height: 6),
            Text('Mengunduh… ${widget.audioProgress}%',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      case AudioStatus.paused:
        return FilledButton.icon(
          onPressed: widget.onDownloadAudio,
          icon: const Icon(Icons.download_outlined, size: 20),
          label: Text('Lanjutkan unduhan (${widget.audioProgress}%)'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
      case AudioStatus.failed:
        return FilledButton.icon(
          onPressed: widget.onDownloadAudio,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Unduhan gagal — ketuk untuk coba lagi'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
      case AudioStatus.notDownloaded:
        return FilledButton.tonalIcon(
          onPressed: widget.onDownloadAudio,
          icon: const Icon(Icons.download_outlined, size: 20),
          label: const Text('Unduh audio ayat ini'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
    }
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const EmptyState(
      {super.key, required this.icon, required this.message, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
