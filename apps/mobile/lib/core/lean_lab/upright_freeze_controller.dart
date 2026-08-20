import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/lean_engine.dart';
import 'lean_imu_math.dart';
import 'lock_cue.dart';

enum UprightFreezePhase {
  idle,
  countdown,
  settle,
  capture,
  failed,
  done,
}

/// How the rider arms the upright freeze.
///
/// [place] — arm → pocket/mount → settle → capture (never freeze in hand).
/// [hold] — phone already mounted; capture ~4 s of stillness.
enum UprightFreezeMode {
  place,
  hold,
}

/// Tap once → phone in final mount → stillness locks g0 → caller starts.
class UprightFreezeController extends ChangeNotifier {
  UprightFreezeController(
    this.engine, {
    this.signFlip = 1,
    this.onFrozen,
  });

  final LeanEngine engine;
  int signFlip;
  final void Function(Vec3 g0)? onFrozen;

  UprightFreezePhase phase = UprightFreezePhase.idle;
  UprightFreezeMode mode = UprightFreezeMode.hold;
  DateTime? _phaseAt;
  int _stillMs = 0;
  int countdownLeft = 5;
  Duration _captureFor = const Duration(seconds: 3);
  Vec3? frozenG0;
  String? failId;
  Timer? _tick;

  bool get busy =>
      phase == UprightFreezePhase.countdown ||
      phase == UprightFreezePhase.settle ||
      phase == UprightFreezePhase.capture;

  void attach() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) => _onTick());
  }

  void detach() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  /// Pocket / place ritual: countdown → wait for stillness → capture g0.
  void beginPlace() {
    mode = UprightFreezeMode.place;
    phase = UprightFreezePhase.countdown;
    _phaseAt = DateTime.now();
    countdownLeft = 5;
    _captureFor = const Duration(seconds: 3);
    frozenG0 = null;
    failId = null;
    _stillMs = 0;
    engine.clearCalibBuffer();
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Tank / already-mounted: capture ~4 s without moving the phone.
  void beginHold() {
    mode = UprightFreezeMode.hold;
    phase = UprightFreezePhase.capture;
    _phaseAt = DateTime.now();
    countdownLeft = 0;
    _captureFor = const Duration(seconds: 4);
    frozenG0 = null;
    failId = null;
    _stillMs = 0;
    engine.clearCalibBuffer();
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void begin(UprightFreezeMode which) {
    if (which == UprightFreezeMode.hold) {
      beginHold();
    } else {
      beginPlace();
    }
  }

  void _fail() {
    unawaited(LockCue.fail());
    phase = UprightFreezePhase.failed;
    failId = mode == UprightFreezeMode.hold ? 'hold_fail' : 'place_fail';
    notifyListeners();
  }

  void _onTick() {
    final now = DateTime.now();
    if (phase == UprightFreezePhase.capture) {
      engine.sampleForManualCalib();
    }
    if (phase == UprightFreezePhase.countdown) {
      final left = 5 - now.difference(_phaseAt ?? now).inSeconds;
      countdownLeft = left.clamp(0, 5);
      if (countdownLeft <= 0) {
        phase = UprightFreezePhase.settle;
        _phaseAt = now;
        _stillMs = 0;
        HapticFeedback.mediumImpact();
      }
      notifyListeners();
    } else if (phase == UprightFreezePhase.settle) {
      if (engine.isStill) {
        _stillMs += 120;
        if (_stillMs >= 600) {
          phase = UprightFreezePhase.capture;
          _phaseAt = now;
          engine.clearCalibBuffer();
        }
      } else {
        _stillMs = 0;
      }
      if (phase == UprightFreezePhase.settle &&
          now.difference(_phaseAt ?? now) >= const Duration(seconds: 12)) {
        _fail();
        return;
      }
      notifyListeners();
    } else if (phase == UprightFreezePhase.capture) {
      if (now.difference(_phaseAt ?? now) >= _captureFor) {
        _finish();
      } else if (mode == UprightFreezeMode.hold) {
        notifyListeners();
      }
    }
  }

  void _finish() {
    final minSamples = mode == UprightFreezeMode.hold ? 25 : 20;
    final g0 =
        engine.peekCalibGravity(minSamples: minSamples) ?? engine.latest?.gravity;
    if (g0 == null) {
      _fail();
      return;
    }
    engine.lockUpright(g0, signFlip: signFlip);
    unawaited(LockCue.ready());
    frozenG0 = g0;
    phase = UprightFreezePhase.done;
    notifyListeners();
    onFrozen?.call(g0);
  }
}
