import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/app_update_service.dart';

void main() {
  test('normalizeVersion strips v prefix and build metadata', () {
    expect(AppUpdateService.normalizeVersion('v1.3.1+5'), '1.3.1');
    expect(AppUpdateService.normalizeVersion('1.4.0'), '1.4.0');
  });

  test('isNewer compares semver parts', () {
    expect(AppUpdateService.isNewer('1.3.1', '1.3.0'), isTrue);
    expect(AppUpdateService.isNewer('1.3.0', '1.3.1'), isFalse);
    expect(AppUpdateService.isNewer('1.3.1', '1.3.1'), isFalse);
    expect(AppUpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
  });
}
