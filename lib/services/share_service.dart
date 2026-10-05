// Share: text share + beautiful branded image via RepaintBoundary screenshot.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';

class ShareService {
  static Future<void> shareText(AyahDetail d, String surahName) async {
    final text =
        '${d.arabic}\n\n"${d.idTranslation ?? d.enTranslation ?? ''}"\n\nQS. $surahName (${d.surah}:${d.ayah}) — ONE AYAT · One Day. One Ayat.';
    await SharePlus.instance.share(ShareParams(text: text.trim()));
  }

  static Future<String?> captureAndShare(GlobalKey key, String fileName) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'ONE AYAT · One Day. One Ayat.',
      ));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> captureBytes(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
