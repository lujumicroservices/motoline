import 'dart:math' as math;

/// One sample on an offroad circuit survey.
///
/// [accuracyM] is the phone's reported horizontal accuracy. Null means the
/// point was tapped on the map, or the fix did not report accuracy.
class CircuitPoint {
  const CircuitPoint({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.altitudeM,
  });

  final double lat;
  final double lng;
  final double? accuracyM;
  final double? altitudeM;

  Map<String, Object?> toJson() => {
    'lat': lat,
    'lng': lng,
    if (accuracyM != null) 'accuracyM': accuracyM,
    if (altitudeM != null) 'altitudeM': altitudeM,
  };

  factory CircuitPoint.fromJson(Map<String, dynamic> json) => CircuitPoint(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    accuracyM: (json['accuracyM'] as num?)?.toDouble(),
    altitudeM: (json['altitudeM'] as num?)?.toDouble(),
  );
}

/// Direction of travel, as the rider walks both edges.
enum TravelDirection {
  unset,
  clockwise,
  counterclockwise;

  static TravelDirection fromJson(Object? raw) {
    for (final value in TravelDirection.values) {
      if (value.name == raw) return value;
    }
    return TravelDirection.unset;
  }
}

/// A circuit survey: two perimeters plus the pieces a lap map still needs.
///
/// The outer ring is the outside edge of the dirt. The inner ring is the
/// infield edge. Walk both in the direction of travel. The racing line and
/// the start/finish gate are what turn those two edges into a circuit.
class OffroadCircuitSurvey {
  const OffroadCircuitSurvey({
    this.name = '',
    this.outer = const [],
    this.inner = const [],
    this.racingLine = const [],
    this.gateOuter,
    this.gateInner,
    this.direction = TravelDirection.unset,
  });

  final String name;
  final List<CircuitPoint> outer;
  final List<CircuitPoint> inner;
  final List<CircuitPoint> racingLine;
  final CircuitPoint? gateOuter;
  final CircuitPoint? gateInner;
  final TravelDirection direction;

  bool get hasGate => gateOuter != null && gateInner != null;

  OffroadCircuitSurvey copyWith({
    String? name,
    List<CircuitPoint>? outer,
    List<CircuitPoint>? inner,
    List<CircuitPoint>? racingLine,
    CircuitPoint? gateOuter,
    CircuitPoint? gateInner,
    TravelDirection? direction,
    bool clearGateOuter = false,
    bool clearGateInner = false,
  }) {
    return OffroadCircuitSurvey(
      name: name ?? this.name,
      outer: outer ?? this.outer,
      inner: inner ?? this.inner,
      racingLine: racingLine ?? this.racingLine,
      gateOuter: clearGateOuter ? null : (gateOuter ?? this.gateOuter),
      gateInner: clearGateInner ? null : (gateInner ?? this.gateInner),
      direction: direction ?? this.direction,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'outer': [for (final p in outer) p.toJson()],
    'inner': [for (final p in inner) p.toJson()],
    'racingLine': [for (final p in racingLine) p.toJson()],
    'gateOuter': gateOuter?.toJson(),
    'gateInner': gateInner?.toJson(),
    'direction': direction.name,
  };

  factory OffroadCircuitSurvey.fromJson(Map<String, dynamic> json) {
    List<CircuitPoint> points(Object? raw) {
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            CircuitPoint.fromJson(Map<String, dynamic>.from(item)),
      ];
    }

    CircuitPoint? point(Object? raw) {
      if (raw is! Map) return null;
      return CircuitPoint.fromJson(Map<String, dynamic>.from(raw));
    }

    return OffroadCircuitSurvey(
      name: json['name'] as String? ?? '',
      outer: points(json['outer']),
      inner: points(json['inner']),
      racingLine: points(json['racingLine']),
      gateOuter: point(json['gateOuter']),
      gateInner: point(json['gateInner']),
      direction: TravelDirection.fromJson(json['direction']),
    );
  }
}

enum CircuitSampleReject { tooClose, poorAccuracy }

class CircuitSampleDecision {
  const CircuitSampleDecision.keep() : keep = true, reject = null;

  const CircuitSampleDecision.reject(this.reject) : keep = false;

  final bool keep;
  final CircuitSampleReject? reject;
}

