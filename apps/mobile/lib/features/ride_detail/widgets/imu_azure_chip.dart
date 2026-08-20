import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/imu_upload.dart';
import '../../../core/services/imu_blob_upload_service.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';

final imuUploadProvider =
    FutureProvider.autoDispose.family<ImuUploadRow?, String>((ref, rideId) {
  return ref.watch(imuBlobUploadServiceProvider).statusFor(rideId);
});

/// Status + retry for Azure IMU replay upload.
class ImuAzureChip extends ConsumerWidget {
  const ImuAzureChip({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ImuBlobUploadService.isConfigured) return const SizedBox.shrink();
    final l10n = context.l10n;
    final async = ref.watch(imuUploadProvider(rideId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (row) {
        if (row == null) return const SizedBox.shrink();
        final (label, color) = switch (row.status) {
          ImuUploadStatus.pending => (l10n.imuAzurePending, AppTheme.steel),
          ImuUploadStatus.uploading => (l10n.imuAzureUploading, AppTheme.line),
          ImuUploadStatus.uploaded => (l10n.imuAzureUploaded, AppTheme.line),
          ImuUploadStatus.failed => (l10n.imuAzureFailed, AppTheme.lineHot),
        };
        final retry = row.status == ImuUploadStatus.failed ||
            row.status == ImuUploadStatus.pending;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: InkWell(
            onTap: retry
                ? () async {
                    await ref
                        .read(imuBlobUploadServiceProvider)
                        .uploadRide(rideId);
                    ref.invalidate(imuUploadProvider(rideId));
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  retry ? l10n.imuAzureRetry : label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
