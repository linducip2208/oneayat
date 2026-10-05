// Mushaf-first Ayat card: Arabic dominant, then translation/transliteration/
// tafsir, then controls (audio status-aware, bookmark, share, more).
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../quran/mushaf_config.dart';
import '../quran/readings.dart';
import '../services/settings_store.dart';

class AyatCard extends StatelessWidget {
  final AyahDetail detail;
  final String surahName;
  final String readingLabel;
  final AppSettings settings;
  final GlobalKey shareKey;
  final bool bookmarked;
  final AudioStatus audioStatus;
  final int audioProgress;
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
    required this.onToggleBookmark,
    required this.onShare,
    required this.onPlay,
    required this.onDownloadAudio,
    required this.onMore,
    required this.note,
    required this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trText = detail.translationFor(settings.trLang);
    final src = detail.translationSource;
    return RepaintBoundary(
      key: shareKey,
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Surah header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'QS. $surahName : ${detail.ayah}  •  Juz ${detail.juz}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert, size: 20),
                  ),
                ],
              ),
              Text(
                readingLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant, letterSpacing: 0.6),
              ),
              const SizedBox(height: 16),
              // Dominant Arabic (verbatim, reading-aware rendering)
              MushafText(
                text: '${detail.tajwid ?? detail.arabic}  ${ayahMarker(detail.ayah)}',
                readingId: detail.readingId,
                fontSize: settings.arabicSize,
                height: settings.lineHeight,
              ),
              if (mushafConfigFor(detail.readingId).licensedFamily == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Madinah-oriented rendering (fallback font — licensed Madinah font can be added via assets)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                ),
              if (settings.showTransliteration &&
                  detail.transliteration != null) ...[
                const SizedBox(height: 12),
                Text(detail.transliteration!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant)),
              ],
              if (settings.showTranslation && trText != null) ...[
                const SizedBox(height: 12),
                Text(trText,
                    style:
                        TextStyle(fontSize: settings.trSize, height: 1.6)),
                if (src != null && src.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('— $src',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ),
              ],
              if (settings.showTafsir && detail.tafsir != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.surfaceContainerLow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tafsir${detail.tafsirScholar != null ? ' — ${detail.tafsirScholar}' : ''}',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(detail.tafsir!,
                          style: TextStyle(
                              fontSize: settings.trSize - 1, height: 1.6)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _audioRow(context),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onToggleBookmark,
                    icon: Icon(
                        bookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                        size: 18),
                    label: Text(bookmarked ? 'Saved' : 'Save'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: onEditNote,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    (note == null || note!.isEmpty)
                        ? '“What does this ayat mean to me today?” — tap to reflect'
                        : '🖊 $note',
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

  Widget _audioRow(BuildContext context) {
    switch (audioStatus) {
      case AudioStatus.ready:
        return FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Play offline'),
        );
      case AudioStatus.downloading:
      case AudioStatus.queued:
      case AudioStatus.verifying:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: audioProgress / 100),
            const SizedBox(height: 6),
            Text('Downloading… $audioProgress%',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      case AudioStatus.paused:
        return OutlinedButton.icon(
          onPressed: onDownloadAudio,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: Text('Resume download ($audioProgress%)'),
        );
      case AudioStatus.failed:
        return OutlinedButton.icon(
          onPressed: onDownloadAudio,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Download failed — retry'),
        );
      case AudioStatus.notDownloaded:
        return OutlinedButton.icon(
          onPressed: onDownloadAudio,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Audio not downloaded — download'),
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
