import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';

/// Live GPS blue-dot for point-selection maps (camera zones, loop A/B).
///
/// Use [liveGpsMapChild] as a [FlutterMap] child so only the GPS layer rebuilds
/// on ticks — full-map `setState` was freezing pinch-zoom.
mixin LiveGpsMapMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<Position>? _liveGpsSub;
  final ValueNotifier<LatLng?> liveGpsListenable = ValueNotifier<LatLng?>(null);
  bool _centeredOnGpsOnce = false;
  bool _gpsNotifierDisposed = false;

  LatLng? get liveGps => liveGpsListenable.value;

  Future<void> startLiveGps({
    MapController? map,
    bool centerOnce = true,
  }) async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final once = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted || _gpsNotifierDisposed) return;
      final first = LatLng(once.latitude, once.longitude);
      liveGpsListenable.value = first;
      if (centerOnce && !_centeredOnGpsOnce && map != null) {
        _centeredOnGpsOnce = true;
        map.move(first, map.camera.zoom < 14 ? 16 : map.camera.zoom);
      }

      await _liveGpsSub?.cancel();
      _liveGpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        if (!mounted || _gpsNotifierDisposed) return;
        liveGpsListenable.value = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {
      // Maps still work without live GPS.
    }
  }

  Future<void> stopLiveGps() async {
    await _liveGpsSub?.cancel();
    _liveGpsSub = null;
  }

  /// Call from [State.dispose] after [stopLiveGps].
  void disposeLiveGpsListenable() {
    if (_gpsNotifierDisposed) return;
    _gpsNotifierDisposed = true;
    liveGpsListenable.dispose();
  }

  void centerOnLiveGps(MapController map) {
    final p = liveGps;
    if (p == null) return;
    map.move(p, map.camera.zoom < 15 ? 16.5 : map.camera.zoom);
  }

  /// Single map child — rebuilds only when the blue-dot moves.
  Widget liveGpsMapChild() {
    return ListenableBuilder(
      listenable: liveGpsListenable,
      builder: (context, _) {
        final p = liveGps;
        if (p == null) return const SizedBox.shrink();
        return CircleLayer(
          circles: [
            CircleMarker(
              point: p,
              radius: 18,
              color: const Color(0xFF2F80ED).withValues(alpha: 0.18),
              borderColor: const Color(0xFF2F80ED).withValues(alpha: 0.35),
              borderStrokeWidth: 1,
            ),
            CircleMarker(
              point: p,
              radius: 7,
              color: const Color(0xFF2F80ED),
              borderColor: AppTheme.mist,
              borderStrokeWidth: 2.5,
            ),
          ],
        );
      },
    );
  }
}
