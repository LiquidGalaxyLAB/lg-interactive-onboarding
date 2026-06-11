import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/architecture_explorer/presentation/architecture_explorer_screen.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/presentation/model_builder_screen.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/presentation/settings_screen.dart';

import 'widgets/dashboard_palette.dart';
import 'widgets/connection_chip.dart';
import 'widgets/status_banner.dart';
import 'widgets/section_header.dart';
import 'widgets/rig_controls_grid.dart';
import 'widgets/feature_card.dart';
import 'widgets/deep_clean_card.dart';

/// Main dashboard — the hub after connecting to the LG rig.
///
/// Features a warm, humanistic design with organic layouts,
/// soft shadows, and tactile micro-animations.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssh = ref.watch(sshServiceProvider);
    final settings = ref.watch(settingsServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pushState = ref.watch(pushProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Organic App Bar ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: isDark
                ? const Color(0xFF141929)
                : DashboardPalette.parchment,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'LG Content Studio',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : DashboardPalette.inkDark,
                ),
              ),
            ),
            actions: [
              // Connection indicator
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ConnectionChip(
                  isConnected: ssh.isConnected,
                  host: settings.host,
                  isDark: isDark,
                ),
              ),
              // Architecture Explorer shortcut
              IconButton(
                icon: Icon(
                  Icons.help_outline_rounded,
                  color: isDark ? Colors.white60 : DashboardPalette.warmGrey,
                ),
                tooltip: 'Architecture Explorer',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ArchitectureExplorerScreen(),
                  ),
                ),
              ),
              IconButton(
                key: GuidedModeController.spotlightKey('settings_btn'),
                icon: Icon(
                  Icons.settings_outlined,
                  color: isDark ? Colors.white70 : DashboardPalette.warmGrey,
                ),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ─── Content ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Status banner with push state feedback
                if (pushState.message != null) ...[
                  StatusBanner(pushState: pushState, isDark: isDark),
                  const SizedBox(height: 16),
                ],

                // ─── Section: Rig Controls ─────────────────────
                SectionHeader(
                  label: 'RIG CONTROLS',
                  icon: Icons.gamepad_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Asymmetric grid of rig controls
                RigControlsGrid(isDark: isDark),

                const SizedBox(height: 28),

                // ─── Section: Tools ────────────────────────────
                SectionHeader(
                  label: 'TOOLS',
                  icon: Icons.construction_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // 3D Model Builder — large feature card
                FeatureCard(
                  title: '3D Model Builder',
                  subtitle: 'Import, place, and push 3D models to Liquid Galaxy',
                  icon: Icons.view_in_ar_outlined,
                  accentColor: DashboardPalette.modelBuilderIndigo,
                  isDark: isDark,
                  spotlightKey: 'model_builder_card',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ModelBuilderScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ─── Section: Maintenance ──────────────────────
                SectionHeader(
                  label: 'MAINTENANCE',
                  icon: Icons.build_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Deep Clean card
                DeepCleanCard(isDark: isDark),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
