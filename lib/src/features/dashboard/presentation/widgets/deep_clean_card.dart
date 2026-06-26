import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/analytics_service.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'dashboard_palette.dart';

class DeepCleanCard extends ConsumerWidget {
  final bool isDark;
  const DeepCleanCard({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssh = ref.watch(sshServiceProvider);
    final pushState = ref.watch(pushProvider);
    final isPushing = pushState.status == PushStatus.pushing;
    return ListenableBuilder(
      listenable: ssh,
      builder: (context, _) {
        final isConnected = ssh.isConnected;
        final enabled = isConnected && !isPushing;

        return GestureDetector(
          key: GuidedModeController.spotlightKey('deep_clean_btn'),
          onTap: enabled ? () => _confirmDeepClean(context, ref) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled
                    ? DashboardPalette.deepCleanRed.withValues(alpha: isDark ? 0.2 : 0.12)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DashboardPalette.deepCleanRed.withValues(
                      alpha: enabled ? (isDark ? 0.15 : 0.08) : 0.04,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    size: 22,
                    color: enabled
                        ? DashboardPalette.deepCleanRed
                        : DashboardPalette.deepCleanRed.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deep Clean',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? (isDark ? Colors.white : DashboardPalette.inkDark)
                              : (isDark ? Colors.white38 : DashboardPalette.warmGrey),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Remove all files from /model & /3d_model_wrapper, reset master KML',
                        style: TextStyle(
                          fontSize: 11,
                          color: enabled
                              ? (isDark ? Colors.white54 : DashboardPalette.warmGrey)
                              : (isDark
                                  ? Colors.white24
                                  : DashboardPalette.warmGrey.withValues(alpha: 0.4)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DashboardPalette.warmGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Offline',
                      style: TextStyle(fontSize: 10, color: DashboardPalette.warmGrey),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeepClean(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: DashboardPalette.deepCleanRed, size: 22),
            SizedBox(width: 10),
            Text('Deep Clean'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL files from:\n\n'
          '• /var/www/html/model/\n'
          '• /var/www/html/3d_model_wrapper/\n\n'
          'And reset the master KML. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(pushProvider.notifier).deepClean();
              // Signal curriculum engine — Module 7 auto-verify listens here
              ref.read(deepCleanConfirmedProvider.notifier).set(true);
              ref.read(analyticsServiceProvider).recordDeepCleanConfirmed();
            },
            style: FilledButton.styleFrom(
              backgroundColor: DashboardPalette.deepCleanRed,
            ),
            child: const Text('Deep Clean'),
          ),
        ],
      ),
    );
  }
}
