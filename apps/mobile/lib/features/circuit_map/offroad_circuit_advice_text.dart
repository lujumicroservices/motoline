import 'package:ride_core/ride_core.dart';

import '../../l10n/app_localizations.dart';

String offroadAdviceText(AppLocalizations l10n, CircuitAdvice advice) {
  final meters = advice.meters?.round() ?? 0;
  final count = advice.count ?? 0;
  return switch (advice.code) {
    CircuitAdviceCode.needOuter => l10n.offroadAdviceNeedOuter,
    CircuitAdviceCode.outerTooFew => l10n.offroadAdviceOuterTooFew,
    CircuitAdviceCode.outerOpen => l10n.offroadAdviceOuterOpen(meters),
    CircuitAdviceCode.outerTooShort => l10n.offroadAdviceOuterTooShort(meters),
    CircuitAdviceCode.needInner => l10n.offroadAdviceNeedInner,
    CircuitAdviceCode.innerTooFew => l10n.offroadAdviceInnerTooFew,
    CircuitAdviceCode.innerOpen => l10n.offroadAdviceInnerOpen(meters),
    CircuitAdviceCode.innerTooShort => l10n.offroadAdviceInnerTooShort(meters),
    CircuitAdviceCode.innerOutside => l10n.offroadAdviceInnerOutside,
    CircuitAdviceCode.ringsCross => l10n.offroadAdviceRingsCross,
    CircuitAdviceCode.edgesSwapped => l10n.offroadAdviceEdgesSwapped,
    CircuitAdviceCode.widthNarrow => l10n.offroadAdviceWidthNarrow(meters),
    CircuitAdviceCode.widthWide => l10n.offroadAdviceWidthWide(meters),
    CircuitAdviceCode.needLine =>
      advice.count == null
          ? l10n.offroadAdviceNeedLine
          : l10n.offroadAdviceNeedLineMore(count),
    CircuitAdviceCode.lineOutside => l10n.offroadAdviceLineOutside(count),
    CircuitAdviceCode.needGate => l10n.offroadAdviceNeedGate,
    CircuitAdviceCode.gateOff => l10n.offroadAdviceGateOff,
    CircuitAdviceCode.needDirection => l10n.offroadAdviceNeedDirection,
    CircuitAdviceCode.directionMismatch => l10n.offroadAdviceDirectionMismatch,
    CircuitAdviceCode.poorAccuracy => l10n.offroadAdvicePoorAccuracy(count),
    CircuitAdviceCode.spacingSparse => l10n.offroadAdviceSpacingSparse(meters),
    CircuitAdviceCode.spacingDense => l10n.offroadAdviceSpacingDense,
    CircuitAdviceCode.needElevation => l10n.offroadAdviceNeedElevation,
    CircuitAdviceCode.alignLandmark => l10n.offroadAdviceAlignLandmark,
    CircuitAdviceCode.walkAgain => l10n.offroadAdviceWalkAgain,
  };
}

String offroadAdviceLevelLabel(
  AppLocalizations l10n,
  CircuitAdviceLevel level,
) {
  return switch (level) {
    CircuitAdviceLevel.required => l10n.offroadLevelRequired,
    CircuitAdviceLevel.recommended => l10n.offroadLevelRecommended,
    CircuitAdviceLevel.tip => l10n.offroadLevelTip,
  };
}
