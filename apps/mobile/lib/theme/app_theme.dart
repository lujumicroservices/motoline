import 'package:flutter/material.dart';

import 'app_tokens.dart';

export 'app_tokens.dart';

/// RiderLab chrome — carbon asphalt + throttle signal + race telemetry.
///
/// One dark theme. The palette stays `#0E1013`. There is no theme switcher;
/// a high-contrast sunlight theme for the off-road display is a separate
/// decision and is not selected here.
///
/// UI type is bundled Plus Jakarta Sans (see [AppFonts]). Exo 2 and Rajdhani
/// were the previous pair and are no longer loaded at runtime.
class AppTheme {
  /// Deep carbon — night track / fairing black.
  static const asphalt = Color(0xFF0E1013);

  /// Raised panel over asphalt.
  static const asphaltElevated = Color(0xFF1A1E24);

  /// Secondary copy / chrome.
  static const steel = Color(0xFF9BA4AE);

  /// Primary text / light fairing.
  static const mist = Color(0xFFF1F5F8);

  /// Throttle / CTA — hot signal orange-red.
  static const signal = Color(0xFFFF3D1F);

  /// Telemetry / live line — electric mint.
  static const line = Color(0xFF00D4AA);

  /// Peak / warning — race amber.
  static const lineHot = Color(0xFFFFC107);

  /// Brand accent on the wordmark (`LAB`) — same family as throttle signal.
  static const brand = Color(0xFFFF5A2A);

  static ThemeData dark() {
    final text = AppFonts.textTheme().apply(
      bodyColor: mist,
      displayColor: mist,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    final buttonLabel = AppFonts.display(
      fontWeight: FontWeight.w700,
      fontSize: 15,
      letterSpacing: 0.1,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.uiFamily,
      colorScheme: const ColorScheme.dark(
        surface: asphalt,
        primary: line,
        secondary: signal,
        onSurface: mist,
        onPrimary: asphalt,
        error: signal,
      ),
      scaffoldBackgroundColor: asphalt,
    );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: AppFonts.textTheme().apply(
        bodyColor: asphalt,
        displayColor: asphalt,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: asphalt,
        foregroundColor: mist,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppFonts.display(
          color: mist,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: const CardThemeData(
        color: asphaltElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: asphaltElevated,
        selectedColor: line.withValues(alpha: 0.22),
        disabledColor: asphaltElevated.withValues(alpha: 0.5),
        labelStyle: AppFonts.body(
          color: mist,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: AppFonts.body(
          color: mist,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: 2,
        ),
        side: BorderSide(color: steel.withValues(alpha: 0.35)),
        shape: const StadiumBorder(),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: asphaltElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sheet)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: asphaltElevated,
        modalBackgroundColor: asphaltElevated,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: asphaltElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: asphaltElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 14,
        ),
        hintStyle: AppFonts.body(color: steel, fontSize: 15),
        labelStyle: AppFonts.body(color: steel, fontSize: 14),
        floatingLabelStyle: AppFonts.body(
          color: line,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        border: _fieldBorder(steel.withValues(alpha: 0.35)),
        enabledBorder: _fieldBorder(steel.withValues(alpha: 0.35)),
        focusedBorder: _fieldBorder(line, width: 1.6),
        errorBorder: _fieldBorder(signal),
        focusedErrorBorder: _fieldBorder(signal, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: signal,
          foregroundColor: mist,
          disabledBackgroundColor: signal.withValues(alpha: 0.38),
          disabledForegroundColor: mist.withValues(alpha: 0.62),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: buttonLabel,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: asphaltElevated,
          foregroundColor: mist,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: buttonLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mist,
          side: const BorderSide(color: steel),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: AppFonts.display(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: line,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(48, 40),
          shape: buttonShape,
          textStyle: AppFonts.display(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: mist,
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: signal,
        foregroundColor: mist,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            AppFonts.display(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
