import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// Classic pulsing red REC indicator (camera-style recording lamp).
class RecordingRecBadge extends StatefulWidget {
  const RecordingRecBadge({
    super.key,
    required this.label,
    this.paused = false,
    this.compact = false,
  });

  final String label;
  final bool paused;
  final bool compact;

  @override
  State<RecordingRecBadge> createState() => _RecordingRecBadgeState();
}

class _RecordingRecBadgeState extends State<RecordingRecBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (!widget.paused) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant RecordingRecBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused) {
      if (_pulse.isAnimating) {
        _pulse.stop();
      }
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 8.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 12,
        vertical: widget.compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.signal.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final opacity = widget.paused
                  ? 0.45
                  : (0.28 + 0.72 * _pulse.value);
              return Opacity(
                opacity: opacity,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppTheme.signal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.signal.withValues(alpha: 0.55),
                        blurRadius: widget.compact ? 4 : 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(width: widget.compact ? 6 : 8),
          Text(
            widget.label,
            style: GoogleFonts.exo2(
              color: AppTheme.signal,
              fontWeight: FontWeight.w800,
              fontSize: widget.compact ? 12 : 13,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
