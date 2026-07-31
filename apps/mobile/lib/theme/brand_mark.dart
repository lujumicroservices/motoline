import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

enum BrandMarkSize { hero, title, eyebrow }

/// RiderLab wordmark — single-line performance lockup (`Rider` + `Lab`).
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
      BrandMarkSize.hero => 34.0,
      BrandMarkSize.title => 22.0,
      BrandMarkSize.eyebrow => 13.0,
    };
    final labSize = switch (size) {
      BrandMarkSize.hero => 34.0,
      BrandMarkSize.title => 22.0,
      BrandMarkSize.eyebrow => 13.0,
    };
    final riderTracking = switch (size) {
      BrandMarkSize.hero => -1.2,
      BrandMarkSize.title => -0.6,
      BrandMarkSize.eyebrow => 0.4,
    };
    final labTracking = switch (size) {
      BrandMarkSize.hero => 0.8,
      BrandMarkSize.title => 0.6,
      BrandMarkSize.eyebrow => 1.4,
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

    final mark = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Rider', style: riderStyle),
            TextSpan(text: 'Lab', style: labStyle),
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
      BrandMarkSize.hero => 12.0,
      BrandMarkSize.title => 11.0,
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
              BrandMarkSize.hero => 56.0,
              BrandMarkSize.title => 40.0,
              BrandMarkSize.eyebrow => 28.0,
            },
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [AppTheme.signal, AppTheme.lineHot, AppTheme.line],
              ),
            ),
          ),
        ],
        if (showAttr) ...[
          SizedBox(height: size == BrandMarkSize.hero ? 8 : 4),
          Text(
            attribution!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: attrSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
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
