import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/alias_provider.dart';
import '../../providers/auth_providers.dart';

const bundledSessionAssets = [
  'assets/offroad/sessions/2026-10-09_8horas.json',
];

/// Sessions visible to the signed-in account (owner match on alias or email).
final trainingSessionsProvider = FutureProvider<List<TrainingSession>>((
  ref,
) async {
  final alias = ref.watch(riderAliasProvider).trim().toLowerCase();
  final email =
      (ref.watch(authServiceProvider).displayLabel ?? '').trim().toLowerCase();
  final out = <TrainingSession>[];
  for (final path in bundledSessionAssets) {
    final raw = await rootBundle.loadString(path);
    final s = TrainingSession.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (s.ownerMatches(alias: alias, email: email)) out.add(s);
  }
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
});

final offroadPerformanceProvider = Provider<OffroadPerformance>((ref) {
  final sessions = ref.watch(trainingSessionsProvider).valueOrNull ?? const [];
  var passes = 0;
  var km = 0.0;
  double? vmax;
  double? bestLap;
  for (final s in sessions) {
    passes += s.summary.passes;
    km += s.summary.distanceKm;
    vmax = vmax == null
        ? s.summary.vmaxKmh
        : (s.summary.vmaxKmh > vmax ? s.summary.vmaxKmh : vmax);
    final d = s.summary.bestDurationS;
    bestLap = bestLap == null ? d : (d < bestLap ? d : bestLap);
  }
  return OffroadPerformance(
    sessions: sessions.length,
    passes: passes,
    distanceKm: km,
    vmaxKmh: vmax,
    bestLapS: bestLap,
  );
});

class OffroadPerformance {
  const OffroadPerformance({
    required this.sessions,
    required this.passes,
    required this.distanceKm,
    required this.vmaxKmh,
    required this.bestLapS,
  });
  final int sessions;
  final int passes;
  final double distanceKm;
  final double? vmaxKmh;
  final double? bestLapS;
}

class TrainingInsight {
  const TrainingInsight({
    required this.kind,
    required this.title,
    required this.body,
    this.passId,
    this.sector,
  });

  final String kind; // good | bad
  final String title;
  final String body;
  final String? passId;
  final String? sector;

  bool get isGood => kind == 'good';
}

class PassSector {
  const PassSector({
    required this.name,
    required this.partial,
    required this.timeS,
    this.note,
  });
  final String name;
  final bool partial;
  final double timeS;
  final String? note;
}

class PassBrake {
  const PassBrake({
    required this.sector,
    required this.lapM,
    required this.vIn,
    required this.vOut,
    required this.peakG,
    required this.durationS,
  });
  final String sector;
  final double lapM;
  final double vIn;
  final double vOut;
  final double peakG;
  final double durationS;
}

class TrainingPass {
  const TrainingPass({
    required this.id,
    required this.sessionId,
    required this.startLocal,
    required this.endLocal,
    required this.durationS,
    required this.movingS,
    required this.distanceM,
    required this.vmaxKmh,
    required this.vavgKmh,
    required this.leanMaxR,
    required this.leanMaxL,
    required this.brakePeakG,
    required this.accelPeakG,
    required this.brakingZones,
    required this.pctOutside,
    required this.outsideMaxM,
    required this.medianDistOuterM,
    required this.medianDistInnerM,
    required this.maxleanSector,
    required this.hardestBrakeSector,
    required this.brakingZonesPerSector,
    required this.sectors,
    required this.brakes,
  });

  final String id;
  final String sessionId;
  final String startLocal;
  final String endLocal;
  final double durationS;
  final double movingS;
  final double distanceM;
  final double vmaxKmh;
  final double vavgKmh;
  final double leanMaxR;
  final double leanMaxL;
  final double brakePeakG;
  final double accelPeakG;
  final int brakingZones;
  final double pctOutside;
  final double outsideMaxM;
  final double medianDistOuterM;
  final double medianDistInnerM;
  final String maxleanSector;
  final String hardestBrakeSector;
  final String brakingZonesPerSector;
  final List<PassSector> sectors;
  final List<PassBrake> brakes;

  double get leanMax => leanMaxL > leanMaxR ? leanMaxL : leanMaxR;
}

class SessionSummary {
  const SessionSummary({
    required this.passes,
    required this.distanceKm,
    required this.bestDurationS,
    required this.vmaxKmh,
    required this.bestOutsidePct,
    required this.bestS2S,
    required this.bestS3S,
    required this.theoreticalPartialS,
    required this.flyingLaps,
  });
  final int passes;
  final double distanceKm;
  final double bestDurationS;
  final double vmaxKmh;
  final double bestOutsidePct;
  final double bestS2S;
  final double bestS3S;
  final double theoreticalPartialS;
  final int flyingLaps;
}

