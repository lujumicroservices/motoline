import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db/ride_database.dart';
import '../core/distribution.dart';
import '../core/models/ride.dart';
import '../core/pro/pro_entitlement.dart';
import '../core/pro/pro_entitlement_repository.dart';
import '../core/supabase/supabase_bootstrap.dart';
import 'supabase_providers.dart';

const _proKey = 'riderlab_pro_unlocked';
const _proStatusKey = 'riderlab_pro_status_json';

/// Entitlement id configured in RevenueCat dashboard.
/// Product contract: docs/FREE_VS_PRO.md
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

/// Sideload, not signed in: keep the local Settings toggle for pilots.
bool get allowLocalProToggle {
  if (AppDistribution.isPlayStore) return false;
  if (SupabaseBootstrap.isReady && SupabaseBootstrap.permanentUser != null) {
    return false;
  }
  return true;
}

final proEntitlementProvider =
    StateNotifierProvider<ProEntitlementController, ProEntitlementStatus>(
        (ref) {
  return ProEntitlementController(ref);
});

final isProProvider = Provider<bool>((ref) {
  return ref.watch(proEntitlementProvider).isPro;
});

class ProEntitlementController extends StateNotifier<ProEntitlementStatus> {
  ProEntitlementController(this._ref) : super(ProEntitlementStatus.empty) {
    _bootstrap();
    _ref.listen(supabaseSessionProvider, (prev, next) {
      unawaited(refresh());
    });
  }

  final Ref _ref;
  final ProEntitlementRepository _repo = ProEntitlementRepository();

  bool _rcReady = false;
  bool _rcPro = false;

  Future<void> _bootstrap() async {
    await _loadCache();
    if (revenueCatConfigured) {
      await _initRevenueCat();
    }
    await refresh();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_proStatusKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          state = ProEntitlementStatus.fromJson(map);
          return;
        }
      } catch (_) {}
    }
    final local = prefs.getBool(_proKey) ?? false;
    if (local && allowLocalProToggle) {
      state = const ProEntitlementStatus(
        isPro: true,
        source: 'local',
        localOverride: true,
      );
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, state.isPro);
    await prefs.setString(_proStatusKey, jsonEncode(state.toCacheJson()));
  }

  Future<void> _initRevenueCat() async {
    try {
      final key = dotenv.env['REVENUECAT_API_KEY']!.trim();
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.info,
      );
      await Purchases.configure(PurchasesConfiguration(key));
      _rcReady = true;
      final uid = SupabaseBootstrap.permanentUserId;
      if (uid != null) {
        try {
          await Purchases.logIn(uid);
        } catch (e) {
          debugPrint('RevenueCat logIn failed: $e');
        }
      }
      Purchases.addCustomerInfoUpdateListener((info) {
        _applyRevenueCat(info);
        state = _merge(state);
        unawaited(_persist());
      });
      final info = await Purchases.getCustomerInfo();
      _applyRevenueCat(info);
    } catch (e, st) {
      debugPrint('RevenueCat init failed: $e\n$st');
      _rcReady = false;
    }
  }

  void _applyRevenueCat(CustomerInfo info) {
    _rcPro = info.entitlements.active.containsKey(revenueCatProEntitlement);
  }

  ProEntitlementStatus _merge(ProEntitlementStatus server) {
    if (_rcPro) {
      return server.copyWith(
        isPro: true,
        source: 'revenuecat',
      );
    }
    if (allowLocalProToggle && server.localOverride) {
      return server.copyWith(isPro: true, source: 'local');
    }
    return server;
  }

  /// Pull server periods (and RevenueCat if configured). Optionally start trial.
  Future<void> refresh({bool fromStoreOnly = false}) async {
    if (_rcReady && !fromStoreOnly) {
      try {
        final uid = SupabaseBootstrap.permanentUserId;
        if (uid != null) {
          await Purchases.logIn(uid);
        }
        final info = await Purchases.getCustomerInfo();
        _applyRevenueCat(info);
      } catch (e) {
        debugPrint('RevenueCat refresh failed: $e');
      }
    }

    if (!fromStoreOnly) {
      final remote = await _repo.status();
      if (remote.ok || remote.status.isPro || remote.status.trialUsed) {
        state = _merge(remote.status);
        await _persist();
      } else if (_rcPro) {
        state = _merge(state);
        await _persist();
      }
    } else {
      state = _merge(state);
      await _persist();
    }

    if (!fromStoreOnly) {
      await startTrialIfEligible();
    }
  }

  Future<void> onSignedOut() async {
    _rcPro = false;
    state = allowLocalProToggle
        ? const ProEntitlementStatus()
        : ProEntitlementStatus.empty;
    await _persist();
  }

  Future<void> restorePurchases() async {
    if (!_rcReady) return;
    try {
      final info = await Purchases.restorePurchases();
      _applyRevenueCat(info);
      await refresh(fromStoreOnly: true);
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
    }
  }

  /// Present store packages (yearly first), or no-op when billing is off.
  Future<bool> purchasePro() async {
    if (_rcReady) {
      try {
        final offerings = await Purchases.getOfferings();
        final current = offerings.current;
        final package = current?.annual ??
            current?.monthly ??
            current?.availablePackages.firstOrNull;
        if (package == null) {
          debugPrint('RevenueCat: no packages in current offering');
          return state.isPro;
        }
        final info = await Purchases.purchasePackage(package);
        _applyRevenueCat(info);
        await refresh(fromStoreOnly: true);
        return state.isPro;
      } catch (e) {
        debugPrint('RevenueCat purchase failed: $e');
        return false;
      }
    }
    return state.isPro;
  }

  /// Local toggle — sideload without a signed-in cloud session only.
  Future<void> setPro(bool unlocked) async {
    if (!allowLocalProToggle) {
      await refresh();
      return;
    }
    state = ProEntitlementStatus(
      isPro: unlocked,
      source: unlocked ? 'local' : null,
      localOverride: unlocked,
      trialUsed: state.trialUsed,
      partnerUsed: state.partnerUsed,
    );
    await _persist();
  }

  Future<void> toggle() => setPro(!state.isPro);

  Future<bool> _hasCompletedRide() async {
    try {
      final rides = await RideDatabase.instance.listRides();
      return rides.any(
        (r) => r.status == RideStatus.completed && r.endedAt != null,
      );
    } catch (e) {
      debugPrint('Pro trial ride check: $e');
      return false;
    }
  }

  /// First completed ride starts a 30-day trial (server enforces one + 90-day cap).
  Future<void> startTrialIfEligible() async {
    if (state.trialUsed) return;
    if (SupabaseBootstrap.permanentUser == null) return;
    if (!await _hasCompletedRide()) return;
    final result = await _repo.startTrial();
    if (result.ok || result.status.trialUsed) {
      state = _merge(result.status);
      await _persist();
    }
  }

  Future<void> onRideCompleted() => startTrialIfEligible();

  Future<ProRpcResult> redeemPartnerCode(String code) async {
    if (_rcPro) {
      return const ProRpcResult(ok: false, error: 'already_paying');
    }
    final result = await _repo.redeem(code);
    if (result.ok) {
      state = _merge(result.status);
      await _persist();
    }
    return result;
  }

  Future<ProRpcResult> staffCreatePartnerCode({String? label}) {
    return _repo.staffCreateCode(label: label);
  }
}
