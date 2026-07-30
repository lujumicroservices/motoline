import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/ride_database.dart';
import '../core/models/ride.dart';
import '../core/models/track_point.dart';
import '../core/services/ride_recorder.dart';

final rideDatabaseProvider = Provider<RideDatabase>((ref) {
  return RideDatabase.instance;
});

final rideRecorderProvider = Provider<RideRecorder>((ref) {
  final recorder = RideRecorder(database: ref.watch(rideDatabaseProvider));
  ref.onDispose(recorder.dispose);
  return recorder;
});

final ridesListProvider = FutureProvider.autoDispose<List<Ride>>((ref) async {
  return ref.watch(rideDatabaseProvider).listRides();
});

final rideProvider =
    FutureProvider.autoDispose.family<Ride?, String>((ref, id) async {
  return ref.watch(rideDatabaseProvider).getRide(id);
});

final ridePointsProvider =
    FutureProvider.autoDispose.family<List<TrackPoint>, String>((ref, id) {
  return ref.watch(rideDatabaseProvider).getPoints(id);
});

final activeRideProvider = StreamProvider.autoDispose<ActiveRideSnapshot?>((ref) {
  final recorder = ref.watch(rideRecorderProvider);
  return recorder.snapshots.map<ActiveRideSnapshot?>((s) => s);
});

final incompleteRideProvider = FutureProvider.autoDispose<Ride?>((ref) {
  return ref.watch(rideDatabaseProvider).getActiveRide();
});
