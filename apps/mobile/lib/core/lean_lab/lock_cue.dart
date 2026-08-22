import 'dart:async';

import 'package:flutter/services.dart';

/// Pocket-audible lock cue: native vibrate pattern + confirmation tone.
class LockCue {
  LockCue._();

  static const _ch = MethodChannel('com.rawthrottle.riderlab/lock_cue');

  static Future<void> ready() async {
    try {
      await _ch.invokeMethod<void>('ready');
    } catch (_) {
      await _fallbackReady();
    }
  }

  static Future<void> fail() async {
    try {
      await _ch.invokeMethod<void>('fail');
    } catch (_) {
      await HapticFeedback.vibrate();
    }
  }

  static Future<void> _fallbackReady() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
  }
}
