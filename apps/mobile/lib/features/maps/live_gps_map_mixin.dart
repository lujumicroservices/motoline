import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';

/// Live GPS blue-dot for point-selection maps (camera zones, loop A/B).
mixin LiveGpsMapMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<Position>? _liveGpsSub;
  LatLng? liveGps;
  bool _centeredOnGpsOnce = false;

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
      if (!mounted) return;
      final first = LatLng(once.latitude, once.longitude);
      setState(() => liveGps = first);
      if (centerOnce && !_centeredOnGpsOnce && map != null) {
        _centeredOnGpsOnce = true;
        map.move(first, map.camera.zoom < 14 ? 16 : map.camera.zoom);
      }

      await _liveGpsSub?.cancel();
      _liveGpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => liveGps = LatLng(pos.latitude, pos.longitude));
      });
    } catch (_) {
      // Maps still work without live GPS.
    }
  }

  Future<void> stopLiveGps() async {
    await _liveGpsSub?.cancel();
    _liveGpsSub = null;
  }

  void centerOnLiveGps(MapController map) {
    final p = liveGps;
    if (p == null) return;
    map.move(p, map.camera.zoom < 15 ? 16.5 : map.camera.zoom);
  }

  List<Widget> liveGpsLayers() {
    final p = liveGps;
    if (p == null) return const [];
    return [
      CircleLayer(
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
      ),
    ];
  }
}
