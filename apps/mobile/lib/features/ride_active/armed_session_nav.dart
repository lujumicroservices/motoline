import 'package:flutter_riverpod/flutter_riverpod.dart';

const kArmedSessionRoute = 'armed-session';

/// Legacy HUD route name — still popped if it remains on the stack.
const kArmedHudRoute = 'armed-ride-hud';

class ArmedSessionNavState {
  const ArmedSessionNavState({
    this.hubOnStack = false,
    this.hudOnStack = false,
    this.hudMinimized = false,
  });

  /// Unified session screen is on the navigator stack.
  final bool hubOnStack;

  /// Same as [hubOnStack] after the lobby was removed.
  final bool hudOnStack;

  /// User left the session on purpose. Do not auto-reopen it.
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

/// Whether motion auto-start / Home resume should push the session screen.
///
/// False when the session is already showing, or the user minimized it.
bool shouldAutoPushHud(
  ArmedSessionNavState nav, {
  required bool isRecording,
  bool rodadaMetricsHeld = false,
}) {
  if (!isRecording) return false;
  if (rodadaMetricsHeld) return false;
  if (nav.hubOnStack || nav.hudOnStack) return false;
  if (nav.hudMinimized) return false;
  return true;
}

/// Explicit reopen of the session (banner, capture bar).
bool canOpenArmedHud({required String? currentRouteName}) {
  return currentRouteName != kArmedSessionRoute &&
      currentRouteName != kArmedHudRoute;
}

/// Home is visible while a ride is recording — reopen the session unless
/// the user minimized it.
bool shouldResumeHubFromHome({
  required bool isRecording,
  required bool hubOnStack,
  bool rodadaMetricsHeld = false,
  bool hudMinimized = false,
}) {
  if (hubOnStack) return false;
  if (rodadaMetricsHeld) return false;
  if (hudMinimized) return false;
  return isRecording;
}

/// Whether Home should push the session screen again.
///
/// If [homeIsVisible], a leftover [hubOnStack] is stale (user popped with
/// the back arrow and dispose could not clear the flag).
///
/// Auto-start / lifecycle must not reopen a minimized session; a tap
/// ([userRequested]) may.
bool shouldPushArmedHub({
  required bool hubOnStack,
  required bool homeIsVisible,
  bool hudMinimized = false,
  bool userRequested = false,
}) {
  if (hudMinimized && !userRequested) return false;
  if (!hubOnStack) return true;
  return homeIsVisible;
}

class ArmedSessionNav extends StateNotifier<ArmedSessionNavState> {
  ArmedSessionNav() : super(const ArmedSessionNavState());

  void reset() => state = const ArmedSessionNavState();

  void hubOpened() => state = state.copyWith(
        hubOnStack: true,
        hudOnStack: true,
        hudMinimized: false,
      );

  void hubClosed() =>
      state = state.copyWith(hubOnStack: false, hudOnStack: false);

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
