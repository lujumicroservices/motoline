import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/location_service.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';

/// Play-prominent disclosure before Android/iOS location permission prompts.
class LocationPermissionGate {
  LocationPermissionGate._();

  static final _location = LocationService();

  /// Shows disclosure (when needed) then requests location permissions for rides.
  static Future<bool> requestForRecording(BuildContext context) async {
    if (await _location.hasRecordingPermission()) return true;
    if (!context.mounted) return false;

    final accepted = await _showDisclosure(
      context,
      title: context.l10n.locationDisclosureTitle,
      body: context.l10n.locationDisclosureBody,
    );
    if (!accepted || !context.mounted) return false;

    final result = await _location.ensurePermission();
    return result.granted;
  }

  /// While-in-use location for rodada En vivo (map + optional pack sharing).
  static Future<bool> requestForRodadaLive(BuildContext context) async {
    if (await hasWhileInUsePermission()) return true;
    if (!context.mounted) return false;

    final accepted = await _showDisclosure(
      context,
      title: context.l10n.locationRodadaLiveDisclosureTitle,
      body: context.l10n.locationRodadaLiveDisclosureBody,
    );
    if (!accepted || !context.mounted) return false;

    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<bool> hasWhileInUsePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<bool> _showDisclosure(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        title: Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.line, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              height: 1.45,
              color: AppTheme.mist,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.locationDisclosureContinue),
          ),
        ],
      ),
    );
    return accepted == true;
  }
}
