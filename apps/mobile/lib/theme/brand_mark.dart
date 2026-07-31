import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'ride_viz_palette.dart';

enum BrandMarkSize { hero, title, eyebrow }

/// RiderLab wordmark — typographic lockup (`Rider` + `Lab`).
class RiderLabMark extends StatelessWidget {
  const RiderLabMark({
    super.key,
    this.size = BrandMarkSize.hero,
    this.color,
    this.labColor,
    this.showAttribution = false,
    this.attribution,
  });

  final BrandMarkSize size;
  final Color? color;
  final Color? labColor;

  /// When true, shows [attribution] under the wordmark (e.g. "by Raw Throttle").
  final bool showAttribution;
  final String? attribution;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppTheme.mist;
    final lab = labColor ?? _defaultLabColor(size);

    final riderSize = switch (size) {
      BrandMarkSize.hero => 40.0,
      BrandMarkSize.title => 22.0,
      BrandMarkSize.eyebrow => 13.0,
    };
    final labSize = switch (size) {
      BrandMarkSize.hero => 40.0,
      BrandMarkSize.title => 22.0,
      BrandMarkSize.eyebrow => 13.0,
    };
    final riderTracking = switch (size) {
      BrandMarkSize.hero => -1.0,
      BrandMarkSize.title => -0.5,
      BrandMarkSize.eyebrow => 0.6,
    };
    final labTracking = switch (size) {
      BrandMarkSize.hero => 1.4,
      BrandMarkSize.title => 1.0,
      BrandMarkSize.eyebrow => 2.0,
    };
    final weight = switch (size) {
      BrandMarkSize.hero => FontWeight.w800,
      BrandMarkSize.title => FontWeight.w700,
      BrandMarkSize.eyebrow => FontWeight.w600,
    };

    // Syne for the brand lockup; Outfit/SpaceGrotesk stay for UI chrome.
    final riderStyle = GoogleFonts.syne(
      fontSize: riderSize,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: riderTracking,
      color: base,
    );
    final labStyle = GoogleFonts.syne(
      fontSize: labSize,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: labTracking,
      color: lab,
    );

    final mark = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Rider', style: riderStyle),
          TextSpan(text: 'Lab', style: labStyle),
        ],
      ),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );

    if (!showAttribution || attribution == null || attribution!.isEmpty) {
      return mark;
    }

    final attrSize = switch (size) {
      BrandMarkSize.hero => 13.0,
      BrandMarkSize.title => 11.0,
      BrandMarkSize.eyebrow => 9.0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size == BrandMarkSize.hero ? 6 : 4),
        Text(
          attribution!,
          style: GoogleFonts.outfit(
            fontSize: attrSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppTheme.steel,
          ),
        ),
      ],
    );
  }

  Color _defaultLabColor(BrandMarkSize size) {
    // Cyan lean accent — lab / analysis, not speed red.
    return switch (size) {
      BrandMarkSize.hero => RideVizPalette.leanLeft,
      BrandMarkSize.title => RideVizPalette.leanLeft,
      BrandMarkSize.eyebrow => RideVizPalette.leanLeft,
    };
  }
}

/// @Deprecated('Use RiderLabMark')
typedef CornerIqMark = RiderLabMark;
