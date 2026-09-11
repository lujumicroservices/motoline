import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/rodadas/rodada_repository.dart';

const kShareAutoArmPref = 'rodada_share_auto_arm';
const kShareLivePref = 'rodada_share_live';
const kShareFamilyPref = 'rodada_share_family';
const kShareTrackPref = 'rodada_share_track';

class RodadaShareSettings {
  const RodadaShareSettings({
    this.autoArmOnStart = false,
    this.shareLive = false,
    this.autoShareFamily = false,
    this.shareTrack = false,
  });

  final bool autoArmOnStart;
  final bool shareLive;
  final bool autoShareFamily;
  final bool shareTrack;

  RodadaShareSettings copyWith({
    bool? autoArmOnStart,
    bool? shareLive,
    bool? autoShareFamily,
    bool? shareTrack,
  }) {
    return RodadaShareSettings(
      autoArmOnStart: autoArmOnStart ?? this.autoArmOnStart,
      shareLive: shareLive ?? this.shareLive,
      autoShareFamily: autoShareFamily ?? this.autoShareFamily,
      shareTrack: shareTrack ?? this.shareTrack,
    );
  }
}

class RodadaSharePrefs extends StateNotifier<RodadaShareSettings> {
  RodadaSharePrefs() : super(const RodadaShareSettings()) {
    _loaded = _load();
  }

  late final Future<void> _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = RodadaShareSettings(
      autoArmOnStart: prefs.getBool(kShareAutoArmPref) ?? false,
      shareLive: prefs.getBool(kShareLivePref) ?? false,
      autoShareFamily: prefs.getBool(kShareFamilyPref) ?? false,
      shareTrack: prefs.getBool(kShareTrackPref) ?? false,
    );
  }

  Future<void> _persist() async {
    await _loaded;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kShareAutoArmPref, state.autoArmOnStart);
    await prefs.setBool(kShareLivePref, state.shareLive);
    await prefs.setBool(kShareFamilyPref, state.autoShareFamily);
    await prefs.setBool(kShareTrackPref, state.shareTrack);
  }

  Future<void> setAutoArmOnStart(bool value) async {
    await _loaded;
    state = state.copyWith(autoArmOnStart: value);
    await _persist();
  }

  Future<void> setShareLive(bool value) async {
    await _loaded;
    state = state.copyWith(shareLive: value);
    await _persist();
  }

  Future<void> setAutoShareFamily(bool value) async {
    await _loaded;
    state = state.copyWith(autoShareFamily: value);
    await _persist();
  }

  Future<void> setShareTrack(bool value) async {
    await _loaded;
    state = state.copyWith(shareTrack: value);
    await _persist();
  }
}

final rodadaSharePrefsProvider =
    StateNotifierProvider<RodadaSharePrefs, RodadaShareSettings>(
      (ref) => RodadaSharePrefs(),
    );

Future<void> applyShareSettingsToMembership({
  required RodadaRepository repo,
  required String rodadaId,
  required RodadaShareSettings settings,
}) {
  return repo.updateMySharing(
    rodadaId: rodadaId,
    shareLive: settings.shareLive,
    shareTrack: settings.shareTrack,
    autoArmOnStart: settings.autoArmOnStart,
    autoShareFamily: settings.autoShareFamily,
  );
}

Future<void> syncShareSettingsToOpenRodadas({
  required RodadaRepository repo,
  required RodadaShareSettings settings,
}) async {
  final mine = await repo.listMyRodadas(limit: 40);
  for (final r in mine) {
    if (r.status == 'ended') continue;
    try {
      await applyShareSettingsToMembership(
        repo: repo,
        rodadaId: r.id,
        settings: settings,
      );
    } catch (_) {}
  }
}
