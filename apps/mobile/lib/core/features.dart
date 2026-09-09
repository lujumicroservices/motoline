import 'package:flutter/foundation.dart';

/// Temporary feature switches. Keep code wired; hide UX when false.
class AppFeatures {
  AppFeatures._();

  /// Circuit / "Ruta" tagging, Routes screen, Loop-from-route, assign-to-ruta.
  /// Off for now — rides are free-standing and manually named.
  static const bool routesEnabled = false;

  /// Dev-only: start recording while armed even if the bike is still.
  /// Hidden in store/release builds; motion auto-start stays the real path.
  static bool get forceStartArmedRecording => !kReleaseMode;
}