/// Keep a live GPS sample when it moves the perimeter and the fix is usable.
///
/// Tapped points (null accuracy) are kept. A fix worse than [maxAccuracyM]
/// is dropped so trees and a pocket do not pull the edge.
CircuitSampleDecision considerCircuitSample({
  required List<CircuitPoint> existing,
  required CircuitPoint next,
  double minSpacingM = 3,
  double maxAccuracyM = 12,
}) {
  final accuracy = next.accuracyM;
  if (accuracy != null && accuracy.isFinite && accuracy > maxAccuracyM) {
    return const CircuitSampleDecision.reject(CircuitSampleReject.poorAccuracy);
  }
  if (existing.isNotEmpty) {
    final last = existing.last;
    final gap = circuitDistanceMeters(last, next);
    if (gap < minSpacingM) {
      return const CircuitSampleDecision.reject(CircuitSampleReject.tooClose);
    }
  }
  return const CircuitSampleDecision.keep();
}

/// Append the first point when the walker is close enough to close the ring.
///
/// Returns the same list when the gap is already tiny, or still too large.
List<CircuitPoint> closeCircuitRing(
  List<CircuitPoint> points, {
  double maxGapM = 20,
}) {
  if (points.length < 3) return points;
  final gap = circuitDistanceMeters(points.last, points.first);
  if (gap <= 1) return points;
  if (gap <= maxGapM) return [...points, points.first];
  return points;
}

enum CircuitAdviceLevel { required, recommended, tip }

enum CircuitAdviceCode {
  needOuter,
  outerTooFew,
  outerOpen,
  outerTooShort,
  needInner,
  innerTooFew,
  innerOpen,
  innerTooShort,
  innerOutside,
  ringsCross,
  edgesSwapped,
  widthNarrow,
  widthWide,
  needLine,
  lineOutside,
  needGate,
  gateOff,
  needDirection,
  directionMismatch,
  poorAccuracy,
  spacingSparse,
  spacingDense,
  needElevation,
  alignLandmark,
  walkAgain,
}

class CircuitAdvice {
  const CircuitAdvice({
    required this.code,
    required this.level,
    this.meters,
    this.count,
  });

  final CircuitAdviceCode code;
  final CircuitAdviceLevel level;
  final double? meters;
  final int? count;
}

class CircuitAssessment {
  const CircuitAssessment({
    required this.advice,
    required this.ready,
    required this.score,
    this.outerLengthM,
    this.innerLengthM,
    this.outerClosureM,
    this.innerClosureM,
    this.minWidthM,
    this.maxWidthM,
  });

  final List<CircuitAdvice> advice;
  final bool ready;
  final int score;
  final double? outerLengthM;
  final double? innerLengthM;
  final double? outerClosureM;
  final double? innerClosureM;
  final double? minWidthM;
  final double? maxWidthM;

  bool has(CircuitAdviceCode code) => advice.any((item) => item.code == code);
}

/// A ring counts as closed when the walker is back within this of the start.
const double kCircuitCloseMeters = 15;

const int kCircuitMinRingPoints = 8;
const double kCircuitMinOuterLengthM = 40;
const double kCircuitMinInnerLengthM = 20;
const double kCircuitNarrowWidthM = 3;
const double kCircuitWideWidthM = 60;
const double kCircuitEdgeSlackM = 4;
const double kCircuitLineSlackM = 6;
const double kCircuitGateSnapM = 12;
const double kCircuitMaxAccuracyM = 12;
const double kCircuitSparseSpacingM = 12;
const double kCircuitDenseSpacingM = 0.8;

