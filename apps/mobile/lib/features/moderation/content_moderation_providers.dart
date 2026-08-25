import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_moderation_repository.dart';

final contentModerationRepositoryProvider =
    Provider<ContentModerationRepository>((ref) {
  return ContentModerationRepository();
});

final staffContentReportsProvider =
    FutureProvider.autoDispose<List<ContentReport>>((ref) async {
  return ref.watch(contentModerationRepositoryProvider).listStaffReports();
});
