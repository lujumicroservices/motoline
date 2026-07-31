import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/ride_database.dart';
import '../core/models/ride.dart';
import '../core/models/track_point.dart';
import '../core/services/loop_session_controller.dart';
import '../core/services/ride_recorder.dart';
import '../core/services/ride_sync_service.dart';

final rideDatabaseProvider = Provider<RideDatabase>((ref) {
  return RideDatabase.instance;
});

final rideSyncServiceProvider = Provider<RideSyncService>((ref) {
  return RideSyncService(database: ref.watch(rideDatabaseProvider));
});

final rideRecorderProvider = Provider<RideRecorder>((ref) {
  final recorder = RideRecorder(database: ref.watch(rideDatabaseProvider));
  ref.onDispose(recorder.dispose);
  return recorder;
});

final ridesListProvider = FutureProvider.autoDispose<List<Ride>>((ref) async {
  // Pull owned cloud rides into SQLite so Garage shows recovered / moved data.
  try {
    await ref.read(rideSyncServiceProvider).pullMyCloudRides();
  } catch (_) {}
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

final ridesForRouteProvider =
    FutureProvider.autoDispose.family<List<Ride>, String>((ref, routeId) {
  return ref.watch(rideDatabaseProvider).listRidesForRoute(routeId);
});

final activeRideProvider = StreamProvider.autoDispose<ActiveRideSnapshot?>((ref) {
  final recorder = ref.watch(rideRecorderProvider);
  return recorder.snapshots.map<ActiveRideSnapshot?>((s) => s);
});

final incompleteRideProvider = FutureProvider.autoDispose<Ride?>((ref) {
  return ref.watch(rideDatabaseProvider).getActiveRide();
});

/// Fires whenever arm+auto-start fires — UI listens (via `ref.listen`) to
/// navigate to the active ride screen.
final autoStartEventsProvider = StreamProvider.autoDispose<Ride>((ref) {
  final recorder = ref.watch(rideRecorderProvider);
  return recorder.autoStartEvents;
});

/// Wraps [RideRecorder.armForAutoStart] / [RideRecorder.disarm] so the UI can
/// toggle + observe the "waiting for motion…" armed state reactively.
class ArmedStateNotifier extends StateNotifier<bool> {
  ArmedStateNotifier(this._recorder) : super(_recorder.isArmed) {
    _sub = _recorder.armedStates.listen((armed) => state = armed);
  }

  final RideRecorder _recorder;
  late final StreamSubscription<bool> _sub;

  Future<void> arm({String? routeId}) =>
      _recorder.armForAutoStart(routeId: routeId);

  void disarm() => _recorder.disarm();

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

final armedStateProvider =
    StateNotifierProvider.autoDispose<ArmedStateNotifier, bool>((ref) {
  final recorder = ref.watch(rideRecorderProvider);
  return ArmedStateNotifier(recorder);
});

final loopSessionControllerProvider =
    Provider.autoDispose<LoopSessionController>((ref) {
  final controller = LoopSessionController(
    recorder: ref.watch(rideRecorderProvider),
    database: ref.watch(rideDatabaseProvider),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

final loopSessionStateProvider =
    StreamProvider.autoDispose<LoopSessionState>((ref) {
  final controller = ref.watch(loopSessionControllerProvider);
  return controller.states;
});
