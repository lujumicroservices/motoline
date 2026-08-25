import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/ride_analytics.dart';
import '../core/analytics/ride_lab_isolate.dart';
import '../core/db/ride_database.dart';
import '../core/lean_lab/lean_lab_service.dart';
import '../core/models/lean_sample.dart';
import '../core/models/ride.dart';
import '../core/models/track_point.dart';
import '../core/services/loop_session_controller.dart';
import '../core/services/imu_blob_upload_service.dart';
import '../core/services/ride_place_name_service.dart';
import '../core/services/ride_recorder.dart';
import '../core/services/ride_sync_service.dart';
import '../core/services/sync_outbox_service.dart';
import '../core/supabase/supabase_bootstrap.dart';
import 'pro_entitlement_provider.dart';


final rideDatabaseProvider = Provider<RideDatabase>((ref) {
  return RideDatabase.instance;
});

final imuBlobUploadServiceProvider = Provider<ImuBlobUploadService>((ref) {
  return ImuBlobUploadService(database: ref.watch(rideDatabaseProvider));
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
  final recorder = RideRecorder(
    database: ref.watch(rideDatabaseProvider),
    onRideCompleted: (_) {
      unawaited(ref.read(proEntitlementProvider.notifier).onRideCompleted());
    },
  );
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// True while home is filling ride summaries from the cloud in the background.
class GarageCloudSyncNotifier extends StateNotifier<bool> {
  GarageCloudSyncNotifier(this._ref) : super(false);

  final Ref _ref;
  Future<void>? _running;
  DateTime? _lastAt;
  String? _lastUser;

  /// Pull ride summaries (and GPS only for empty local tracks) without
  /// blocking the garage list. Safe to call after leaving/returning home.
  Future<void> ensureStarted({bool force = false}) async {
    final existing = _running;
    if (existing != null) {
      if (force) await existing;
      return;
    }
    final uid = SupabaseBootstrap.permanentUserId;
    if (!force &&
        uid != null &&
        uid == _lastUser &&
        _lastAt != null &&
        DateTime.now().difference(_lastAt!) < const Duration(seconds: 20)) {
      return;
    }
    await _startPull(invalidateAlways: force);
  }

  /// Pull-to-refresh: re-read SQLite immediately, then force a cloud pull.
  Future<void> refresh() async {
    _ref.invalidate(ridesListProvider);
    final existing = _running;
    if (existing != null) {
      await existing;
      _ref.invalidate(ridesListProvider);
      return;
    }
    await _startPull(invalidateAlways: true);
  }

  Future<void> _startPull({required bool invalidateAlways}) {
    final future = _doPull(invalidateAlways: invalidateAlways);
    _running = future;
    return future;
  }

  Future<void> _doPull({required bool invalidateAlways}) async {
    final uid = SupabaseBootstrap.permanentUserId;
    state = true;
    try {
      await _ref.read(rideSyncServiceProvider).pullMyCloudRides(
            policy: TrackPullPolicy.fillGapsOnly,
            tracksOnlyIfLocalEmpty: true,
            afterSummaries: (changed) {
              state = false;
              if (changed > 0 || invalidateAlways) {
                _ref.invalidate(ridesListProvider);
              }
              unawaited(() async {
                try {
                  await LeanLabService.instance.pullMyCloudSessions();
                } catch (_) {}
              }());
            },
          );
      if (invalidateAlways) {
        _ref.invalidate(ridesListProvider);
      }
    } catch (_) {
    } finally {
      _running = null;
      _lastAt = DateTime.now();
      _lastUser = uid;
      state = false;
    }
  }
}

final garageCloudSyncProvider =
    StateNotifierProvider<GarageCloudSyncNotifier, bool>((ref) {
  return GarageCloudSyncNotifier(ref);
});

final ridesListProvider = FutureProvider<List<Ride>>((ref) async {
  final db = ref.watch(rideDatabaseProvider);
  final rides = await db.listRides();
  unawaited(ref.read(garageCloudSyncProvider.notifier).ensureStarted());
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

/// Download GPS for this ride if local SQLite has none (recovered ride).
final rideTrackReadyProvider =
    FutureProvider.autoDispose.family<void, String>((ref, id) async {
  final db = ref.watch(rideDatabaseProvider);
  if (await db.countPoints(id) > 0) return;
  try {
    await ref.read(rideSyncServiceProvider).pullTrackIfLocalEmpty(id);
  } catch (_) {}
});

/// Full GPS — sync, export, reel, compare. Not used to open Ride Lab.
final ridePointsProvider =
    FutureProvider.autoDispose.family<List<TrackPoint>, String>((ref, id) async {
  await ref.watch(rideTrackReadyProvider(id).future);
  return ref.watch(rideDatabaseProvider).getPoints(id);
});

/// ~1k GPS vertices for map + charts (includes first/last).
final rideOverviewPointsProvider =
    FutureProvider.autoDispose.family<List<TrackPoint>, String>((ref, id) async {
  await ref.watch(rideTrackReadyProvider(id).future);
  return ref.watch(rideDatabaseProvider).getPointsOverview(id);
});

final rideLeanSamplesProvider =
    FutureProvider.autoDispose.family<List<LeanSample>, String>((ref, id) {
  return ref.watch(rideDatabaseProvider).getLeanSamples(id);
});

/// Full-track curves / skill; loads in a background isolate.
final rideLabAnalyticsProvider =
    FutureProvider.autoDispose.family<RideAnalytics?, String>((ref, id) async {
  await ref.watch(rideTrackReadyProvider(id).future);
  final db = ref.watch(rideDatabaseProvider);
  final ride = await db.getRide(id);
  if (ride == null) return null;
  final points = await db.getPoints(id);
  final lean = await db.getLeanSamples(id);
  return computeRideLabAnalytics(
    ride: ride,
    points: points,
    leanSamples: lean,
  );
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
