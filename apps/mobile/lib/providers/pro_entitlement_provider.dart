import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

const _proKey = 'riderlab_pro_unlocked';

/// Entitlement id configured in RevenueCat dashboard.
const revenueCatProEntitlement = 'pro';

/// How many brake events Free can see in full (rest are obfuscated).
const freeBrakePreviewCount = 3;

/// True when a RevenueCat API key is present in `.env`.
bool get revenueCatConfigured {
  try {
    final key = dotenv.env['REVENUECAT_API_KEY']?.trim() ?? '';
    return key.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Pro entitlement. Uses RevenueCat when configured; otherwise local prefs
/// (dev / sideload until store billing is live).
final isProProvider =
    StateNotifierProvider<ProEntitlementController, bool>((ref) {
  return ProEntitlementController();
});

class ProEntitlementController extends StateNotifier<bool> {
  ProEntitlementController() : super(false) {
    _bootstrap();
  }

  bool _rcReady = false;

  Future<void> _bootstrap() async {
    await _loadLocal();
    if (revenueCatConfigured) {
      await _initRevenueCat();
      await refreshFromStore();
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_proKey) ?? false;
  }

  Future<void> _initRevenueCat() async {
    try {
      final key = dotenv.env['REVENUECAT_API_KEY']!.trim();
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.info,
      );
      await Purchases.configure(PurchasesConfiguration(key));
      _rcReady = true;
      Purchases.addCustomerInfoUpdateListener((info) {
        final active = info.entitlements.active.containsKey(
          revenueCatProEntitlement,
        );
        state = active;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_proKey, active);
        });
      });
    } catch (e, st) {
      debugPrint('RevenueCat init failed: $e\n$st');
      _rcReady = false;
    }
  }

  /// Pull latest entitlements from RevenueCat (no-op if not configured).
  Future<void> refreshFromStore() async {
    if (!_rcReady && revenueCatConfigured) {
      await _initRevenueCat();
    }
    if (!_rcReady) return;
    try {
      final info = await Purchases.getCustomerInfo();
      final active =
          info.entitlements.active.containsKey(revenueCatProEntitlement);
      state = active;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_proKey, active);
    } catch (e) {
      debugPrint('RevenueCat refresh failed: $e');
    }
  }

  Future<void> restorePurchases() async {
    if (!_rcReady) return;
    try {
      final info = await Purchases.restorePurchases();
      final active =
          info.entitlements.active.containsKey(revenueCatProEntitlement);
      state = active;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_proKey, active);
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
    }
  }

  /// Present RevenueCat offerings purchase for `pro`, or unlock locally in debug.
  Future<bool> purchasePro() async {
    if (_rcReady) {
      try {
        final offerings = await Purchases.getOfferings();
        final package = offerings.current?.availablePackages.firstOrNull;
        if (package == null) {
          debugPrint('RevenueCat: no packages in current offering');
          return false;
        }
        final info = await Purchases.purchasePackage(package);
        final active =
            info.entitlements.active.containsKey(revenueCatProEntitlement);
        state = active;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_proKey, active);
        return active;
      } catch (e) {
        debugPrint('RevenueCat purchase failed: $e');
        return false;
      }
    }
    // Store billing not configured — local unlock for sideload / debug.
    await setPro(true);
    return true;
  }

  /// Local toggle (Settings). Prefer [purchasePro] when RevenueCat is live.
  Future<void> setPro(bool unlocked) async {
    state = unlocked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, unlocked);
  }

  Future<void> toggle() => setPro(!state);
}
