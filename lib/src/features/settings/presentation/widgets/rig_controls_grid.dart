import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/common/lg/lg_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/logo_overlay_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/system_kml_service.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/data/kml_playground_service.dart';
import 'package:lg_interactive_onboarding/src/common/theme/app_palette.dart';

class RigControlsGrid extends ConsumerWidget {
  final bool isDark;
  const RigControlsGrid({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssh = ref.watch(sshServiceProvider);
    return ListenableBuilder(
      listenable: ssh,
      builder: (context, _) {
        final isConnected = ssh.isConnected;
        return Column(
          children: [
            // Row 1: Shutdown + Reboot (wider shutdown)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: RigControlCard(
                    title: 'Shutdown',
                    icon: Icons.power_settings_new_rounded,
                    accentColor: AppPalette.terracotta,
                    isDark: isDark,
                    enabled: isConnected,
                    onTap: () => _confirmDangerous(
                      context,
                      ref,
                      title: 'Shutdown All Rigs',
                      message: 'This will power off all Liquid Galaxy rigs. Continue?',
                      action: () => ref.read(lgServiceProvider).shutdown(),
                      actionLabel: 'Shutdown',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: RigControlCard(
                    title: 'Reboot',
                    icon: Icons.restart_alt_rounded,
                    accentColor: AppPalette.warmAmber,
                    isDark: isDark,
                    enabled: isConnected,
                    onTap: () => _confirmDangerous(
                      context,
                      ref,
                      title: 'Reboot All Rigs',
                      message: 'This will reboot all Liquid Galaxy rigs. Continue?',
                      action: () => ref.read(lgServiceProvider).reboot(),
                      actionLabel: 'Reboot',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Relaunch + Refresh Master KML
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: RigControlCard(
                    title: 'Relaunch',
                    icon: Icons.refresh_rounded,
                    accentColor: AppPalette.sage,
                    isDark: isDark,
                    enabled: isConnected,
                    onTap: () async {
                      await ref.read(lgServiceProvider).relaunch();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Relaunching LG...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: RigControlCard(
                    title: 'Refresh KML',
                    icon: Icons.sync_rounded,
                    accentColor: AppPalette.dustyBlue,
                    isDark: isDark,
                    enabled: isConnected,
                    onTap: () async {
                      final ok = await ref.read(systemKmlServiceProvider).forceRefreshAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Master KML refreshed' : 'Refresh failed'),
                            backgroundColor: ok ? AppPalette.sage : AppPalette.terracotta,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Clear KML + Clear Logo
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: RigControlCard(
                    title: 'Clear KML',
                    icon: Icons.layers_clear_rounded,
                    accentColor: AppPalette.lgYellow,
                    isDark: isDark,
                    enabled: isConnected,
                    onTap: () async {
                      final ok = await ref.read(kmlPlaygroundServiceProvider).clearKml();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'KML cleared' : 'Failed to clear KML'),
                            backgroundColor: ok ? AppPalette.sage : AppPalette.terracotta,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: RigControlCard(
                    title: 'Clear Logo',
                    icon: Icons.hide_image_outlined,
                    accentColor: AppPalette.dustyBlue,
                    isDark: isDark,
                    enabled: isConnected,
                    onTap: () => _confirmDangerous(
                      context,
                      ref,
                      title: 'Clear Logo',
                      message: 'Remove the logo overlay from the leftmost LG screen?',
                      action: () async {
                        await ref.read(logoOverlayServiceProvider).clearLogo();
                        return true;
                      },
                      actionLabel: 'Clear Logo',
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _confirmDangerous(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required Future<bool> Function() action,
    required String actionLabel,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppPalette.terracotta, size: 22),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await action();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '$actionLabel command sent'
                        : '$actionLabel failed'),
                    backgroundColor: ok ? AppPalette.sage : AppPalette.terracotta,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.terracotta,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class RigControlCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  const RigControlCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<RigControlCard> createState() => _RigControlCardState();
}

class _RigControlCardState extends State<RigControlCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark
        ? const Color(0xFF2A2A2D)   // M3 dark surface variant
        : Colors.white;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.96 : 1.0,
          _pressed ? 0.96 : 1.0,
          1.0,
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: widget.enabled
              ? surfaceColor
              : surfaceColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.enabled
                ? (widget.isDark ? Colors.white12 : const Color(0xFFDADCE0))
                : Colors.transparent,
          ),
          boxShadow: [
            if (widget.enabled && !_pressed)
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(
                  alpha: widget.enabled
                      ? (widget.isDark ? 0.15 : 0.08)
                      : 0.04,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: widget.enabled
                    ? widget.accentColor
                    : widget.accentColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.enabled
                    ? (widget.isDark ? Colors.white : AppPalette.inkDark)
                    : (widget.isDark
                        ? Colors.white38
                        : AppPalette.warmGrey.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
