import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/watch/watch_models.dart';

WatchSession _session({required String status, String? localRideId}) {
  return WatchSession(
    id: 's1',
    riderId: 'r1',
    status: status,
    startedAt: DateTime.utc(2026, 9, 10),
    localRideId: localRideId,
  );
}

void main() {
  test('familyWatchIsLive is true only for an active session', () {
    expect(familyWatchIsLive(null), isFalse);
    expect(
      familyWatchIsLive(_session(status: 'ended', localRideId: 'ride-a')),
      isFalse,
    );
    expect(
      familyWatchIsLive(_session(status: 'active', localRideId: 'ride-a')),
      isTrue,
    );
    expect(
      familyWatchIsLive(_session(status: 'active', localRideId: 'rodada:abc')),
      isTrue,
    );
  });
}
