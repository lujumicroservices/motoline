import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/share_visibility.dart';
import '../../theme/app_theme.dart';

/// Fast 3-way visibility control (Only me / Friends / Everyone).
class VisibilitySelector extends StatelessWidget {
  const VisibilitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final ShareVisibility value;
  final ValueChanged<ShareVisibility> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ShareVisibility>(
          segments: [
            for (final v in ShareVisibility.values)
              ButtonSegment(
                value: v,
                label: Text(
                  dense ? _short(v) : v.label,
                  style: GoogleFonts.exo2(fontSize: dense ? 11 : 12),
                ),
                tooltip: v.help,
              ),
          ],
          selected: {value},
          onSelectionChanged: (set) {
            if (set.isEmpty) return;
            onChanged(set.first);
          },
          style: ButtonStyle(
            visualDensity:
                dense ? VisualDensity.compact : VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (!dense) ...[
          const SizedBox(height: 6),
          Text(
            value.help,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  String _short(ShareVisibility v) => switch (v) {
        ShareVisibility.private => 'Me',
        ShareVisibility.friends => 'Friends',
        ShareVisibility.public => 'Public',
      };
}