/// What the two perimeters still need before the circuit is worth using.
CircuitAssessment assessOffroadCircuit(OffroadCircuitSurvey survey) {
  final advice = <CircuitAdvice>[];

  final outerLen = _pathLength(survey.outer, closed: false);
  final innerLen = _pathLength(survey.inner, closed: false);
  final outerGap = _closureGap(survey.outer);
  final innerGap = _closureGap(survey.inner);
  final outerClosed = _isClosed(survey.outer);
  final innerClosed = _isClosed(survey.inner);
  final outerCount = _stripClose(survey.outer).length;
  final innerCount = _stripClose(survey.inner).length;

  final outerOk =
      outerClosed &&
      outerCount >= kCircuitMinRingPoints &&
      outerLen >= kCircuitMinOuterLengthM;
  final outerHasShape = outerCount >= 4;

  if (survey.outer.isEmpty) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.needOuter,
        level: CircuitAdviceLevel.required,
      ),
    );
  } else if (outerCount < kCircuitMinRingPoints) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.outerTooFew,
        level: CircuitAdviceLevel.required,
      ),
    );
  } else if (!outerClosed && outerGap != null) {
    advice.add(
      CircuitAdvice(
        code: CircuitAdviceCode.outerOpen,
        level: CircuitAdviceLevel.required,
        meters: outerGap,
      ),
    );
  } else if (outerClosed && outerLen < kCircuitMinOuterLengthM) {
    advice.add(
      CircuitAdvice(
        code: CircuitAdviceCode.outerTooShort,
        level: CircuitAdviceLevel.required,
        meters: outerLen,
      ),
    );
  }

  if (survey.inner.isEmpty) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.needInner,
        level: CircuitAdviceLevel.required,
      ),
    );
  } else if (innerCount < kCircuitMinRingPoints) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.innerTooFew,
        level: CircuitAdviceLevel.required,
      ),
    );
  } else if (!innerClosed && innerGap != null) {
    advice.add(
      CircuitAdvice(
        code: CircuitAdviceCode.innerOpen,
        level: CircuitAdviceLevel.required,
        meters: innerGap,
      ),
    );
  } else if (innerClosed && innerLen < kCircuitMinInnerLengthM) {
    advice.add(
      CircuitAdvice(
        code: CircuitAdviceCode.innerTooShort,
        level: CircuitAdviceLevel.required,
        meters: innerLen,
      ),
    );
  }

  final outerArea = outerCount >= 4 ? _signedAreaM2(survey.outer) : 0.0;
  final innerArea = innerCount >= 4 ? _signedAreaM2(survey.inner) : 0.0;
  final swapped =
      outerCount >= 4 &&
      innerCount >= 4 &&
      innerArea.abs() > outerArea.abs() * 1.05;
  final ringsReadyForContainment = outerClosed && innerClosed && !swapped;

  var crosses = false;
  var innerOutside = false;
  if (swapped) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.edgesSwapped,
        level: CircuitAdviceLevel.required,
      ),
    );
  } else if (ringsReadyForContainment) {
    crosses = _ringsCross(survey.outer, survey.inner);
    innerOutside = _innerLeavesOuter(survey.outer, survey.inner);
    if (crosses) {
      advice.add(
        const CircuitAdvice(
          code: CircuitAdviceCode.ringsCross,
          level: CircuitAdviceLevel.required,
        ),
      );
    }
    if (innerOutside) {
      advice.add(
        const CircuitAdvice(
          code: CircuitAdviceCode.innerOutside,
          level: CircuitAdviceLevel.required,
        ),
      );
    }
  }

  final corridorOk = ringsReadyForContainment && !crosses && !innerOutside;
  double? minWidth;
  double? maxWidth;
  if (corridorOk) {
    final widths = _widthsAlongOuter(survey.outer, survey.inner);
    if (widths.isNotEmpty) {
      minWidth = widths.reduce(math.min);
      maxWidth = widths.reduce(math.max);
      if (minWidth < kCircuitNarrowWidthM) {
        advice.add(
          CircuitAdvice(
            code: CircuitAdviceCode.widthNarrow,
            level: CircuitAdviceLevel.required,
            meters: minWidth,
          ),
        );
      } else if (maxWidth > kCircuitWideWidthM) {
        advice.add(
          CircuitAdvice(
            code: CircuitAdviceCode.widthWide,
            level: CircuitAdviceLevel.recommended,
            meters: maxWidth,
          ),
        );
      }
    }
  }

  final innerOk =
      innerClosed &&
      innerCount >= kCircuitMinRingPoints &&
      innerLen >= kCircuitMinInnerLengthM &&
      corridorOk &&
      (minWidth == null || minWidth >= kCircuitNarrowWidthM);

  final lineCount = survey.racingLine.length;
  var lineOk = false;
  if (lineCount == 0) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.needLine,
        level: CircuitAdviceLevel.required,
      ),
    );
  } else if (corridorOk) {
    final outside = _lineOutsideCount(survey);
    lineOk = lineCount >= kCircuitMinRingPoints && outside == 0;
    if (outside > 0) {
      advice.add(
        CircuitAdvice(
          code: CircuitAdviceCode.lineOutside,
          level: CircuitAdviceLevel.required,
          count: outside,
        ),
      );
    } else if (lineCount < kCircuitMinRingPoints) {
      advice.add(
        CircuitAdvice(
          code: CircuitAdviceCode.needLine,
          level: CircuitAdviceLevel.required,
          count: lineCount,
        ),
      );
    }
  }

  var gateOk = false;
  if (!survey.hasGate) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.needGate,
        level: CircuitAdviceLevel.required,
      ),
    );
  } else if (corridorOk) {
    gateOk = _gateFits(survey);
    if (!gateOk) {
      advice.add(
        const CircuitAdvice(
          code: CircuitAdviceCode.gateOff,
          level: CircuitAdviceLevel.required,
        ),
      );
    }
  }

  var directionOk = false;
  final mismatch = _directionMismatch(survey, outerArea, innerArea);
  if (survey.direction == TravelDirection.unset) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.needDirection,
        level: CircuitAdviceLevel.recommended,
      ),
    );
  } else if (mismatch) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.directionMismatch,
        level: CircuitAdviceLevel.recommended,
      ),
    );
  } else if (outerCount >= 4) {
    directionOk = true;
  }

  var accuracyOk = false;
  var spacingOk = false;
  if (outerCount >= 4) {
    final poor = _poorAccuracyCount(survey.outer);
    final known = survey.outer.where((p) => p.accuracyM != null).length;
    if (known > 0 && poor / known > 0.25) {
      advice.add(
        CircuitAdvice(
          code: CircuitAdviceCode.poorAccuracy,
          level: CircuitAdviceLevel.recommended,
          count: poor,
        ),
      );
    } else {
      accuracyOk = true;
    }

    final spacing = _medianSpacing(survey.outer);
    if (spacing != null && spacing > kCircuitSparseSpacingM) {
      advice.add(
        CircuitAdvice(
          code: CircuitAdviceCode.spacingSparse,
          level: CircuitAdviceLevel.recommended,
          meters: spacing,
        ),
      );
    } else if (spacing != null && spacing < kCircuitDenseSpacingM) {
      advice.add(
        const CircuitAdvice(
          code: CircuitAdviceCode.spacingDense,
          level: CircuitAdviceLevel.recommended,
        ),
      );
    } else if (spacing != null) {
      spacingOk = true;
    }

    final withAlt = survey.outer.where((p) => p.altitudeM != null).length;
    if (withAlt < survey.outer.length * 0.3) {
      advice.add(
        const CircuitAdvice(
          code: CircuitAdviceCode.needElevation,
          level: CircuitAdviceLevel.tip,
        ),
      );
    }
  }

  if (outerClosed && outerCount >= kCircuitMinRingPoints) {
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.alignLandmark,
        level: CircuitAdviceLevel.tip,
      ),
    );
    advice.add(
      const CircuitAdvice(
        code: CircuitAdviceCode.walkAgain,
        level: CircuitAdviceLevel.tip,
      ),
    );
  }

  var score = 0;
  if (outerOk) {
    score += 28;
  } else if (outerHasShape) {
    score += 8;
  }
  if (innerOk) {
    score += 22;
  } else if (innerCount >= 4) {
    score += 6;
  }
  if (lineOk) {
    score += 18;
  }
  if (gateOk) {
    score += 14;
  }
  if (directionOk) score += 6;
  if (accuracyOk) score += 6;
  if (spacingOk) score += 6;
  if (crosses || swapped) score -= 20;
  if (minWidth != null && minWidth < kCircuitNarrowWidthM) score -= 10;

  final ready = advice.every(
    (item) => item.level != CircuitAdviceLevel.required,
  );

  return CircuitAssessment(
    advice: advice,
    ready: ready,
    score: score.clamp(0, 100),
    outerLengthM: survey.outer.length >= 2 ? outerLen : null,
    innerLengthM: survey.inner.length >= 2 ? innerLen : null,
    outerClosureM: outerGap,
    innerClosureM: innerGap,
    minWidthM: minWidth,
    maxWidthM: maxWidth,
  );
}

