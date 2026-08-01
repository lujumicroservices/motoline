import '../../../core/utils/geo_utils.dart';
import 'models/camera_zone.dart';

/// Emits start/stop when the rider *enters* a camera geofence (edge-triggered).
class CameraZoneDetector {
  CameraZoneDetector({List<CameraZone> zones = const []}) : _zones = zones;

  List<CameraZone> _zones;
  final Set<String> _inside = {};

  List<CameraZone> get zones => List.unmodifiable(_zones);

  void setZones(List<CameraZone> zones) {
    _zones = List.of(zones);
    _inside.removeWhere((id) => !_zones.any((z) => z.id == id));
  }

  void reset() => _inside.clear();

  /// Returns the highest-priority action on this sample (stop > start), or null.
  CameraZoneAction? feed({
    required double latitude,
    required double longitude,
  }) {
    CameraZoneAction? fired;
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
        // Prefer stop if both fire in the same sample.
        if (fired == null || zone.action == CameraZoneAction.stop) {
          fired = zone.action;
        }
      } else if (!inside && wasInside) {
        _inside.remove(zone.id);
      }
    }
    return fired;
  }
}
