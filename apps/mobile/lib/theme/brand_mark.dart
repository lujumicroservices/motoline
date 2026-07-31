import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Shared type styles — motorsport / telemetry feel.
class AppFonts {
  AppFonts._();

  /// Wordmark + timing-board display (condensed, aggressive).
  static TextStyle brand({
    double fontSize = 34,
    FontWeight fontWeight = FontWeight.w800,
    double letterSpacing = 0.8,
    double height = 1.0,
    Color? color,
  }) =>
      GoogleFonts.barlowCondensed(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );

  /// Titles, HUD numbers, buttons.
  static TextStyle display({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.exo2(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing ?? 0.2,
        height: height,
        color: color,
      );

  /// Body, captions, secondary chrome.
  static TextStyle body({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.rajdhani(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );
}

enum BrandMarkSize { hero, title, eyebrow }

/// RiderLab wordmark — condensed race lockup (`RIDER` + `LAB`).
class RiderLabMark extends StatelessWidget {
  const RiderLabMark({
    super.key,
    this.size = BrandMarkSize.hero,
    this.color,
    this.labColor,
    this.showAttribution = false,
    this.attribution,
    this.showAccentBar = false,
  });

  final BrandMarkSize size;
  final Color? color;
  final Color? labColor;

  /// When true, shows [attribution] under the wordmark (e.g. "by RawThrottle").
  final bool showAttribution;
  final String? attribution;

  /// Thin throttle accent under the lockup (hero home treatment).
  final bool showAccentBar;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppTheme.mist;
    final lab = labColor ?? AppTheme.brand;

    final riderSize = switch (size) {
      BrandMarkSize.hero => 42.0,
      BrandMarkSize.title => 26.0,
      BrandMarkSize.eyebrow => 15.0,
    };
    final labSize = switch (size) {
      BrandMarkSize.hero => 42.0,
      BrandMarkSize.title => 26.0,
      BrandMarkSize.eyebrow => 15.0,
    };
    // Condensed race tracking: Rider tight, LAB slightly open like a decal.
    final riderTracking = switch (size) {
      BrandMarkSize.hero => 1.2,
      BrandMarkSize.title => 1.0,
      BrandMarkSize.eyebrow => 1.4,
    };
    final labTracking = switch (size) {
      BrandMarkSize.hero => 2.4,
      BrandMarkSize.title => 2.0,
      BrandMarkSize.eyebrow => 2.2,
    };
    final weight = switch (size) {
      BrandMarkSize.hero => FontWeight.w800,
      BrandMarkSize.title => FontWeight.w700,
      BrandMarkSize.eyebrow => FontWeight.w700,
    };

    final riderStyle = AppFonts.brand(
      fontSize: riderSize,
      fontWeight: weight,
      letterSpacing: riderTracking,
      color: base,
    );
    final labStyle = AppFonts.brand(
      fontSize: labSize,
      fontWeight: FontWeight.w800,
      letterSpacing: labTracking,
      color: lab,
    );

    final mark = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'RIDER', style: riderStyle),
            TextSpan(text: 'LAB', style: labStyle),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    );

    final showAttr =
        showAttribution && attribution != null && attribution!.isNotEmpty;
    if (!showAttr && !showAccentBar) {
      return mark;
    }

    final attrSize = switch (size) {
      BrandMarkSize.hero => 11.0,
      BrandMarkSize.title => 10.0,
      BrandMarkSize.eyebrow => 9.0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        if (showAccentBar) ...[
          SizedBox(height: size == BrandMarkSize.hero ? 10 : 6),
          Container(
            height: 3,
            width: switch (size) {
              BrandMarkSize.hero => 64.0,
              BrandMarkSize.title => 44.0,
              BrandMarkSize.eyebrow => 28.0,
            },
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: const LinearGradient(
                colors: [AppTheme.signal, AppTheme.lineHot, AppTheme.line],
              ),
            ),
          ),
        ],
        if (showAttr) ...[
          SizedBox(height: size == BrandMarkSize.hero ? 8 : 4),
          Text(
            attribution!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.body(
              fontSize: attrSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
              color: AppTheme.steel,
            ),
          ),
        ],
      ],
    );
  }
}

/// @Deprecated('Use RiderLabMark')
typedef CornerIqMark = RiderLabMark;
