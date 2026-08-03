import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/data/kml_playground_service.dart';
import 'dashboard_palette.dart';

class ClearKmlCard extends ConsumerStatefulWidget {
  final bool isDark;
  const ClearKmlCard({super.key, required this.isDark});

  @override
  ConsumerState<ClearKmlCard> createState() => _ClearKmlCardState();
}

class _ClearKmlCardState extends ConsumerState<ClearKmlCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ssh = ref.watch(sshServiceProvider);
    final isConnected = ssh.isConnected;
    
    // Using LG Yellow to complete the 4-color harmony on the dashboard
    const accentColor = DashboardPalette.lgYellow;
    final textColor = accentColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return GestureDetector(
      key: GuidedModeController.spotlightKey('clear_kml_btn'),
      onTapDown: isConnected ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isConnected ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: isConnected ? () => setState(() => _pressed = false) : null,
      onTap: isConnected ? () => _clearKml(context, ref) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.98 : 1.0,
          _pressed ? 0.98 : 1.0,
          1.0,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConnected
              ? accentColor
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (isConnected && !_pressed)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isConnected
                    ? textColor.withValues(alpha: 0.15)
                    : accentColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.layers_clear_rounded,
                size: 22,
                color: isConnected
                    ? textColor
                    : accentColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clear KML',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isConnected
                          ? textColor
                          : (widget.isDark ? Colors.white38 : DashboardPalette.warmGrey),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Remove standard KML layers from the Liquid Galaxy display',
                    style: TextStyle(
                      fontSize: 11,
                      color: isConnected
                          ? textColor.withValues(alpha: 0.8)
                          : (widget.isDark
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
  }

  Future<void> _clearKml(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(kmlPlaygroundServiceProvider).clearKml();
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'KML layers cleared!' : 'Failed to clear KML layers',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: ok ? const Color(0xFF1E8E3E) : const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
