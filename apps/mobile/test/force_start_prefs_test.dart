import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/providers/force_start_prefs.dart';

void main() {
  test('force-start button needs the settings switch on', () {
    expect(showForceStartArmedButton(false), isFalse);
    expect(showForceStartArmedButton(true), isTrue);
  });
}
