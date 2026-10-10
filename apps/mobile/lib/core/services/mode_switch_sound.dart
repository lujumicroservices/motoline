import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../app_mode.dart';

/// Engine cue for the ON/OFF switch. Uses the sonification stream so the
/// phone's silent / vibrate mode mutes it.
class ModeSwitchSound {
  ModeSwitchSound._();

  static final AudioPlayer _player = AudioPlayer(playerId: 'mode_switch')
    ..setReleaseMode(ReleaseMode.stop);

  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.assistanceSonification,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static Future<void> play(AppMode mode) async {
    final asset = mode == AppMode.off
        ? 'sounds/mode_off_2t.wav'
        : 'sounds/mode_on_track.wav';
    try {
      await _player.stop();
      await _player.play(AssetSource(asset), ctx: _context, volume: 0.9);
    } catch (e) {
      debugPrint('mode switch sound failed: $e');
    }
  }
}
