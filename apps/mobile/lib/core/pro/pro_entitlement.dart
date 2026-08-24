import 'dart:convert';

/// Server + store Pro status. Contract: docs/FREE_VS_PRO.md
class ProEntitlementStatus {
  const ProEntitlementStatus({
    this.isPro = false,
    this.source,
    this.endsAt,
    this.daysLeft = 0,
    this.trialUsed = false,
    this.partnerUsed = false,
    this.localOverride = false,
  });

  static const empty = ProEntitlementStatus();

  /// `trial` | `partner` | `revenuecat` | `local`
  final bool isPro;
  final String? source;
  final DateTime? endsAt;
  final int daysLeft;
  final bool trialUsed;
  final bool partnerUsed;
  final bool localOverride;

  bool get isTrial => isPro && source == 'trial';
  bool get isPartner => isPro && source == 'partner';
  bool get isPaid => isPro && source == 'revenuecat';
  bool get expiredAfterGrant => !isPro && (trialUsed || partnerUsed);

  ProEntitlementStatus copyWith({
    bool? isPro,
    String? source,
    DateTime? endsAt,
    int? daysLeft,
    bool? trialUsed,
    bool? partnerUsed,
    bool? localOverride,
    bool clearSource = false,
    bool clearEndsAt = false,
  }) {
    return ProEntitlementStatus(
      isPro: isPro ?? this.isPro,
      source: clearSource ? null : (source ?? this.source),
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      daysLeft: daysLeft ?? this.daysLeft,
      trialUsed: trialUsed ?? this.trialUsed,
      partnerUsed: partnerUsed ?? this.partnerUsed,
      localOverride: localOverride ?? this.localOverride,
    );
  }

  factory ProEntitlementStatus.fromJson(Map<String, dynamic> json) {
    final endsRaw = json['ends_at'];
    DateTime? endsAt;
    if (endsRaw is String && endsRaw.isNotEmpty) {
      endsAt = DateTime.tryParse(endsRaw)?.toLocal();
    }
    final days = json['days_left'];
    return ProEntitlementStatus(
      isPro: json['is_pro'] == true,
      source: json['source'] as String?,
      endsAt: endsAt,
      daysLeft: days is int ? days : int.tryParse('$days') ?? 0,
      trialUsed: json['trial_used'] == true,
      partnerUsed: json['partner_used'] == true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'is_pro': isPro,
        'source': source,
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'days_left': daysLeft,
        'trial_used': trialUsed,
        'partner_used': partnerUsed,
      };
}

class ProRpcResult {
  const ProRpcResult({
    required this.ok,
    this.error,
    this.status = ProEntitlementStatus.empty,
    this.code,
  });

  final bool ok;
  final String? error;
  final ProEntitlementStatus status;
  final String? code;

  factory ProRpcResult.fromJson(Object? raw) {
    Object? data = raw;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return const ProRpcResult(ok: false, error: 'bad_response');
      }
    }
    if (data is List && data.isNotEmpty) {
      data = data.first;
    }
    if (data is! Map) {
      return const ProRpcResult(ok: false, error: 'bad_response');
    }
    final json = Map<String, dynamic>.from(data);
    return ProRpcResult(
      ok: json['ok'] == true,
      error: json['error'] as String?,
      status: ProEntitlementStatus.fromJson(json),
      code: json['code'] as String?,
    );
  }
}
