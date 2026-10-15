import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/offroad/pass_channels.dart';
import 'package:motoline/features/offroad/session_model.dart';

void main() {
  final session = TrainingSession.fromJson(
    jsonDecode(
      File('assets/offroad/sessions/2026-10-09_8horas.json').readAsStringSync(),
    ) as Map<String, dynamic>,
  );

  test('every bundled pass carries a trace with aligned columns', () {
    for (final p in session.passes) {
      final t = p.trace!;
      expect(t.length, greaterThan(500), reason: p.id);
      for (final col in [t.t, t.dist, t.lapM, t.kmh, t.longG, t.lean, t.latG, t.alt, t.outsideM]) {
        expect(col.length, t.length, reason: p.id);
      }
      expect(t.sector.length, t.length);
      expect(t.braking.length, t.length);
    }
  });

  test('brake zones point at braking rows of the trace', () {
    for (final p in session.passes) {
      final ranges = passBrakeRanges(p);
      expect(ranges.length, p.brakes.length, reason: p.id);
      for (final (a, b) in ranges) {
        expect(b, greaterThanOrEqualTo(a));
        expect(p.trace!.braking.sublist(a, b + 1), contains(1), reason: p.id);
      }
    }
  });

  test('peak events agree with the pass summary', () {
    for (final p in session.passes) {
      expect(p.event('vmax')!.value, closeTo(p.vmaxKmh, 0.1), reason: p.id);
      expect(p.event('lean_r')!.value, closeTo(p.leanMaxR, 0.1), reason: p.id);
      expect(p.event('lean_l')!.value, closeTo(p.leanMaxL, 0.1), reason: p.id);
      expect(p.event('brake')!.value, closeTo(p.brakePeakG, 0.01), reason: p.id);
      expect(p.event('vmax')!.index, lessThan(p.trace!.length));
    }
  });

  test('braking / throttle scale is symmetric around zero', () {
    final t = session.passes.first.trace!;
    final (lo, hi) = TraceChannel.longG.range(t);
    expect(lo, -hi);
    expect(TraceChannel.speed.range(t).$1, 0);
  });
}
