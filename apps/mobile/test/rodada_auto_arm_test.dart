import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/rodadas/rodada_auto_arm.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('auto-arm starts unconsumed', () async {
    expect(await RodadaAutoArm.isConsumed('r1'), isFalse);
  });

  test('markConsumed is a one-shot until cleared', () async {
    await RodadaAutoArm.markConsumed('r1');
    expect(await RodadaAutoArm.isConsumed('r1'), isTrue);
    expect(await RodadaAutoArm.isConsumed('r2'), isFalse);

    await RodadaAutoArm.markConsumed('r1');
    expect(await RodadaAutoArm.isConsumed('r1'), isTrue);

    await RodadaAutoArm.clearConsumed('r1');
    expect(await RodadaAutoArm.isConsumed('r1'), isFalse);
  });
}
