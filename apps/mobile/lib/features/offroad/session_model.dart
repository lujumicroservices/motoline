import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

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
    this.i0,
    this.i1,
  });
  final String sector;
  final double lapM;
  final double vIn;
  final double vOut;
  final double peakG;
  final double durationS;

  /// First / last [PassTrace] row of the zone, when the asset carries a trace.
  final int? i0;
  final int? i1;
}

/// Peak moment of a pass, picked from the full 10 Hz data by the asset tool.
class PassEvent {
  const PassEvent({
    required this.kind,
    required this.index,
    required this.point,
    required this.lapM,
    required this.kmh,
    required this.value,
  });

  /// vmax | lean_r | lean_l | brake | accel | lat_g
  final String kind;

  /// Nearest [PassTrace] row.
  final int index;
  final LatLng point;
  final double lapM;
  final double kmh;

  /// km/h for vmax, degrees for lean, g for the rest (always positive).
  final double value;
}

/// Channel trace of one pass (5 Hz). Lean and lateral g are GNSS estimates
/// (speed × yaw rate), not IMU measurements.
class PassTrace {
  PassTrace({
    required this.hz,
    required this.t,
    required this.dist,
    required this.points,
    required this.lapM,
    required this.sector,
    required this.kmh,
    required this.longG,
    required this.braking,
    required this.lean,
    required this.latG,
    required this.alt,
    required this.outsideM,
  });

  factory PassTrace.fromJson(Map<String, dynamic> j) {
    final cols = [for (final c in j['cols'] as List) c as String];
    final rows = j['rows'] as List;
    int col(String name) => cols.indexOf(name);
    List<double> dbl(String name) {
      final k = col(name);
      return [for (final r in rows) ((r as List)[k] as num).toDouble()];
    }

    List<int> integer(String name) {
      final k = col(name);
      return [for (final r in rows) ((r as List)[k] as num).toInt()];
    }

    final lat = dbl('lat');
    final lng = dbl('lng');
    return PassTrace(
      hz: (j['hz'] as num).toInt(),
      t: dbl('t'),
      dist: dbl('d'),
      points: [for (var i = 0; i < lat.length; i++) LatLng(lat[i], lng[i])],
      lapM: dbl('s'),
      sector: integer('sec'),
      kmh: dbl('v'),
      longG: dbl('ax'),
      braking: integer('brk'),
      lean: dbl('lean'),
      latG: dbl('ay'),
      alt: dbl('alt'),
      outsideM: dbl('out'),
    );
  }

  final int hz;

  /// Seconds since the first row.
  final List<double> t;

  /// Metres ridden since the first row (does not wrap at the line).
  final List<double> dist;
  final List<LatLng> points;

  /// Metres along the circuit centerline (wraps at start/finish).
  final List<double> lapM;

  /// 0-based sector index.
  final List<int> sector;
  final List<double> kmh;

  /// + accelerating, − braking.
  final List<double> longG;
  final List<int> braking;

  /// + right, − left.
  final List<double> lean;
  final List<double> latG;
  final List<double> alt;
  final List<double> outsideM;

  int get length => points.length;
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
    this.events = const [],
    this.trace,
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
  final List<PassEvent> events;
  final PassTrace? trace;

  double get leanMax => leanMaxL > leanMaxR ? leanMaxL : leanMaxR;

  PassEvent? event(String kind) {
    for (final e in events) {
      if (e.kind == kind) return e;
    }
    return null;
  }
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
                  i0: (b['i0'] as num?)?.toInt(),
                  i1: (b['i1'] as num?)?.toInt(),
                ),
            ],
            events: [
              for (final e in p['events'] as List? ?? const [])
                PassEvent(
                  kind: e['kind'] as String,
                  index: (e['i'] as num).toInt(),
                  point: LatLng(
                    (e['lat'] as num).toDouble(),
                    (e['lng'] as num).toDouble(),
                  ),
                  lapM: (e['s'] as num).toDouble(),
                  kmh: (e['v'] as num).toDouble(),
                  value: (e['value'] as num).toDouble(),
                ),
            ],
            trace: p['trace'] == null
                ? null
                : PassTrace.fromJson(p['trace'] as Map<String, dynamic>),
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
