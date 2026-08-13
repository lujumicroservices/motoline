import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bikes/bike_catalog.dart';
import '../core/bikes/triumph_catalog.dart';
import 'social_providers.dart';

const _bikePrefKey = 'corneriq_bike_id';

/// Selected garage bike. Local + optional cloud profile sync.
final riderBikeProvider =
    StateNotifierProvider<RiderBikeController, BikeModel?>((ref) {
  final controller = RiderBikeController(ref);
  ref.listen(myProfileProvider, (_, next) {
    next.whenData((profile) {
      final id = profile?.bikeId?.trim();
      if (id != null && id.isNotEmpty) {
        controller.applyFromCloud(id);
      }
    });
  });
  return controller;
});

class RiderBikeController extends StateNotifier<BikeModel?> {
  RiderBikeController(this._ref) : super(null) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await BikeCatalog.load();
    final id = prefs.getString(_bikePrefKey);
    state = BikeCatalog.byId(id);
  }

  void applyFromCloud(String bikeId) {
    final bike = BikeCatalog.byId(bikeId);
    if (bike == null || bike.id == state?.id) return;
    state = bike;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_bikePrefKey, bike.id);
    });
  }

  Future<void> select(BikeModel bike) async {
    state = bike;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bikePrefKey, bike.id);
    try {
      await _ref.read(socialRepositoryProvider).updateBikeId(bike.id);
      _ref.invalidate(myProfileProvider);
    } catch (e) {
      debugPrint('bike cloud sync: $e');
    }
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bikePrefKey);
    try {
      await _ref.read(socialRepositoryProvider).updateBikeId(null);
      _ref.invalidate(myProfileProvider);
    } catch (e) {
      debugPrint('bike clear sync: $e');
    }
  }
}
