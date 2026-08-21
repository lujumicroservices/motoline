import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/ride_stretch.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/features/ride_active/armed_session_nav.dart';

TrackPoint _pt(int id, DateTime t, {double lat = 0, double lng = 0}) {
  return TrackPoint(
    id: id,
    rideId: 'r',
    latitude: lat,
    longitude: lng,
    timestamp: t,
  );
}

void main() {
  group('rideStretchesFrom', () {
    test('empty track has no stretches', () {
      expect(rideStretchesFrom(const []), isEmpty);
    });

    test('auto-pause gap becomes a second stretch', () {
      final base = DateTime(2026, 8, 20, 12);
      final points = [
        _pt(1, base, lat: 0, lng: 0),
        _pt(2, base.add(const Duration(seconds: 2)), lat: 0.001, lng: 0),
        _pt(3, base.add(const Duration(seconds: 40)), lat: 0.002, lng: 0),
        _pt(4, base.add(const Duration(seconds: 42)), lat: 0.003, lng: 0),
      ];
      final stretches = rideStretchesFrom(points);
      expect(stretches.length, 2);
      expect(stretches.first.index, 1);
      expect(stretches.first.pointCount, 2);
      expect(stretches.last.index, 2);
      expect(stretches.last.pointCount, 2);
      expect(stretches.first.distanceMeters, greaterThan(100));
      expect(stretches.first.duration, const Duration(seconds: 2));
    });
  });

  group('armed session nav', () {
    test('minimize keeps recording: do not auto-reopen HUD', () {
      const afterMinimize = ArmedSessionNavState(
        hubOnStack: true,
        hudOnStack: false,
        hudMinimized: true,
      );
      expect(
        shouldAutoPushHud(afterMinimize, isRecording: true),
        isFalse,
      );
    });

    test('first auto-start opens HUD while recording', () {
      const waitingOnHub = ArmedSessionNavState(
        hubOnStack: true,
      );
      expect(
        shouldAutoPushHud(waitingOnHub, isRecording: true),
        isTrue,
      );
    });

    test('HUD already showing is not pushed again', () {
      const onHud = ArmedSessionNavState(
        hubOnStack: true,
        hudOnStack: true,
      );
      expect(shouldAutoPushHud(onHud, isRecording: true), isFalse);
    });

    test('Home resumes hub when recording and hub was popped', () {
      expect(
        shouldResumeHubFromHome(isRecording: true, hubOnStack: false),
        isTrue,
      );
      expect(
        shouldResumeHubFromHome(isRecording: true, hubOnStack: true),
        isFalse,
      );
      expect(
        shouldResumeHubFromHome(isRecording: false, hubOnStack: false),
        isFalse,
      );
    });

    test('hudClosed while recording marks minimized (not stop)', () {
      final nav = ArmedSessionNav();
      nav.hubOpened();
      nav.hudOpened();
      expect(nav.state.hudMinimized, isFalse);
      nav.hudClosed(stillRecording: true);
      expect(nav.state.hudOnStack, isFalse);
      expect(nav.state.hudMinimized, isTrue);
      expect(shouldAutoPushHud(nav.state, isRecording: true), isFalse);
    });

    test('hudClosed after stop does not treat as minimize', () {
      final nav = ArmedSessionNav();
      nav.hudOpened();
      nav.reset();
      nav.hudClosed(stillRecording: false);
      expect(nav.state.hudMinimized, isFalse);
    });
  });
}
