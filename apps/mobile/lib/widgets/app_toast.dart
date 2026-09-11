import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How long a toast stays up, by importance.
enum AppToastTone { info, success, warning, error }

extension AppToastToneDuration on AppToastTone {
  Duration get linger {
    return switch (this) {
      AppToastTone.info => const Duration(milliseconds: 2500),
      AppToastTone.success => const Duration(seconds: 3),
      AppToastTone.warning => const Duration(seconds: 4),
      AppToastTone.error => const Duration(milliseconds: 5500),
    };
  }

  Color get accent {
    return switch (this) {
      AppToastTone.info => AppTheme.line,
      AppToastTone.success => AppTheme.line,
      AppToastTone.warning => AppTheme.lineHot,
      AppToastTone.error => AppTheme.signal,
    };
  }
}

final GlobalKey<AppToastHostState> appToastHostKey =
    GlobalKey<AppToastHostState>();

class _ToastSpec {
  const _ToastSpec({
    required this.message,
    required this.tone,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppToastTone tone;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Overlay at the top of the app. Replaces Material [SnackBar].
class AppToastHost extends StatefulWidget {
  const AppToastHost({super.key, required this.child});

  final Widget child;

  static AppToastHostState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AppToastHostState>();
  }

  @override
  State<AppToastHost> createState() => AppToastHostState();
}

class AppToastHostState extends State<AppToastHost> {
  _ToastSpec? _toast;
  Timer? _hideTimer;
  int _seq = 0;

  void showToast({
    required String message,
    required AppToastTone tone,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _present(
      _ToastSpec(
        message: message,
        tone: tone,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  void _present(_ToastSpec spec) {
    _hideTimer?.cancel();
    setState(() {
      _seq += 1;
      _toast = spec;
    });
    _hideTimer = Timer(spec.duration, hide);
  }

  void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_toast == null) return;
    setState(() => _toast = null);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toast = _toast;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (toast != null)
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: _AppToastCard(
                  key: ValueKey(_seq),
                  spec: toast,
                  onClose: hide,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppToastCard extends StatelessWidget {
  const _AppToastCard({super.key, required this.spec, required this.onClose});

  final _ToastSpec spec;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final closeTip = MaterialLocalizations.of(context).closeButtonTooltip;
    return Dismissible(
      key: ValueKey(spec.message),
      direction: DismissDirection.up,
      onDismissed: (_) => onClose(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: AppTheme.asphaltElevated.withValues(alpha: 0.72),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.mist.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(width: 3, height: 36, color: spec.tone.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              spec.message,
                              style: const TextStyle(
                                color: AppTheme.mist,
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (spec.actionLabel != null &&
                                spec.onAction != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: GestureDetector(
                                  onTap: () {
                                    final action = spec.onAction!;
                                    onClose();
                                    action();
                                  },
                                  child: Text(
                                    spec.actionLabel!,
                                    style: TextStyle(
                                      color: spec.tone.accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: closeTip,
                      child: InkWell(
                        key: const Key('app-toast-close'),
                        onTap: onClose,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: AppTheme.mist.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showAppToast(
  String message, {
  BuildContext? context,
  AppToastTone tone = AppToastTone.info,
  Duration? duration,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final text = message.trim();
  if (text.isEmpty) return;

  var linger = duration ?? tone.linger;
  if (actionLabel != null && duration == null) {
    linger = linger + const Duration(seconds: 2);
  }

  final host =
      (context != null ? AppToastHost.maybeOf(context) : null) ??
      appToastHostKey.currentState;
  host?.showToast(
    message: text,
    tone: tone,
    duration: linger,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

/// Compact in-app toast (top). Empty messages are ignored.
void showAppSnack(
  BuildContext? context,
  String message, {
  Duration? duration,
  AppToastTone tone = AppToastTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showAppToast(
    message,
    context: context,
    duration: duration,
    tone: tone,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

void showAppSnackError(BuildContext? context, String message) {
  showAppToast(message, context: context, tone: AppToastTone.error);
}
