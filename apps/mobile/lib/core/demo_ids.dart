import 'package:flutter/material.dart';

/// Stable semantics identifiers for demo recording (Maestro / UI Automator).
abstract final class DemoIds {
  static const navRodadas = 'demo.nav.rodadas';
  static const navFriends = 'demo.nav.friends';
  static const navProfile = 'demo.nav.profile';
  static const ctaLeanLab = 'demo.cta.leanLab';
  static const ctaStart = 'demo.cta.start';
  static const ctaArm = 'demo.cta.arm';
  static const rideTile = 'demo.ride';
  static const mapFullscreen = 'demo.map.fullscreen';
  static const skillLab = 'demo.skill.lab';
  static const rodadaCard = 'demo.rodada';
}

/// Exposes [id] as Android `resource-id` / iOS identifier for automation.
class DemoTarget extends StatelessWidget {
  const DemoTarget({
    super.key,
    required this.id,
    required this.child,
    this.button = true,
  });

  final String id;
  final Widget child;
  final bool button;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: id,
      button: button,
      container: true,
      child: child,
    );
  }
}