/// Distance in meters between two survey points.
double circuitDistanceMeters(CircuitPoint a, CircuitPoint b) =>
    _haversineMeters(a.lat, a.lng, b.lat, b.lng);

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

bool _isClosed(List<CircuitPoint> points) {
  final gap = _closureGap(points);
  return gap != null && gap <= kCircuitCloseMeters;
}

double? _closureGap(List<CircuitPoint> points) {
  if (points.length < 3) return null;
  return _haversineMeters(
    points.last.lat,
    points.last.lng,
    points.first.lat,
    points.first.lng,
  );
}

List<CircuitPoint> _stripClose(List<CircuitPoint> points) {
  if (points.length >= 2) {
    final gap = _haversineMeters(
      points.last.lat,
      points.last.lng,
      points.first.lat,
      points.first.lng,
    );
    if (gap <= 1) return points.sublist(0, points.length - 1);
  }
  return points;
}

double _pathLength(List<CircuitPoint> points, {required bool closed}) {
  final ring = _stripClose(points);
  if (ring.length < 2) return 0;
  var total = 0.0;
  final last = closed ? ring.length : ring.length - 1;
  for (var i = 0; i < last; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    total += _haversineMeters(a.lat, a.lng, b.lat, b.lng);
  }
  return total;
}

class _XY {
  const _XY(this.x, this.y);
  final double x;
  final double y;
}

