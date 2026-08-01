import '../../../core/utils/geo_utils.dart';
import 'models/camera_zone.dart';

/// Result of entering a camera geofence.
class CameraZoneHit {
  const CameraZoneHit({
    required this.action,
    required this.zoneId,
    this.partnerId,
  });

  final CameraZoneAction action;
  final String zoneId;
  final String? partnerId;
}

/// Emits start/stop when the rider *enters* a camera geofence (edge-triggered).
///
/// Stops only fire when their linked Start partner was entered earlier in the
/// ride (pair-armed). Unpaired stops are ignored.
class CameraZoneDetector {
  CameraZoneDetector({List<CameraZone> zones = const []}) {
    setZones(zones);
  }

  List<CameraZone> _zones = const [];
  final Set<String> _inside = {};
  /// Start zone ids whose partner Stop is now allowed.
  final Set<String> _armedStarts = {};

  List<CameraZone> get zones => List.unmodifiable(_zones);

  void setZones(List<CameraZone> zones) {
    _zones = pairOrphanCameraZones(zones);
    final ids = _zones.map((z) => z.id).toSet();
    _inside.removeWhere((id) => !ids.contains(id));
    _armedStarts.removeWhere((id) => !ids.contains(id));
  }

  void reset() {
    _inside.clear();
    _armedStarts.clear();
  }

  /// Highest-priority hit this sample (stop > start), or null.
  CameraZoneHit? feed({
    required double latitude,
    required double longitude,
  }) {
    CameraZoneHit? fired;
    for (final zone in _zones) {
      final inside = inGeofence(
        latitude,
        longitude,
        zone.latitude,
        zone.longitude,
        zone.radiusMeters,
      );
      final wasInside = _inside.contains(zone.id);
      if (inside && !wasInside) {
        _inside.add(zone.id);
        final hit = _onEnter(zone);
        if (hit == null) continue;
        if (fired == null || hit.action == CameraZoneAction.stop) {
          fired = hit;
        }
      } else if (!inside && wasInside) {
        _inside.remove(zone.id);
      }
    }
    return fired;
  }

  CameraZoneHit? _onEnter(CameraZone zone) {
    if (zone.action == CameraZoneAction.start) {
      _armedStarts.add(zone.id);
      return CameraZoneHit(
        action: CameraZoneAction.start,
        zoneId: zone.id,
        partnerId: zone.partnerId,
      );
    }

    // Stop: only if its partner Start was armed.
    final startId = zone.partnerId;
    if (startId == null || startId.isEmpty) return null;
    if (!_armedStarts.contains(startId)) return null;

    _armedStarts.remove(startId);
    return CameraZoneHit(
      action: CameraZoneAction.stop,
      zoneId: zone.id,
      partnerId: startId,
    );
  }
}
