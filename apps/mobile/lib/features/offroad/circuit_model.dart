import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Circuits bundled with the app (smoothed geometry exported from Métrica
/// firmware by `tool/export_circuit_asset.py`).
const bundledCircuitAssets = ['assets/circuits/8horas.json'];

final circuitsProvider = FutureProvider<List<Circuit>>((ref) async {
  final out = <Circuit>[];
  for (final path in bundledCircuitAssets) {
    final raw = await rootBundle.loadString(path);
    out.add(Circuit.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }
  return out;
});

class CircuitGate {
  const CircuitGate(this.a, this.b, this.s, this.kind);
  final LatLng a;
  final LatLng b;
  final double s;

  /// 0 = start/finish, 1 = sector boundary, 2 = micro-sector.
  final int kind;
}

class CircuitSector {
  const CircuitSector({
    required this.name,
    required this.startM,
    required this.endM,
    required this.lengthM,
    required this.widthMin,
    required this.widthMax,
    required this.widthMedian,
    required this.elevMin,
    required this.elevMax,
  });

  final String name;
  final double startM;
  final double endM;
  final double lengthM;
  final double widthMin;
  final double widthMax;
  final double widthMedian;
  final double? elevMin;
  final double? elevMax;
}

class CircuitSmoothing {
  const CircuitSmoothing(this.json);
  final Map<String, dynamic> json;
  double get maxDevOuter => _d('max_dev_outer_m');
  double get maxDevInner => _d('max_dev_inner_m');
  double get rmsOuter => _d('rms_outer_m');
  double get rmsInner => _d('rms_inner_m');
  double get outlierM => _d('outlier_m');
  double get resampleM => _d('resample_m');
  int get selfIntersections => (json['self_intersections'] as num?)?.toInt() ?? 0;
  double get innerInsidePct => _d('inner_inside_outer_pct');
  double _d(String k) => (json[k] as num?)?.toDouble() ?? 0;
}

class Circuit {
  Circuit({
    required this.id,
    required this.name,
    required this.place,
    required this.mappedOn,
    required this.ccw,
    required this.anchor,
    required this.anchorAlt,
    required this.lengthM,
    required this.widthMin,
    required this.widthMax,
    required this.widthMedian,
    required this.outer,
    required this.inner,
    required this.center,
    required this.gates,
    required this.sectors,
    required this.elevStepM,
    required this.elevation,
    required this.elevSource,
    required this.loggers,
    required this.receiver,
    required this.smoothing,
  }) : centerCum = _cumulative(center);

  factory Circuit.fromJson(Map<String, dynamic> j) {
    List<LatLng> pts(String k) => [
      for (final p in j[k] as List)
        LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];
    final w = j['width'] as Map<String, dynamic>;
    final e = j['elevation'] as Map<String, dynamic>;
    final m = j['mapping'] as Map<String, dynamic>;
    final anchor = j['anchor'] as Map<String, dynamic>;
    return Circuit(
      id: j['id'] as String,
      name: j['name'] as String,
      place: j['place'] as String? ?? '',
      mappedOn: DateTime.parse(j['mapped_on'] as String),
      ccw: j['direction'] == 'CCW',
      anchor: LatLng(
        (anchor['lat'] as num).toDouble(),
        (anchor['lon'] as num).toDouble(),
      ),
      anchorAlt: (anchor['alt'] as num).toDouble(),
      lengthM: (j['length_m'] as num).toDouble(),
      widthMin: (w['min'] as num).toDouble(),
      widthMax: (w['max'] as num).toDouble(),
      widthMedian: (w['median'] as num).toDouble(),
      outer: pts('outer'),
      inner: pts('inner'),
      center: pts('center'),
      gates: [
        for (final g in j['gates'] as List)
          CircuitGate(
            LatLng((g['a'][0] as num).toDouble(), (g['a'][1] as num).toDouble()),
            LatLng((g['b'][0] as num).toDouble(), (g['b'][1] as num).toDouble()),
            (g['s'] as num).toDouble(),
            (g['kind'] as num).toInt(),
          ),
      ],
      sectors: [
        for (final s in j['sectors'] as List)
          CircuitSector(
            name: s['name'] as String,
            startM: (s['start_m'] as num).toDouble(),
            endM: (s['end_m'] as num).toDouble(),
            lengthM: (s['length_m'] as num).toDouble(),
            widthMin: (s['width_min'] as num).toDouble(),
            widthMax: (s['width_max'] as num).toDouble(),
            widthMedian: (s['width_median'] as num).toDouble(),
            elevMin: (s['elev_min'] as num?)?.toDouble(),
            elevMax: (s['elev_max'] as num?)?.toDouble(),
          ),
      ],
      elevStepM: (e['step_m'] as num).toDouble(),
      elevation: [for (final v in e['values_m'] as List) (v as num).toDouble()],
      elevSource: e['source'] as String? ?? '',
      loggers: [
        for (final l in m['loggers'] as List)
          (id: l['id'] as String, edge: l['edge'] as String),
      ],
      receiver: m['receiver'] as String? ?? '',
      smoothing: CircuitSmoothing(m['smoothing'] as Map<String, dynamic>),
    );
  }

  final String id;
  final String name;
  final String place;
  final DateTime mappedOn;
  final bool ccw;
  final LatLng anchor;
  final double anchorAlt;
  final double lengthM;
  final double widthMin;
  final double widthMax;
  final double widthMedian;
  final List<LatLng> outer;
  final List<LatLng> inner;
  final List<LatLng> center;
  final List<CircuitGate> gates;
  final List<CircuitSector> sectors;
  final double elevStepM;
  final List<double> elevation;
  final String elevSource;
  final List<({String id, String edge})> loggers;
  final String receiver;
  final CircuitSmoothing smoothing;

  /// Metres along the centerline at each [center] point.
  final List<double> centerCum;

  double get elevMin => elevation.reduce(math.min);
  double get elevMax => elevation.reduce(math.max);
  double get elevDrop => elevMax - elevMin;

  int sectorIndexAt(double s) {
    for (var i = 0; i < sectors.length; i++) {
      if (s < sectors[i].endM) return i;
    }
    return sectors.length - 1;
  }

  /// Centerline split into one polyline per sector.
  List<List<LatLng>> sectorLines() {
    final out = [for (final _ in sectors) <LatLng>[]];
    final loop = [...center, center.first];
    final cum = [...centerCum, lengthM];
    int? prev;
    for (var i = 0; i < loop.length; i++) {
      final k = sectorIndexAt(math.min(cum[i], lengthM - 0.01));
      if (prev != null && prev != k) out[prev].add(loop[i]);
      out[k].add(loop[i]);
      prev = k;
    }
    return out;
  }

  static List<double> _cumulative(List<LatLng> pts) {
    const d = Distance();
    final out = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      out.add(out.last + d(pts[i - 1], pts[i]));
    }
    return out;
  }
}
