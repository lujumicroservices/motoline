import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/theme/ride_viz_palette.dart';

void main() {
  test('speedColor is blue ramp through 300 then red', () {
    final zero = RideVizPalette.speedColor(0);
    final mid = RideVizPalette.speedColor(150);
    final cap = RideVizPalette.speedColor(300);
    final over = RideVizPalette.speedColor(301);

    expect(zero, RideVizPalette.speedBlueLow);
    expect(cap, RideVizPalette.speedBlueHigh);
    expect(mid.b, greaterThan(mid.r));
    expect(over.r, greaterThan(over.b));
  });

  test('leanColor uses cyan left and amber right', () {
    expect(RideVizPalette.leanColor(-20), RideVizPalette.leanLeft);
    expect(RideVizPalette.leanColor(20), RideVizPalette.leanRight);
    expect(RideVizPalette.leanColor(0), isNot(RideVizPalette.leanLeft));
    expect(RideVizPalette.leanColor(0), isNot(RideVizPalette.leanRight));
  });
}
