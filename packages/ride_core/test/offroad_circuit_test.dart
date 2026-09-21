import 'dart:math' as math;

import 'package:ride_core/ride_core.dart';
import 'package:test/test.dart';

void main() {
  group('samples', () {
    test('drops a fix that barely moved or is too loose', () {
      final first = _at(0, 0);
      expect(
        considerCircuitSample(existing: const [], next: first).keep,
        isTrue,
      );
      expect(
        considerCircuitSample(existing: [first], next: _at(1, 0)).reject,
        CircuitSampleReject.tooClose,
      );
      expect(
        considerCircuitSample(
          existing: [first],
          next: _at(5, 0, accuracyM: 20),
        ).reject,
        CircuitSampleReject.poorAccuracy,
      );
      expect(
        considerCircuitSample(
          existing: [first],
          next: _at(5, 0, accuracyM: null),
        ).keep,
        isTrue,
      );
    });

    test('closes a ring only when the walker is near the start', () {
      final open = [_at(0, 0), _at(30, 0), _at(30, 10)];
      expect(closeCircuitRing(open), same(open));

      final near = [_at(0, 0), _at(40, 0), _at(40, 8), _at(0, 8)];
      final closed = closeCircuitRing(near);
      expect(closed.length, near.length + 1);
      expect(closed.last.lat, near.first.lat);
      expect(closeCircuitRing(closed), same(closed));
    });
  });

  group('assess', () {
    test('a blank survey lists the pieces a circuit still needs', () {
      final result = assessOffroadCircuit(const OffroadCircuitSurvey());
      expect(result.ready, isFalse);
      expect(result.score, 0);
      expect(result.has(CircuitAdviceCode.needOuter), isTrue);
      expect(result.has(CircuitAdviceCode.needInner), isTrue);
      expect(result.has(CircuitAdviceCode.needLine), isTrue);
      expect(result.has(CircuitAdviceCode.needGate), isTrue);
      expect(result.has(CircuitAdviceCode.needDirection), isTrue);
    });

    test('a closed corridor with a line and a gate is ready', () {
      final result = assessOffroadCircuit(_goodSurvey());
      expect(
        result.ready,
        isTrue,
        reason: result.advice.map((a) => a.code).join(','),
      );
      expect(result.score, greaterThanOrEqualTo(90));
      expect(result.minWidthM, inInclusiveRange(18, 22));
      expect(result.maxWidthM, inInclusiveRange(20, 32));
      expect(result.outerLengthM, inInclusiveRange(390, 410));
      expect(result.has(CircuitAdviceCode.alignLandmark), isTrue);
      expect(result.has(CircuitAdviceCode.walkAgain), isTrue);
      expect(
        result.advice.every(
          (item) => item.level != CircuitAdviceLevel.required,
        ),
        isTrue,
      );
    });

    test('an open outside edge reports the gap', () {
      final outer = _rect(west: 0, south: 0, east: 100, north: 80);
      outer.removeLast();
      outer.removeLast();
      final result = assessOffroadCircuit(OffroadCircuitSurvey(outer: outer));
      final open = result.advice.firstWhere(
        (item) => item.code == CircuitAdviceCode.outerOpen,
      );
      expect(open.meters, greaterThan(15));
      expect(result.ready, isFalse);
    });

    test('the inside edge must stay inside and must not cross', () {
      final outside = assessOffroadCircuit(
        OffroadCircuitSurvey(
          outer: _rect(west: 0, south: 0, east: 100, north: 100),
          inner: _rect(west: 300, south: 0, east: 360, north: 60),
          direction: TravelDirection.counterclockwise,
        ),
      );
      expect(outside.has(CircuitAdviceCode.innerOutside), isTrue);

      final crossing = assessOffroadCircuit(
        OffroadCircuitSurvey(
          outer: _rect(west: 0, south: 0, east: 100, north: 100),
          inner: _rect(west: 85, south: 15, east: 145, north: 75),
        ),
      );
      expect(crossing.has(CircuitAdviceCode.ringsCross), isTrue);
    });

    test('swapped edges and a too-narrow corridor are called out', () {
      final swapped = assessOffroadCircuit(
        OffroadCircuitSurvey(
          outer: _rect(west: 20, south: 20, east: 80, north: 80),
          inner: _rect(west: 0, south: 0, east: 100, north: 100),
        ),
      );
      expect(swapped.has(CircuitAdviceCode.edgesSwapped), isTrue);

      final narrow = assessOffroadCircuit(
        OffroadCircuitSurvey(
          outer: _rect(west: 0, south: 0, east: 100, north: 100),
          inner: _rect(west: 1, south: 1, east: 99, north: 99),
          direction: TravelDirection.counterclockwise,
        ),
      );
      expect(narrow.has(CircuitAdviceCode.widthNarrow), isTrue);
      expect(narrow.minWidthM, lessThan(3));
    });

    test('the racing line and the gate have to sit in the dirt', () {
      final good = _goodSurvey();
      final lineOut = assessOffroadCircuit(
        good.copyWith(racingLine: [_at(-30, 50), ...good.racingLine]),
      );
      expect(lineOut.has(CircuitAdviceCode.lineOutside), isTrue);

      final gateOut = assessOffroadCircuit(
        good.copyWith(gateOuter: _at(50, 50), gateInner: _at(55, 50)),
      );
      expect(gateOut.has(CircuitAdviceCode.gateOff), isTrue);
    });

    test('direction, accuracy, and spacing are part of a good map', () {
      final backwards = assessOffroadCircuit(
        _goodSurvey().copyWith(direction: TravelDirection.clockwise),
      );
      expect(backwards.has(CircuitAdviceCode.directionMismatch), isTrue);

      final loose = _rect(west: 0, south: 0, east: 100, north: 100);
      for (var i = 0; i < loose.length; i += 2) {
        final p = loose[i];
        loose[i] = CircuitPoint(lat: p.lat, lng: p.lng, accuracyM: 40);
      }
      final poor = assessOffroadCircuit(OffroadCircuitSurvey(outer: loose));
      expect(poor.has(CircuitAdviceCode.poorAccuracy), isTrue);

      final sparse = assessOffroadCircuit(
        OffroadCircuitSurvey(
          outer: _rect(west: 0, south: 0, east: 200, north: 80, step: 40),
        ),
      );
      expect(sparse.has(CircuitAdviceCode.spacingSparse), isTrue);
    });

    test('round-trips through json', () {
      final survey = _goodSurvey().copyWith(name: 'Bugambilias');
      final again = OffroadCircuitSurvey.fromJson(survey.toJson());
      expect(again.name, 'Bugambilias');
      expect(again.outer.length, survey.outer.length);
      expect(again.direction, TravelDirection.counterclockwise);
      expect(again.gateOuter!.lat, survey.gateOuter!.lat);
      expect(assessOffroadCircuit(again).ready, isTrue);
    });
  });
}

