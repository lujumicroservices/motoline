import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/rodadas/models/rodada_models.dart';

RodadaSummary _rodada({
  required String id,
  required String status,
  DateTime? startsAt,
  DateTime? createdAt,
}) {
  return RodadaSummary(
    id: id,
    hostId: 'host',
    title: id,
    status: status,
    inviteCode: 'ABC123',
    startsAt: startsAt,
    createdAt: createdAt,
  );
}

void main() {
  test('attach prefers tonight over a future open rodada', () {
    final now = DateTime.utc(2026, 8, 22, 5, 20);
    final test1 = _rodada(
      id: 'test-1',
      status: 'open',
      startsAt: DateTime.utc(2026, 8, 22, 5, 5),
      createdAt: DateTime.utc(2026, 8, 22, 4, 58),
    );
    final tapalpa = _rodada(
      id: 'tapalpa',
      status: 'open',
      startsAt: DateTime.utc(2026, 8, 23, 14),
      createdAt: DateTime.utc(2026, 8, 21, 23, 23),
    );
    final ranked = [tapalpa, test1]
      ..sort((a, b) => compareAttachableRodadas(a, b, now: now));
    expect(ranked.first.id, 'test-1');
  });

  test('attach prefers live over a closer open start', () {
    final now = DateTime.utc(2026, 8, 22, 5, 20);
    final live = _rodada(
      id: 'live',
      status: 'live',
      startsAt: DateTime.utc(2026, 8, 22, 8),
      createdAt: now,
    );
    final open = _rodada(
      id: 'open',
      status: 'open',
      startsAt: now,
      createdAt: now,
    );
    final ranked = [open, live]
      ..sort((a, b) => compareAttachableRodadas(a, b, now: now));
    expect(ranked.first.id, 'live');
  });
}
