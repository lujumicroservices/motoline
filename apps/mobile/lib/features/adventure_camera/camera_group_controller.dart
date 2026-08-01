import 'dart:async';

import 'package:flutter/foundation.dart';

import 'camera_controller.dart';
import 'models/adventure_camera_status.dart';
import 'models/camera_member.dart';

/// Fans shutter commands out to several [AdventureCameraController]s.
///
/// Soft-fails per member: one camera error does not block the others.
class CameraGroupController implements AdventureCameraController {
  CameraGroupController({
    required List<CameraMember> members,
    required AdventureCameraController Function(CameraMember member) factory,
  })  : _members = List.of(members),
        _factory = factory,
        _statusController =
            StreamController<AdventureCameraStatus>.broadcast() {
    _rebuildSlots();
    _emitAggregate();
  }

  final AdventureCameraController Function(CameraMember member) _factory;
  final StreamController<AdventureCameraStatus> _statusController;

  List<CameraMember> _members;
  final Map<String, AdventureCameraController> _slots = {};
  final Map<String, StreamSubscription<AdventureCameraStatus>> _subs = {};
  AdventureCameraStatus _status = const AdventureCameraStatus(
    phase: AdventureCameraPhase.idle,
  );

  List<CameraMember> get members => List.unmodifiable(_members);

  List<CameraMember> get enabledMembers =>
      _members.where((m) => m.enabled).toList(growable: false);

  @override
  String get backendId => 'camera_group';

  @override
  Stream<AdventureCameraStatus> get statusStream => _statusController.stream;

  @override
  AdventureCameraStatus get status => _status;

  /// Replace the group roster (creates/disposes per-member controllers).
  Future<void> setMembers(List<CameraMember> members) async {
    _members = List.of(members);
    await _rebuildSlots();
    _emitAggregate();
  }

  Future<void> _rebuildSlots() async {
    final keep = enabledMembers.map((m) => m.id).toSet();
    final drop = _slots.keys.where((id) => !keep.contains(id)).toList();
    for (final id in drop) {
      await _subs.remove(id)?.cancel();
      try {
        await _slots.remove(id)?.dispose();
      } catch (_) {}
    }
    for (final member in enabledMembers) {
      if (_slots.containsKey(member.id)) continue;
      final c = _factory(member);
      _slots[member.id] = c;
      _subs[member.id] = c.statusStream.listen((_) => _emitAggregate());
    }
  }

  @override
  Future<void> ensurePermissions() async {
    for (final c in _slots.values) {
      await c.ensurePermissions();
    }
  }

  @override
  Future<void> connect({String? preferredDeviceId}) async {
    if (enabledMembers.isEmpty) {
      _emit(
        const AdventureCameraStatus(
          phase: AdventureCameraPhase.error,
          message: 'Camera group is empty — add a GoPro in Settings → Lab',
          memberCount: 0,
        ),
      );
      return;
    }

    _emit(
      AdventureCameraStatus(
        phase: AdventureCameraPhase.connecting,
        deviceName: _groupLabel(),
        message: 'Connecting ${enabledMembers.length} cameras…',
        memberCount: enabledMembers.length,
      ),
    );

    // Sequential connects are more reliable on Android BLE stacks.
    for (final member in enabledMembers) {
      final c = _slots[member.id];
      if (c == null) continue;
      try {
        await c.connect(preferredDeviceId: member.remoteId);
      } catch (e) {
        debugPrint('CameraGroup connect ${member.displayName}: $e');
      }
    }
    _emitAggregate();
  }

  @override
  Future<void> disconnect() async {
    await Future.wait([
      for (final c in _slots.values) c.disconnect(),
    ]);
    _emitAggregate();
  }

  @override
  Future<void> startRecording() async {
    final ready = _slots.entries
        .where((e) => e.value.status.isReady)
        .toList(growable: false);
    if (ready.isEmpty) {
      _emitAggregate();
      return;
    }
    await Future.wait([
      for (final e in ready) e.value.startRecording(),
    ]);
    _emitAggregate();
  }

  @override
  Future<void> stopRecording() async {
    await Future.wait([
      for (final c in _slots.values)
        if (c.status.isReady || c.status.isRecording) c.stopRecording(),
    ]);
    _emitAggregate();
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subs.values) {
      await sub.cancel();
    }
    _subs.clear();
    for (final c in _slots.values) {
      try {
        await c.dispose();
      } catch (_) {}
    }
    _slots.clear();
    await _statusController.close();
  }

  String _groupLabel() {
    final enabled = enabledMembers;
    if (enabled.isEmpty) return 'No cameras';
    if (enabled.length == 1) return enabled.first.displayName;
    if (enabled.length == 2) {
      return '${enabled[0].displayName} + ${enabled[1].displayName}';
    }
    return '${enabled.length} cameras';
  }

  void _emitAggregate() {
    final enabled = enabledMembers;
    if (enabled.isEmpty) {
      _emit(
        const AdventureCameraStatus(
          phase: AdventureCameraPhase.idle,
          message: 'Add cameras to the group',
          memberCount: 0,
          readyCount: 0,
          recordingCount: 0,
        ),
      );
      return;
    }

    var ready = 0;
    var recording = 0;
    var connecting = 0;
    var scanning = 0;
    var errors = 0;
    String? lastError;

    for (final member in enabled) {
      final c = _slots[member.id];
      final phase = c?.status.phase ?? AdventureCameraPhase.idle;
      switch (phase) {
        case AdventureCameraPhase.recording:
          recording++;
          ready++;
        case AdventureCameraPhase.ready:
          ready++;
        case AdventureCameraPhase.connecting:
          connecting++;
        case AdventureCameraPhase.scanning:
          scanning++;
        case AdventureCameraPhase.error:
          errors++;
          lastError = c?.status.message;
        case AdventureCameraPhase.idle:
        case AdventureCameraPhase.disabled:
          break;
      }
    }

    final AdventureCameraPhase phase;
    final String message;
    if (recording > 0) {
      phase = AdventureCameraPhase.recording;
      message = recording == enabled.length
          ? 'All $recording cameras recording'
          : '$recording/${enabled.length} cameras recording';
    } else if (connecting > 0 || scanning > 0) {
      phase = connecting > 0
          ? AdventureCameraPhase.connecting
          : AdventureCameraPhase.scanning;
      message = 'Linking cameras…';
    } else if (ready > 0) {
      phase = AdventureCameraPhase.ready;
      message = ready == enabled.length
          ? 'All $ready cameras ready'
          : '$ready/${enabled.length} cameras ready'
              '${errors > 0 ? ' · $errors failed' : ''}';
    } else if (errors > 0) {
      phase = AdventureCameraPhase.error;
      message = lastError ?? '$errors camera(s) failed';
    } else {
      phase = AdventureCameraPhase.idle;
      message = 'Group idle — connect cameras';
    }

    _emit(
      AdventureCameraStatus(
        phase: phase,
        deviceName: _groupLabel(),
        message: message,
        memberCount: enabled.length,
        readyCount: ready,
        recordingCount: recording,
      ),
    );
  }

  void _emit(AdventureCameraStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}
