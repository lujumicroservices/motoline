import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/live_share_loop.dart';

void main() {
  test('retry delay starts at 15s and caps at 60s', () {
    const share = Duration(minutes: 5);
    expect(liveShareRetryDelay(failStreak: 0, shareInterval: share), share);
    expect(
      liveShareRetryDelay(failStreak: 1, shareInterval: share).inSeconds,
      15,
    );
    expect(
      liveShareRetryDelay(failStreak: 2, shareInterval: share).inSeconds,
      30,
    );
    expect(
      liveShareRetryDelay(failStreak: 3, shareInterval: share).inSeconds,
      60,
    );
    expect(
      liveShareRetryDelay(failStreak: 8, shareInterval: share).inSeconds,
      60,
    );
  });

  test('catalog fetch failure keeps current share sessions', () {
    expect(
      nextLiveShareIds(fetchedWantShare: null, currentSessionIds: {'a', 'b'}),
      {'a', 'b'},
    );
  });

  test('successful catalog replaces share sessions', () {
    expect(
      nextLiveShareIds(fetchedWantShare: {'b'}, currentSessionIds: {'a', 'b'}),
      {'b'},
    );
  });
}
