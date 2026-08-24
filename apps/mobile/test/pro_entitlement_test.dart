import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/pro/partner_code.dart';
import 'package:motoline/core/pro/pro_entitlement.dart';

void main() {
  group('normalizePartnerProCode', () {
    test('accepts dashed codes and 6-char shorthand', () {
      expect(normalizePartnerProCode('pro-7k4m2q'), 'PRO-7K4M2Q');
      expect(normalizePartnerProCode('  7k4m2q  '), 'PRO-7K4M2Q');
      expect(isPartnerProCodeShape('PRO-7K4M2Q'), isTrue);
    });

    test('rejects values that are not a 6-character code', () {
      expect(isPartnerProCodeShape(normalizePartnerProCode('hello')), isFalse);
      expect(isPartnerProCodeShape(normalizePartnerProCode('TAP42')), isFalse);
    });
  });

  group('ProEntitlementStatus', () {
    test('parses server payload', () {
      final status = ProEntitlementStatus.fromJson({
        'ok': true,
        'is_pro': true,
        'source': 'trial',
        'ends_at': '2026-09-23T00:00:00.000Z',
        'days_left': 12,
        'trial_used': true,
        'partner_used': false,
      });
      expect(status.isPro, isTrue);
      expect(status.isTrial, isTrue);
      expect(status.daysLeft, 12);
      expect(status.expiredAfterGrant, isFalse);
    });

    test('expired after trial or partner grant', () {
      const status = ProEntitlementStatus(trialUsed: true);
      expect(status.expiredAfterGrant, isTrue);
      expect(status.isPro, isFalse);
    });

    test('rpc result maps errors', () {
      final result = ProRpcResult.fromJson({
        'ok': false,
        'error': 'already_paying',
        'is_pro': true,
        'source': 'revenuecat',
      });
      expect(result.ok, isFalse);
      expect(result.error, 'already_paying');
      expect(result.status.isPro, isTrue);
    });
  });
}
