// Offline-only ayat audio playback (just_audio over LOCAL files).
// Never streams: if the file is not downloaded, callers show
// "Audio not downloaded [DOWNLOAD]". Repeat counts, speed, autoplay-next
// respect the selected reading + reciter via explicit file paths.
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../data/models.dart';

class OfflineAudioController {
  final AudioPlayer _player = AudioPlayer();
  bool playing = false;
  String? currentPath;
  int repeatLeft = 0; // extra repeats after the first play

  Stream<bool> get playingStream => _player.playingStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get stateStream => _player.playerStateStream;

  Future<bool> playFile(String path,
      {double speed = 1.0, int repeatCount = 0}) async {
    final f = File(path);
    if (!await f.exists()) return false;
    try {
      currentPath = path;
      repeatLeft = repeatCount;
      await _player.setSpeed(speed);
      await _player.setFilePath(path);
      await _player.play();
      playing = true;
      _player.processingStateStream.listen((st) {
        if (st == ProcessingState.completed) {
          if (repeatLeft > 0) {
            repeatLeft--;
            _player.seek(Duration.zero);
            _player.play();
          } else {
            playing = false;
          }
        }
      });
      return true;
    } catch (_) {
      playing = false;
      return false;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    playing = false;
  }

  Future<void> resume() async {
    await _player.play();
    playing = true;
  }

  Future<void> stop() async {
    await _player.stop();
    playing = false;
  }

  Future<void> seek(Duration d) => _player.seek(d);
  Future<void> setSpeed(double v) => _player.setSpeed(v);

  Future<void> dispose() => _player.dispose();
}

/// Legacy name kept for provider compatibility; delegates to offline control.
class AyatAudioService extends OfflineAudioController {
  AudioStatus statusFor(AudioFileInfo? info) =>
      info?.status ?? AudioStatus.notDownloaded;
}
