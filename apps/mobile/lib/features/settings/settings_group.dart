import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    this.help,
    required this.children,
  });

  final String title;
  final String? help;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Text(
          title,
          style: AppFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (help != null && help!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            help!,
            style: AppFonts.body(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
