import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/ride.dart';
import 'package:motoline/features/ride_active/armed_session_nav.dart';
import 'package:motoline/features/rodadas/rodada_capture.dart';

Ride _ride({String? rodadaId, RideStatus status = RideStatus.recording}) {
  return Ride(
    id: 'ride-1',
    startedAt: DateTime.utc(2026, 9, 10, 12),
    status: status,
    rodadaId: rodadaId,
  );
}

void main() {
  group('rodada capture helpers', () {
    test('ride maps rodadaId round-trip', () {
      final ride = _ride(rodadaId: 'rod-1');
      final copy = Ride.fromMap(ride.toMap());
      expect(copy.rodadaId, 'rod-1');
      expect(rideIsRodadaBound(copy), isTrue);
      expect(rideIsRodadaBound(_ride()), isFalse);
    });

    test('incomplete rodada rides stay off Home until completed', () {
      expect(shouldHideIncompleteRodadaRide(_ride(rodadaId: 'rod-1')), isTrue);
      expect(shouldHideIncompleteRodadaRide(_ride()), isFalse);
      expect(shouldHideIncompleteRodadaRide(null), isFalse);
    });

    test('pause action is rodada-scoped', () {
      expect(shouldUseRodadaPauseAction('rod-1'), isTrue);
      expect(shouldUseRodadaPauseAction(null), isFalse);
      expect(shouldUseRodadaPauseAction(''), isFalse);
    });

    test('resume shows when held, not while capturing', () {
      expect(
        shouldShowResumeRodadaCapture(
          rodadaLive: true,
          rodadaId: 'rod-1',
          activeRodadaId: 'rod-1',
          isRecording: true,
          isArmed: false,
          metricsHeld: true,
          hasLocalRecordingRide: true,
        ),
        isTrue,
      );
      expect(
        isActivelyCapturingRodada(
          rodadaId: 'rod-1',
          activeRodadaId: 'rod-1',
          isRecording: true,
          metricsHeld: false,
        ),
        isTrue,
      );
      expect(
        shouldShowResumeRodadaCapture(
          rodadaLive: true,
          rodadaId: 'rod-1',
          activeRodadaId: 'rod-1',
          isRecording: true,
          isArmed: false,
          metricsHeld: false,
          hasLocalRecordingRide: true,
        ),
        isFalse,
      );
    });

    test('copyWith keeps the same ride id across hold/resume', () {
      final a = _ride(rodadaId: 'rod-1');
      final b = a.copyWith(distanceMeters: 1200);
      expect(b.id, a.id);
      expect(b.rodadaId, 'rod-1');
      expect(b.status, RideStatus.recording);
    });
  });

  group('armed session nav with rodada hold', () {
    test('held capture does not auto-reopen HUD or hub from Home', () {
      const nav = ArmedSessionNavState();
      expect(
        shouldAutoPushHud(nav, isRecording: true, rodadaMetricsHeld: true),
        isFalse,
      );
      expect(
        shouldResumeHubFromHome(
          isRecording: true,
          hubOnStack: false,
          rodadaMetricsHeld: true,
        ),
        isFalse,
      );
      expect(
        shouldAutoPushHud(nav, isRecording: true, rodadaMetricsHeld: false),
        isTrue,
      );
    });
  });
}
