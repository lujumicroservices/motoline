import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/theme/ride_viz_palette.dart';

void main() {
  test('speedColor goes clear pale red to dark red with speed', () {
    final zero = RideVizPalette.speedColor(0);
    final mid = RideVizPalette.speedColor(150);
    final cap = RideVizPalette.speedColor(300);
    final over = RideVizPalette.speedColor(400);

    expect(zero.toARGB32(), RideVizPalette.speedClear.toARGB32());
    expect(cap.toARGB32(), RideVizPalette.speedDark.toARGB32());
    expect(over.toARGB32(), RideVizPalette.speedDark.toARGB32());

    // Darker = lower luminance as speed rises.
    expect(_luma(mid), lessThan(_luma(zero)));
    expect(_luma(cap), lessThan(_luma(mid)));
  });

  test('leanColor uses cyan left and amber right', () {
    expect(RideVizPalette.leanColor(-20), RideVizPalette.leanLeft);
    expect(RideVizPalette.leanColor(20), RideVizPalette.leanRight);
    expect(RideVizPalette.leanColor(0), isNot(RideVizPalette.leanLeft));
    expect(RideVizPalette.leanColor(0), isNot(RideVizPalette.leanRight));
  });
}

double _luma(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
