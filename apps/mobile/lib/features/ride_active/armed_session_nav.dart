import 'package:flutter_riverpod/flutter_riverpod.dart';

const kArmedSessionRoute = 'armed-session';
const kArmedHudRoute = 'armed-ride-hud';

class ArmedSessionNavState {
  const ArmedSessionNavState({
    this.hubOnStack = false,
    this.hudOnStack = false,
    this.hudMinimized = false,
  });

  final bool hubOnStack;
  final bool hudOnStack;

  /// User left the recording HUD on purpose. Do not auto-reopen it.
  final bool hudMinimized;

  ArmedSessionNavState copyWith({
    bool? hubOnStack,
    bool? hudOnStack,
    bool? hudMinimized,
  }) {
    return ArmedSessionNavState(
      hubOnStack: hubOnStack ?? this.hubOnStack,
      hudOnStack: hudOnStack ?? this.hudOnStack,
      hudMinimized: hudMinimized ?? this.hudMinimized,
    );
  }
}

/// Whether motion auto-start / Home resume should push the recording HUD.
///
/// False when the HUD is already showing, or the user minimized it.
bool shouldAutoPushHud(
  ArmedSessionNavState nav, {
  required bool isRecording,
}) {
  if (!isRecording) return false;
  if (nav.hudOnStack) return false;
  if (nav.hudMinimized) return false;
  return true;
}

/// Home is visible while a ride is recording — reopen the session hub.
bool shouldResumeHubFromHome({
  required bool isRecording,
  required bool hubOnStack,
}) {
  if (hubOnStack) return false;
  return isRecording;
}

class ArmedSessionNav extends StateNotifier<ArmedSessionNavState> {
  ArmedSessionNav() : super(const ArmedSessionNavState());

  void reset() => state = const ArmedSessionNavState();

  void hubOpened() => state = state.copyWith(hubOnStack: true);

  void hubClosed() => state = state.copyWith(hubOnStack: false);

  void hudOpened() =>
      state = state.copyWith(hudOnStack: true, hudMinimized: false);

  void hudClosed({required bool stillRecording}) {
    state = state.copyWith(
      hudOnStack: false,
      hudMinimized: stillRecording ? true : state.hudMinimized,
    );
  }
}

final armedSessionNavProvider =
    StateNotifierProvider<ArmedSessionNav, ArmedSessionNavState>(
  (ref) => ArmedSessionNav(),
);