_XY _project(CircuitPoint point, CircuitPoint origin) {
  const metersPerDegLat = 110540.0;
  final metersPerDegLng = 111320.0 * math.cos(_rad(origin.lat));
  return _XY(
    (point.lng - origin.lng) * metersPerDegLng,
    (point.lat - origin.lat) * metersPerDegLat,
  );
}

double _signedAreaM2(List<CircuitPoint> points) {
  final ring = _stripClose(points);
  if (ring.length < 3) return 0;
  final origin = ring.first;
  final xy = [for (final p in ring) _project(p, origin)];
  var sum = 0.0;
  for (var i = 0; i < xy.length; i++) {
    final j = (i + 1) % xy.length;
    sum += xy[i].x * xy[j].y - xy[j].x * xy[i].y;
  }
  return sum / 2;
}

bool _pointInRing(CircuitPoint point, List<CircuitPoint> ring) {
  final pts = _stripClose(ring);
  if (pts.length < 3) return false;
  final origin = pts.first;
  final p = _project(point, origin);
  final xy = [for (final item in pts) _project(item, origin)];
  var inside = false;
  for (var i = 0, j = xy.length - 1; i < xy.length; j = i++) {
    final yi = xy[i].y;
    final yj = xy[j].y;
    final xi = xy[i].x;
    final xj = xy[j].x;
    final crosses =
        (yi > p.y) != (yj > p.y) &&
        (p.x < (xj - xi) * (p.y - yi) / (yj - yi + 0.0) + xi);
    if (crosses) inside = !inside;
  }
  return inside;
}

double _distanceToPath(
  CircuitPoint point,
  List<CircuitPoint> path, {
  required bool closed,
}) {
  final pts = _stripClose(path);
  if (pts.isEmpty) return double.infinity;
  if (pts.length == 1) {
    return _haversineMeters(point.lat, point.lng, pts.first.lat, pts.first.lng);
  }
  final origin = pts.first;
  final p = _project(point, origin);
  final xy = [for (final item in pts) _project(item, origin)];
  final segments = closed ? xy.length : xy.length - 1;
  var best = double.infinity;
  for (var i = 0; i < segments; i++) {
    final d = _distPointSeg(p, xy[i], xy[(i + 1) % xy.length]);
    if (d < best) best = d;
  }
  return best;
}

