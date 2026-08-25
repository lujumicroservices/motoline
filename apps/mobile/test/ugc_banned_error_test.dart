import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/moderation/content_moderation_repository.dart';

void main() {
  test('ugc_banned errors are detected from Postgrest/StateError text', () {
    expect(isUgcBannedError(StateError('ugc_banned')), isTrue);
    expect(isUgcBannedError(Exception('P0001 ugc_banned')), isTrue);
    expect(isUgcBannedError(Exception('network')), isFalse);
  });
}
