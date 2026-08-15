import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/ride_database.dart';
import '../core/lean_lab/lean_lab_service.dart';
import '../core/models/lean_sample.dart';
import '../core/models/ride.dart';
import '../core/models/track_point.dart';
import '../core/services/loop_session_controller.dart';
import '../core/services/ride_place_name_service.dart';
import '../core/services/ride_recorder.dart';
import '../core/services/ride_sync_service.dart';
import '../core/services/sync_outbox_service.dart';


final rideDatabaseProvider = Provider<RideDatabase>((ref) {
  return RideDatabase.instance;
});

final rideSyncServiceProvider = Provider<RideSyncService>((ref) {
  return RideSyncService(database: ref.watch(rideDatabaseProvider));
});

final syncOutboxServiceProvider = Provider<SyncOutboxService>((ref) {
  return SyncOutboxService(
    database: ref.watch(rideDatabaseProvider),
    sync: ref.watch(rideSyncServiceProvider),
  );
});

/// Enqueue + drain outbox (soft-fail). Prefer this after ride complete.
Future<void> enqueueAndDrainRideSync(
  SyncOutboxService outbox,
  String rideLocalId,
) async {
  await outbox.enqueueRideUpload(rideLocalId);
  await outbox.drain();
}

final rideRecorderProvider = Provider<RideRecorder>((ref) {
  final recorder = RideRecorder(database: ref.watch(rideDatabaseProvider));
  ref.onDispose(recorder.dispose);
  return recorder;
});

final ridesListProvider = FutureProvider.autoDispose<List<Ride>>((ref) async {
  // Soft cloud fill: never wipe local GPS/lean just by opening Garage.
  try {
    await ref.read(rideSyncServiceProvider).pullMyCloudRides(
          policy: TrackPullPolicy.fillGapsOnly,
        );
  } catch (_) {}
  try {
    await LeanLabService.instance.pullMyCloudSessions();
  } catch (_) {}
  final db = ref.watch(rideDatabaseProvider);
  final rides = await db.listRides();
  // Soft backfill start→end place titles; refresh list when any are written.
  unawaited(() async {
    final named = await nameUntitledRides(
      db,
      rides,
      limit: 8,
    );
    if (named > 0) {
      ref.invalidateSelf();
    }
  }());
  return rides;
});

/// Progress while naming rides from GPS start/end places.
class RideTitleNamingState {
  const RideTitleNamingState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.lastTitle,
  });

  final bool running;
  final int done;
  final int total;
  final String? lastTitle;

  RideTitleNamingState copyWith({
    bool? running,
    int? done,
    int? total,
    String? lastTitle,
    bool clearLast = false,
  }) {
    return RideTitleNamingState(
      running: running ?? this.running,
      done: done ?? this.done,
      total: total ?? this.total,
      lastTitle: clearLast ? null : (lastTitle ?? this.lastTitle),
    );
  }
}

class RideTitleNamingController extends StateNotifier<RideTitleNamingState> {
  RideTitleNamingController(this._ref) : super(const RideTitleNamingState());

  final Ref _ref;
  bool _busy = false;

  /// Name every untitled completed ride (start place - end place).
  Future<int> nameAll({int limit = 40}) async {
    if (_busy) return 0;
    _busy = true;
    state = const RideTitleNamingState(running: true);
    try {
      final db = _ref.read(rideDatabaseProvider);
      final rides = await db.listRides();
      final named = await nameUntitledRides(
        db,
        rides,
        limit: limit,
        onProgress: (done, total, title) {
          state = RideTitleNamingState(
            running: true,
            done: done,
            total: total,
            lastTitle: title,
          );
        },
      );
      if (named > 0) {
        _ref.invalidate(ridesListProvider);
      }
      return named;
    } finally {
      _busy = false;
      state = state.copyWith(running: false);
    }
  }
}

final rideTitleNamingProvider =
    StateNotifierProvider<RideTitleNamingController, RideTitleNamingState>(
  (ref) => RideTitleNamingController(ref),
);

/// Reverse-geocode start/end for untitled completed rides.
/// Returns how many titles were written.
Future<int> nameUntitledRides(
  RideDatabase db,
  List<Ride> rides, {
  int limit = 8,
  void Function(int done, int total, String? title)? onProgress,
}) async {
  final pending = rides
      .where(
        (r) =>
            r.status == RideStatus.completed &&
            (r.title == null || r.title!.trim().isEmpty) &&
            r.pointCount >= 2,
      )
      .take(limit)
      .toList();
  if (pending.isEmpty) return 0;
  final namer = RidePlaceNameService();
  var named = 0;
  for (var i = 0; i < pending.length; i++) {
    final ride = pending[i];
    String? title;
    try {
      final points = await db.getPoints(ride.id);
      title = await namer.titleFromTrack(points);
      if (title != null && title.trim().isNotEmpty) {
        await db.upsertRide(ride.copyWith(title: title.trim()));
        named++;
      }
    } catch (_) {}
    onProgress?.call(i + 1, pending.length, title);
  }
  return named;
}

final rideProvider =
    FutureProvider.autoDispose.family<Ride?, String>((ref, id) async {
  return ref.watch(rideDatabaseProvider).getRide(id);
});

final ridePointsProvider =
    FutureProvider.autoDispose.family<List<TrackPoint>, String>((ref, id) {
  return ref.watch(rideDatabaseProvider).getPoints(id);
});

final rideLeanSamplesProvider =
    FutureProvider.autoDispose.family<List<LeanSample>, String>((ref, id) {
  return ref.watch(rideDatabaseProvider).getLeanSamples(id);
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
