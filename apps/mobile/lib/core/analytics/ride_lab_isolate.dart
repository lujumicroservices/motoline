import 'dart:isolate';

import 'ride_analytics.dart';
import 'map_curve_engine.dart';
import '../models/lean_sample.dart';
import '../models/ride.dart';
import '../models/track_point.dart';

/// Heavy curve / skill pass off the UI isolate.
Future<RideAnalytics> computeRideLabAnalytics({
  required Ride ride,
  required List<TrackPoint> points,
  List<LeanSample> leanSamples = const [],
  List<GeoPoint>? matchedCenterline,
}) {
  return Isolate.run(() {
    return RideAnalytics(
      ride: ride,
      points: points,
      leanSamples: leanSamples,
      matchedCenterline: matchedCenterline,
    );
  });
}
