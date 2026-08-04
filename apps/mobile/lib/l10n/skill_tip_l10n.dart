import '../core/analytics/corner_skill.dart';
import 'app_localizations.dart';

extension SkillTipL10n on AppLocalizations {
  String skillTipText(SkillTip tip) {
    switch (tip.id) {
      case SkillTipId.noCurvasDetected:
        return skillTipNoCurvas;
      case SkillTipId.entryHot:
        return skillTipEntryHot(
          (tip.entry ?? 0).toString(),
          (tip.apex ?? 0).toString(),
        );
      case SkillTipId.moderateSpeedDrop:
        return skillTipModerateSpeedDrop;
      case SkillTipId.littleSpeedScrub:
        return skillTipLittleSpeedScrub;
      case SkillTipId.weakExitDrive:
        return skillTipWeakExitDrive;
      case SkillTipId.peakLeanNotAtApex:
        return skillTipPeakLeanNotAtApex;
      case SkillTipId.lowLeanBigHeading:
        return skillTipLowLeanBigHeading;
      case SkillTipId.solidCorner:
        return skillTipSolidCorner;
      case SkillTipId.bestHighlight:
        return skillHighlightBest(tip.label ?? '', tip.score ?? 0);
      case SkillTipId.medianHighlight:
        return skillHighlightMedian(tip.score ?? 0);
      case SkillTipId.drillRepeatCorner:
        return skillTipDrillRepeat(tip.label ?? '');
    }
  }
}
