import 'package:flutter/material.dart';

import '../core/notifications/push_notification_service.dart';
import '../theme/app_theme.dart';

/// Compact floating toast — hides quickly and stays out of the way.
SnackBar appSnackBar(
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  return SnackBar(
    content: Text(message, style: const TextStyle(fontSize: 13, height: 1.25)),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(48, 0, 48, 20),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    dismissDirection: DismissDirection.horizontal,
    elevation: 2,
  );
}

void showAppSnack(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final bar = appSnackBar(message, duration: duration);
  final local = ScaffoldMessenger.maybeOf(context);
  if (local != null) {
    local.hideCurrentSnackBar();
    local.showSnackBar(bar);
    return;
  }
  appMessengerKey.currentState?.hideCurrentSnackBar();
  appMessengerKey.currentState?.showSnackBar(bar);
}

void showAppSnackError(BuildContext context, String message) {
  final bar = SnackBar(
    content: Text(
      message,
      style: const TextStyle(fontSize: 13, color: AppTheme.mist, height: 1.25),
    ),
    duration: const Duration(seconds: 3),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(48, 0, 48, 20),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    backgroundColor: AppTheme.asphaltElevated,
    dismissDirection: DismissDirection.horizontal,
    elevation: 2,
  );
  final local = ScaffoldMessenger.maybeOf(context);
  if (local != null) {
    local.hideCurrentSnackBar();
    local.showSnackBar(bar);
    return;
  }
  appMessengerKey.currentState?.hideCurrentSnackBar();
  appMessengerKey.currentState?.showSnackBar(bar);
}
