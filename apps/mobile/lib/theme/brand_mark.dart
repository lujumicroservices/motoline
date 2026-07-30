import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'ride_viz_palette.dart';

enum BrandMarkSize { hero, title, eyebrow }

/// CornerIQ wordmark — typographic brand lockup (Corner + IQ).
class CornerIqMark extends StatelessWidget {
  const CornerIqMark({
    super.key,
    this.size = BrandMarkSize.hero,
    this.color,
    this.iqColor,
  });

  final BrandMarkSize size;
  final Color? color;
  final Color? iqColor;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppTheme.mist;
    final iq = iqColor ?? _defaultIqColor(size);

    final cornerSize = switch (size) {
      BrandMarkSize.hero => 40.0,
      BrandMarkSize.title => 22.0,
      BrandMarkSize.eyebrow => 13.0,
    };
    final iqSize = switch (size) {
      BrandMarkSize.hero => 40.0,
      BrandMarkSize.title => 22.0,
      BrandMarkSize.eyebrow => 13.0,
    };
    final cornerTracking = switch (size) {
      BrandMarkSize.hero => -1.2,
      BrandMarkSize.title => -0.6,
      BrandMarkSize.eyebrow => 0.8,
    };
    final iqTracking = switch (size) {
      BrandMarkSize.hero => 1.6,
      BrandMarkSize.title => 1.2,
      BrandMarkSize.eyebrow => 2.4,
    };
    final weight = switch (size) {
      BrandMarkSize.hero => FontWeight.w800,
      BrandMarkSize.title => FontWeight.w700,
      BrandMarkSize.eyebrow => FontWeight.w600,
    };

    // Syne for the brand lockup; Outfit/SpaceGrotesk stay for UI chrome.
    final cornerStyle = GoogleFonts.syne(
      fontSize: cornerSize,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: cornerTracking,
      color: base,
    );
    final iqStyle = GoogleFonts.syne(
      fontSize: iqSize,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: iqTracking,
      color: iq,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Corner', style: cornerStyle),
          TextSpan(text: 'IQ', style: iqStyle),
        ],
      ),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }

  Color _defaultIqColor(BrandMarkSize size) {
    return switch (size) {
      BrandMarkSize.hero => RideVizPalette.speedBlueHigh,
      BrandMarkSize.title => RideVizPalette.speedBlueHigh,
      BrandMarkSize.eyebrow => RideVizPalette.leanLeft,
    };
  }
}
