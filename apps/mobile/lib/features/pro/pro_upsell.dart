import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/pro_entitlement_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';

/// Commercial / Pro upsell banner shown over locked curva detail, etc.
class ProUpsellBanner extends ConsumerWidget {
  const ProUpsellBanner({
    super.key,
    required this.title,
    required this.body,
    this.compact = false,
  });

  final String title;
  final String body;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding:
            EdgeInsets.fromLTRB(16, compact ? 12 : 18, 16, compact ? 12 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.asphaltElevated,
              RideVizPalette.leanLeft.withValues(alpha: 0.22),
              RideVizPalette.leanRight.withValues(alpha: 0.14),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: RideVizPalette.leanLeft.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: RideVizPalette.leanRight.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.pro,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppTheme.asphalt,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppTheme.mist.withValues(alpha: 0.8),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              title,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 16 : 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            FilledButton(
              onPressed: () async {
                final ok =
                    await ref.read(isProProvider.notifier).purchasePro();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? l10n.proUnlocked : l10n.upgradeToPro,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: RideVizPalette.leanLeft,
                foregroundColor: AppTheme.asphalt,
                minimumSize: Size.fromHeight(compact ? 44 : 48),
              ),
              child: Text(
                l10n.upgradeToPro,
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Free: show content ~500ms, then commercial banner on top.
/// Pro: content stays fully open.
class ProTeaserGate extends ConsumerStatefulWidget {
  const ProTeaserGate({
    super.key,
    required this.child,
    required this.bannerTitle,
    required this.bannerBody,
    this.teaserMs = 500,
  });

  final Widget child;
  final String bannerTitle;
  final String bannerBody;
  final int teaserMs;

  @override
  ConsumerState<ProTeaserGate> createState() => _ProTeaserGateState();
}

class _ProTeaserGateState extends ConsumerState<ProTeaserGate> {
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.teaserMs), () {
      if (!mounted) return;
      if (!ref.read(isProProvider)) {
        setState(() => _showBanner = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    if (isPro) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showBanner) ...[
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: AppTheme.asphalt.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: ProUpsellBanner(
              title: widget.bannerTitle,
              body: widget.bannerBody,
              compact: true,
            ),
          ),
        ],
      ],
    );
  }
}