double _distPointSeg(_XY p, _XY a, _XY b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  if (len2 < 1e-6) return _dist(p, a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  return _dist(p, _XY(a.x + t * dx, a.y + t * dy));
}

double _dist(_XY a, _XY b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

int _orient(_XY a, _XY b, _XY c) {
  final v = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
  if (v.abs() < 1e-4) return 0;
  return v > 0 ? 1 : -1;
}

bool _properCross(_XY a, _XY b, _XY c, _XY d) {
  final o1 = _orient(a, b, c);
  final o2 = _orient(a, b, d);
  final o3 = _orient(c, d, a);
  final o4 = _orient(c, d, b);
  return o1 != 0 && o2 != 0 && o3 != 0 && o4 != 0 && o1 != o2 && o3 != o4;
}

bool _ringsCross(List<CircuitPoint> outer, List<CircuitPoint> inner) {
  final a = _stripClose(outer);
  final b = _stripClose(inner);
  if (a.length < 3 || b.length < 3) return false;
  final origin = a.first;
  final ax = [for (final p in a) _project(p, origin)];
  final bx = [for (final p in b) _project(p, origin)];
  for (var i = 0; i < ax.length; i++) {
    final a1 = ax[i];
    final a2 = ax[(i + 1) % ax.length];
    for (var j = 0; j < bx.length; j++) {
      if (_properCross(a1, a2, bx[j], bx[(j + 1) % bx.length])) return true;
    }
  }
  return false;
}

bool _innerLeavesOuter(List<CircuitPoint> outer, List<CircuitPoint> inner) {
  for (final point in _stripClose(inner)) {
    final inside = _pointInRing(point, outer);
    final near =
        _distanceToPath(point, outer, closed: true) <= kCircuitEdgeSlackM;
    if (!inside && !near) return true;
  }
  return false;
}

bool _inCorridor(CircuitPoint point, OffroadCircuitSurvey survey) {
  final insideOuter =
      _pointInRing(point, survey.outer) ||
      _distanceToPath(point, survey.outer, closed: true) <= kCircuitLineSlackM;
  final infield =
      _pointInRing(point, survey.inner) &&
      _distanceToPath(point, survey.inner, closed: true) > kCircuitLineSlackM;
  return insideOuter && !infield;
}

int _lineOutsideCount(OffroadCircuitSurvey survey) {
  var outside = 0;
  for (final point in survey.racingLine) {
    if (!_inCorridor(point, survey)) outside++;
  }
  return outside;
}

bool _gateFits(OffroadCircuitSurvey survey) {
  final outer = survey.gateOuter;
  final inner = survey.gateInner;
  if (outer == null || inner == null) return false;
  final dOuter = _distanceToPath(outer, survey.outer, closed: true);
  final dInner = _distanceToPath(inner, survey.inner, closed: true);
  if (dOuter > kCircuitGateSnapM || dInner > kCircuitGateSnapM) return false;
  final span = _haversineMeters(outer.lat, outer.lng, inner.lat, inner.lng);
  if (span < 2 || span > 80) return false;
  final mid = CircuitPoint(
    lat: (outer.lat + inner.lat) / 2,
    lng: (outer.lng + inner.lng) / 2,
  );
  return _inCorridor(mid, survey);
}

bool _directionMismatch(
  OffroadCircuitSurvey survey,
  double outerArea,
  double innerArea,
) {
  if (survey.direction != TravelDirection.unset && outerArea.abs() > 50) {
    final clockwise = outerArea < 0;
    if (survey.direction == TravelDirection.clockwise && !clockwise)
      return true;
    if (survey.direction == TravelDirection.counterclockwise && clockwise) {
      return true;
    }
  }
  if (outerArea.abs() > 50 && innerArea.abs() > 50) {
    if (outerArea.sign != innerArea.sign) return true;
  }
  return false;
}

int _poorAccuracyCount(List<CircuitPoint> points) {
  var count = 0;
  for (final point in points) {
    final accuracy = point.accuracyM;
    if (accuracy != null && accuracy > kCircuitMaxAccuracyM) count++;
  }
  return count;
}

double? _medianSpacing(List<CircuitPoint> points) {
  final ring = _stripClose(points);
  if (ring.length < 2) return null;
  final steps = <double>[];
  for (var i = 1; i < ring.length; i++) {
    final d = _haversineMeters(
      ring[i - 1].lat,
      ring[i - 1].lng,
      ring[i].lat,
      ring[i].lng,
    );
    if (d >= 0.3) steps.add(d);
  }
  if (steps.isEmpty) return null;
  steps.sort();
  final mid = steps.length ~/ 2;
  if (steps.length.isOdd) return steps[mid];
  return (steps[mid - 1] + steps[mid]) / 2;
}

List<double> _widthsAlongOuter(
  List<CircuitPoint> outer,
  List<CircuitPoint> inner,
) {
  final samples = _samplePath(outer, 5);
  if (samples.isEmpty) return const [];
  return [
    for (final sample in samples) _distanceToPath(sample, inner, closed: true),
  ];
}

List<CircuitPoint> _samplePath(List<CircuitPoint> points, double stepM) {
  final ring = _stripClose(points);
  if (ring.length < 2) return ring;
  final samples = <CircuitPoint>[ring.first];
  var since = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    final seg = _haversineMeters(a.lat, a.lng, b.lat, b.lng);
    if (seg < 0.05) continue;
    var pos = stepM - since;
    while (pos <= seg + 1e-6) {
      final t = (pos / seg).clamp(0.0, 1.0);
      samples.add(
        CircuitPoint(
          lat: a.lat + (b.lat - a.lat) * t,
          lng: a.lng + (b.lng - a.lng) * t,
        ),
      );
      pos += stepM;
    }
    since = seg - (pos - stepM);
    if (since < 0) since = 0;
  }
  return samples;
}

double _rad(double degrees) => degrees * math.pi / 180;