class TrainingSession {
  TrainingSession({
    required this.id,
    required this.owner,
    required this.circuitId,
    required this.circuitName,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.mapping,
    required this.passes,
    required this.insights,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> j) {
    final sum = j['summary'] as Map<String, dynamic>;
    return TrainingSession(
      id: j['id'] as String,
      owner: j['owner'] as String,
      circuitId: j['circuit_id'] as String,
      circuitName: j['circuit_name'] as String,
      date: DateTime.parse(j['date'] as String),
      title: j['title'] as String,
      subtitle: j['subtitle'] as String? ?? '',
      summary: SessionSummary(
        passes: (sum['passes'] as num).toInt(),
        distanceKm: (sum['distance_km'] as num).toDouble(),
        bestDurationS: (sum['best_duration_s'] as num).toDouble(),
        vmaxKmh: (sum['vmax_kmh'] as num).toDouble(),
        bestOutsidePct: (sum['best_outside_pct'] as num).toDouble(),
        bestS2S: (sum['best_s2_s'] as num).toDouble(),
        bestS3S: (sum['best_s3_s'] as num).toDouble(),
        theoreticalPartialS: (sum['theoretical_partial_s'] as num).toDouble(),
        flyingLaps: (sum['flying_laps'] as num).toInt(),
      ),
      mapping: Map<String, dynamic>.from(j['mapping'] as Map),
      passes: [
        for (final p in j['passes'] as List)
          TrainingPass(
            id: p['id'] as String,
            sessionId: p['session_id'] as String,
            startLocal: p['start_local'] as String,
            endLocal: p['end_local'] as String,
            durationS: (p['duration_s'] as num).toDouble(),
            movingS: (p['moving_s'] as num).toDouble(),
            distanceM: (p['distance_m'] as num).toDouble(),
            vmaxKmh: (p['vmax_kmh'] as num).toDouble(),
            vavgKmh: (p['vavg_kmh'] as num).toDouble(),
            leanMaxR: (p['lean_max_r'] as num).toDouble(),
            leanMaxL: (p['lean_max_l'] as num).toDouble(),
            brakePeakG: (p['brake_peak_g'] as num).toDouble(),
            accelPeakG: (p['accel_peak_g'] as num).toDouble(),
            brakingZones: (p['braking_zones'] as num).toInt(),
            pctOutside: (p['pct_outside'] as num).toDouble(),
            outsideMaxM: (p['outside_max_m'] as num).toDouble(),
            medianDistOuterM: (p['median_dist_outer_m'] as num).toDouble(),
            medianDistInnerM: (p['median_dist_inner_m'] as num).toDouble(),
            maxleanSector: p['maxlean_sector'] as String,
            hardestBrakeSector: p['hardest_brake_sector'] as String,
            brakingZonesPerSector: p['braking_zones_per_sector'] as String,
            sectors: [
              for (final s in p['sectors'] as List)
                PassSector(
                  name: s['name'] as String,
                  partial: s['partial'] as bool? ?? false,
                  timeS: (s['time_s'] as num).toDouble(),
                  note: s['note'] as String?,
                ),
            ],
            brakes: [
              for (final b in p['brakes'] as List)
                PassBrake(
                  sector: b['sector'] as String,
                  lapM: (b['lap_m'] as num).toDouble(),
                  vIn: (b['v_in'] as num).toDouble(),
                  vOut: (b['v_out'] as num).toDouble(),
                  peakG: (b['peak_g'] as num).toDouble(),
                  durationS: (b['duration_s'] as num).toDouble(),
                ),
            ],
          ),
      ],
      insights: [
        for (final i in j['insights'] as List)
          TrainingInsight(
            kind: i['kind'] as String,
            title: i['title'] as String,
            body: i['body'] as String,
            passId: i['pass_id'] as String?,
            sector: i['sector'] as String?,
          ),
      ],
    );
  }

  final String id;
  final String owner;
  final String circuitId;
  final String circuitName;
  final DateTime date;
  final String title;
  final String subtitle;
  final SessionSummary summary;
  final Map<String, dynamic> mapping;
  final List<TrainingPass> passes;
  final List<TrainingInsight> insights;

  List<TrainingInsight> get goods =>
      insights.where((i) => i.isGood).toList(growable: false);
  List<TrainingInsight> get bads =>
      insights.where((i) => !i.isGood).toList(growable: false);

  bool ownerMatches({required String alias, required String email}) {
    final o = owner.toLowerCase();
    if (o.isEmpty) return true;
    if (alias.isNotEmpty && (alias == o || alias.contains(o) || o.contains(alias))) {
      return true;
    }
    if (email.isNotEmpty && email.contains(o)) return true;
    // Bundled seed for the org account: always show until personal sessions exist.
    if (o == 'lujumicroservices') return true;
    return false;
  }
}
