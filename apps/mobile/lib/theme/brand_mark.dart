import 'package:flutter/material.dart';

import 'app_theme.dart';

enum BrandMarkSize { hero, title, eyebrow }

/// RiderLab wordmark — condensed race lockup (`RIDER` + `LAB`).
///
/// Drawn as text in bundled Barlow Condensed, not an SVG or bitmap. Stroke
/// weight is the font weight: every size is one step heavier than the previous
/// cut (title/eyebrow RIDER 700→800, hero RIDER and all LAB 800→900).
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
    // One step heavier than the previous lockup, clamped at Black (900).
    final weight = switch (size) {
      BrandMarkSize.hero => FontWeight.w900,
      BrandMarkSize.title => FontWeight.w800,
      BrandMarkSize.eyebrow => FontWeight.w800,
    };

    final riderStyle = AppFonts.brand(
      fontSize: riderSize,
      fontWeight: weight,
      letterSpacing: riderTracking,
      color: base,
    );
    final labStyle = AppFonts.brand(
      fontSize: labSize,
      fontWeight: FontWeight.w900,
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
