import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/providers/force_start_prefs.dart';

void main() {
  test('force-start button follows only the Settings switch', () {
    expect(showForceStartArmedButton(false), isFalse);
    expect(showForceStartArmedButton(true), isTrue);
  });
}