OffroadCircuitSurvey _goodSurvey() {
  return OffroadCircuitSurvey(
    outer: _rect(west: 0, south: 0, east: 100, north: 100),
    inner: _rect(west: 20, south: 20, east: 80, north: 80),
    racingLine: _rect(west: 10, south: 10, east: 90, north: 90),
    gateOuter: _at(50, 0),
    gateInner: _at(50, 20),
    direction: TravelDirection.counterclockwise,
  );
}

/// Rectangle walked counterclockwise, one point every [step] meters, closed.
List<CircuitPoint> _rect({
  required double west,
  required double south,
  required double east,
  required double north,
  double step = 10,
}) {
  final points = <CircuitPoint>[];
  void edge(double x0, double y0, double x1, double y1) {
    final len = math.sqrt(math.pow(x1 - x0, 2) + math.pow(y1 - y0, 2));
    final n = math.max(1, (len / step).floor());
    for (var i = 0; i < n; i++) {
      final t = i / n;
      points.add(_at(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t));
    }
  }

  edge(west, south, east, south);
  edge(east, south, east, north);
  edge(east, north, west, north);
  edge(west, north, west, south);
  points.add(points.first);
  return points;
}

CircuitPoint _at(double eastM, double northM, {double? accuracyM = 4}) {
  const lat0 = 19.4;
  const lng0 = -99.1;
  const metersPerDegLat = 110540.0;
  final metersPerDegLng = 111320.0 * math.cos(lat0 * math.pi / 180);
  return CircuitPoint(
    lat: lat0 + northM / metersPerDegLat,
    lng: lng0 + eastM / metersPerDegLng,
    accuracyM: accuracyM,
    altitudeM: accuracyM == null ? null : 1800,
  );
}
