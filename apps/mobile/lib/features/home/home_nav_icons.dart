import 'package:flutter/material.dart';

import '../../core/demo_ids.dart';
import '../../theme/app_theme.dart';

/// Glove-friendly home nav button — asset glyph or Material fallback.
class HomeNavIconButton extends StatelessWidget {
  const HomeNavIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.semanticId,
    this.asset,
    this.icon,
    this.color = AppTheme.mist,
  }) : assert(asset != null || icon != null);

  final String tooltip;
  final VoidCallback onPressed;
  final String? semanticId;
  final String? asset;
  final IconData? icon;
  final Color color;

  static const double hit = 52;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: hit, minHeight: hit),
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, size: 28, color: color)
          : AppAssetIcon(asset: asset!, size: 34, color: color),
    );
    final id = semanticId;
    if (id == null) return button;
    return DemoTarget(id: id, child: button);
  }
}

/// White-on-transparent PNG tinted with [color] (BlendMode.srcIn).
class AppAssetIcon extends StatelessWidget {
  const AppAssetIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.color = AppTheme.mist,
  });

  final String asset;
  final double size;
  final Color color;

  static const rodadas = 'assets/icons/ic_rodadas.png';
  static const lean = 'assets/icons/ic_lean.png';
  static const routes = 'assets/icons/ic_routes.png';

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Sport lean glyph used in Lean Lab / garage tiles.
class AppMotoIcon extends StatelessWidget {
  const AppMotoIcon({
    super.key,
    this.size = 24,
    this.color = AppTheme.mist,
    // Kept for call-site compatibility; lean is baked into the asset.
    this.leanRad = 0,
  });

  final double size;
  final Color color;
  final double leanRad;

  @override
  Widget build(BuildContext context) {
    return AppAssetIcon(
      asset: AppAssetIcon.lean,
      size: size,
      color: color,
    );
  }
}
