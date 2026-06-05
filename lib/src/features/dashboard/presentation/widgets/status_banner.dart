import 'package:flutter/material.dart';
import 'dashboard_palette.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';

class StatusBanner extends StatelessWidget {
  final PushState pushState;
  final bool isDark;

  const StatusBanner({super.key, required this.pushState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isSuccess = pushState.status == PushStatus.success;
    final isError = pushState.status == PushStatus.error;
    final isPushing = pushState.status == PushStatus.pushing;

    final color = isSuccess
        ? DashboardPalette.sage
        : isError
            ? DashboardPalette.terracotta
            : DashboardPalette.dustyBlue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          if (isPushing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: color,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pushState.message ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
