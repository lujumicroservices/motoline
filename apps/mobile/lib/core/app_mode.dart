import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/ride_providers.dart';
import 'services/mode_switch_sound.dart';

const _modeKey = 'riderlab_app_mode';
const _soundKey = 'riderlab_mode_sound';

/// ON = street RiderLab (the original app). OFF = off-road circuits.
enum AppMode { on, off }

final appModeProvider = StateNotifierProvider<AppModeController, AppMode>((
  ref,
) {
  return AppModeController(ref);
});

final modeSoundEnabledProvider =
    StateNotifierProvider<ModeSoundController, bool>((ref) {
      return ModeSoundController();
    });

class AppModeController extends StateNotifier<AppMode> {
  AppModeController(this._ref) : super(AppMode.on) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_modeKey) == AppMode.off.name) state = AppMode.off;
  }

  /// Switches mode with the engine cue: two-stroke into OFF, track roar into ON.
  /// The sound never plays while a ride is recording.
  Future<void> setMode(AppMode mode) async {
    if (mode == state) return;
    state = mode;
    HapticFeedback.heavyImpact();
    final recording = _ref.read(rideRecorderProvider).isRecording;
    if (_ref.read(modeSoundEnabledProvider) && !recording) {
      ModeSwitchSound.play(mode);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> toggle() =>
      setMode(state == AppMode.on ? AppMode.off : AppMode.on);
}

class ModeSoundController extends StateNotifier<bool> {
  ModeSoundController() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_soundKey) ?? true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }
}
