import 'package:flutter/material.dart';
import 'dashboard_palette.dart';

class SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;

  const SectionHeader({
    super.key,
    required this.label,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : DashboardPalette.warmGrey.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : DashboardPalette.warmGrey.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
