import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/logo_overlay_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'dashboard_palette.dart';

/// Maintenance card for manually clearing the logo overlay from the
/// leftmost LG slave screen.
class ClearLogoCard extends ConsumerWidget {
  final bool isDark;
  const ClearLogoCard({super.key, required this.isDark});

  static const _accentColor = DashboardPalette.dustyBlue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssh = ref.watch(sshServiceProvider);
    final pushState = ref.watch(pushProvider);
    final logoService = ref.watch(logoOverlayServiceProvider);
    final isPushing = pushState.status == PushStatus.pushing;

    return ListenableBuilder(
      listenable: Listenable.merge([ssh, logoService]),
      builder: (context, _) {
        final isConnected = ssh.isConnected;
        final isLogoVisible = logoService.isLogoVisible;
        final enabled = isConnected && !isPushing;

        return GestureDetector(
          onTap: enabled ? () => _confirmClearLogo(context, ref, isLogoVisible) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled
                    ? _accentColor.withValues(alpha: isDark ? 0.2 : 0.12)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(
                      alpha: enabled ? (isDark ? 0.15 : 0.08) : 0.04,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    isLogoVisible ? Icons.hide_image_outlined : Icons.image_outlined,
                    size: 22,
                    color: enabled
                        ? _accentColor
                        : _accentColor.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLogoVisible ? 'Clear Logo' : 'Show Logo',
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
                        isLogoVisible
                            ? 'Remove the logo overlay from the left LG screen'
                            : 'Show the logo overlay on the left LG screen',
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

  void _confirmClearLogo(BuildContext context, WidgetRef ref, bool isLogoVisible) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isLogoVisible ? Icons.hide_image_outlined : Icons.image_outlined,
                color: _accentColor, size: 22),
            const SizedBox(width: 10),
            Text(isLogoVisible ? 'Clear Logo' : 'Show Logo'),
          ],
        ),
        content: Text(
          isLogoVisible 
              ? 'Remove the logo overlay from the leftmost LG screen?'
              : 'Show the logo overlay on the leftmost LG screen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isLogoVisible) {
                ref.read(logoOverlayServiceProvider).clearLogo();
              } else {
                ref.read(logoOverlayServiceProvider).sendLogo();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: _accentColor,
            ),
            child: Text(isLogoVisible ? 'Clear Logo' : 'Show Logo'),
          ),
        ],
      ),
    );
  }
}
