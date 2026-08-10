import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/common/lg/lg_service.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/data/kml_playground_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
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
    final theme = Theme.of(context);
    final surfaceColor = widget.isDark ? const Color(0xFF2A2A2D) : Colors.white;
    final txtColor = isConnected ? theme.colorScheme.onSurface : (widget.isDark ? Colors.white38 : DashboardPalette.warmGrey);
    final subTxtColor = isConnected ? theme.colorScheme.onSurfaceVariant : (widget.isDark ? Colors.white24 : DashboardPalette.warmGrey.withValues(alpha: 0.4));
    
    // Using LG Yellow as an accent
    const accentColor = DashboardPalette.lgYellow;

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
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark ? Colors.white12 : const Color(0xFFDADCE0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
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
                color: accentColor.withValues(alpha: isConnected ? (widget.isDark ? 0.15 : 0.1) : 0.04),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.layers_clear_rounded,
                size: 22,
                color: isConnected ? accentColor : accentColor.withValues(alpha: 0.4),
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
                      color: txtColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Remove standard KML layers from the Liquid Galaxy display',
                    style: TextStyle(
                      fontSize: 11,
                      color: subTxtColor,
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
    await ref.read(pushProvider.notifier).clearMasterKml();
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
