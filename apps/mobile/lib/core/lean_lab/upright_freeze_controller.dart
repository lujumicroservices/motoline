import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/lean_engine.dart';
import 'lean_imu_math.dart';

enum UprightFreezePhase {
  idle,
  holding,
  pocketCountdown,
  pocketSettle,
  pocketCapture,
  failed,
  done,
}

/// Shared tank-hold / pocket-countdown freeze. Used by Lean Lab, ride deck,
/// arm, and IMU lab so the rider never has to tap a pocketed phone.
class UprightFreezeController extends ChangeNotifier {
  UprightFreezeController(
    this.engine, {
    this.signFlip = 1,
    this.onFrozen,
  });

  final LeanEngine engine;
  int signFlip;
  final void Function(Vec3 g0, {required bool fromPocket})? onFrozen;

  UprightFreezePhase phase = UprightFreezePhase.idle;
  DateTime? _phaseAt;
  int _stillMs = 0;
  int countdownLeft = 5;
  Vec3? frozenG0;
  String? failId;
  Timer? _tick;
  bool _fromPocket = false;

  bool get busy =>
      phase == UprightFreezePhase.holding ||
      phase == UprightFreezePhase.pocketCountdown ||
      phase == UprightFreezePhase.pocketSettle ||
      phase == UprightFreezePhase.pocketCapture;

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

  void beginTankHold() {
    _fromPocket = false;
    phase = UprightFreezePhase.holding;
    _phaseAt = DateTime.now();
    frozenG0 = null;
    failId = null;
    engine.clearCalibBuffer();
    notifyListeners();
  }

  void beginPocket() {
    _fromPocket = true;
    phase = UprightFreezePhase.pocketCountdown;
    _phaseAt = DateTime.now();
    countdownLeft = 5;
    frozenG0 = null;
    failId = null;
    _stillMs = 0;
    engine.clearCalibBuffer();
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void _fail() {
    HapticFeedback.vibrate();
    phase = UprightFreezePhase.failed;
    failId = 'pocket_fail';
    notifyListeners();
  }

  void _onTick() {
    final now = DateTime.now();
    if (phase == UprightFreezePhase.holding ||
        phase == UprightFreezePhase.pocketCapture) {
      engine.sampleForManualCalib();
    }
    if (phase == UprightFreezePhase.holding) {
      if (now.difference(_phaseAt ?? now) >= const Duration(seconds: 4)) {
        _finish();
      }
    } else if (phase == UprightFreezePhase.pocketCountdown) {
      final left = 5 - now.difference(_phaseAt ?? now).inSeconds;
      countdownLeft = left.clamp(0, 5);
      if (countdownLeft <= 0) {
        phase = UprightFreezePhase.pocketSettle;
        _phaseAt = now;
        _stillMs = 0;
        HapticFeedback.mediumImpact();
      }
      notifyListeners();
    } else if (phase == UprightFreezePhase.pocketSettle) {
      if (engine.isStill) {
        _stillMs += 120;
        if (_stillMs >= 600) {
          phase = UprightFreezePhase.pocketCapture;
          _phaseAt = now;
          engine.clearCalibBuffer();
        }
      } else {
        _stillMs = 0;
      }
      if (phase == UprightFreezePhase.pocketSettle &&
          now.difference(_phaseAt ?? now) >= const Duration(seconds: 12)) {
        _fail();
        return;
      }
      notifyListeners();
    } else if (phase == UprightFreezePhase.pocketCapture) {
      if (now.difference(_phaseAt ?? now) >= const Duration(seconds: 3)) {
        _finish();
      }
    }
  }

  void _finish() {
    final g0 = engine.peekCalibGravity(minSamples: 20) ?? engine.latest?.gravity;
    if (g0 == null) {
      _fail();
      return;
    }
    engine.lockUpright(g0, signFlip: signFlip);
    HapticFeedback.heavyImpact();
    frozenG0 = g0;
    phase = UprightFreezePhase.done;
    notifyListeners();
    onFrozen?.call(g0, fromPocket: _fromPocket);
  }
}
