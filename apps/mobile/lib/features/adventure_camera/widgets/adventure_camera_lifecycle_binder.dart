import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ride.dart';
import '../../../providers/ride_providers.dart';
import '../providers/adventure_camera_providers.dart';

/// Soft bridge: watches ride recording / pause without modifying [RideRecorder].
///
/// Mount once under the app shell (e.g. [HomeScreen]).
class AdventureCameraLifecycleBinder extends ConsumerStatefulWidget {
  const AdventureCameraLifecycleBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdventureCameraLifecycleBinder> createState() =>
      _AdventureCameraLifecycleBinderState();
}

class _AdventureCameraLifecycleBinderState
    extends ConsumerState<AdventureCameraLifecycleBinder> {
  bool _wasRecording = false;
  bool _wasPaused = false;
  DateTime? _lastSampleAt;

  @override
  Widget build(BuildContext context) {
    // Ensure hub prefs load.
    ref.watch(adventureCameraHydratedProvider);

    ref.listen(activeRideProvider, (previous, next) {
      final snap = next.asData?.value;
      final recording = snap != null &&
          snap.ride.status == RideStatus.recording;
      final paused = snap?.isPaused ?? false;

      final hub = ref.read(adventureCameraHubProvider);
      if (!_wasRecording && recording) {
        unawaited(hub.onRideStarted(rideLocalId: snap!.ride.id));
      } else if (_wasRecording && !recording) {
        unawaited(hub.onRideStopped());
      } else if (recording && !_wasPaused && paused) {
        unawaited(hub.onRidePaused());
      } else if (recording && _wasPaused && !paused) {
        unawaited(hub.onRideResumed());
      }

      // Mid-ride GPS / lean → map zones + aggressive auto-record.
      final live = snap;
      if (recording && !paused && live != null) {
        final point = live.lastPoint;
        if (point != null) {
          final ts = point.timestamp;
          // Deduplicate identical snapshot timestamps from stream churn.
          if (_lastSampleAt == null || ts.isAfter(_lastSampleAt!)) {
            _lastSampleAt = ts;
            unawaited(
              hub.onLiveSample(
                latitude: point.latitude,
                longitude: point.longitude,
                leanDegrees: live.relativeLeanDegrees ?? point.leanDegrees,
                speedKmh: point.speedKmh,
                timestamp: ts,
              ),
            );
          }
        }
      } else if (!recording) {
        _lastSampleAt = null;
      }

      _wasRecording = recording;
      _wasPaused = paused;
    });

    return widget.child;
  }
}
