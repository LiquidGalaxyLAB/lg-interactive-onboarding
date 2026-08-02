import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lg_interactive_onboarding/src/common/theme/app_palette.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/learning_module.dart';
import 'package:lg_interactive_onboarding/src/features/about/presentation/about_screen.dart';
import 'package:lg_interactive_onboarding/src/features/architecture_explorer/presentation/architecture_explorer_screen.dart';
import 'package:lg_interactive_onboarding/src/features/curriculum_engine/presentation/module_completion_screen.dart';
import 'package:lg_interactive_onboarding/src/features/curriculum_engine/providers/curriculum_providers.dart';

/// The "Learn" tab — lists all curriculum modules with status and progress.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(curriculumModulesProvider);
    final completedCount = ref.watch(completedModuleCountProvider);
    final totalCount = ref.watch(totalModuleCountProvider);
    final guidedState = ref.watch(guidedModeControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen for module completion → push completion screen
    ref.listen(guidedModeControllerProvider, (prev, next) {
      if (next.phase == GuidedModePhase.completed &&
          next.activeModule != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                ModuleCompletionScreen(completedModule: next.activeModule!),
          ));
        });
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: isDark
                ? const Color(0xFF1E1E20)
                : Colors.white,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                tooltip: 'About',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AboutScreen(),
                )),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Learn',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Progress overview card
                _ProgressCard(
                  completed: completedCount,
                  total: totalCount,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // Active module banner
                if (guidedState.isActive &&
                    guidedState.activeModule != null) ...[
                  _ActiveModuleBanner(
                    module: guidedState.activeModule!,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                ],

                // Section header
                Text(
                  'MODULES',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 10),

                // Module list
                ...modules.map((module) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModuleCard(
                        module: module,
                        isDark: isDark,
                        isActiveModule:
                            guidedState.activeModule?.id == module.id,
                      ),
                    )),

                const SizedBox(height: 20),

                // Architecture Explorer entry
                _ExplorerCard(isDark: isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress Card ────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final bool isDark;

  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    final bg = isDark ? const Color(0xFF2A2A2D) : Colors.white;
    const accent = AppPalette.lgYellow;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.18 : 0.06),
            const Color(0xFFD3E3FD).withValues(alpha: isDark ? 0.08 : 0.04),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
        ),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(accent),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$completed',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          height: 1,
                        ),
                      ),
                      Text(
                        'of $total',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed == total && total > 0
                      ? 'All modules complete!'
                      : completed == 0
                          ? 'Ready to start learning?'
                          : 'Keep it up!',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed module${completed == 1 ? '' : 's'} completed',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        isDark ? Colors.white12 : Colors.black12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Active Module Banner ─────────────────────────────────────────────────────

class _ActiveModuleBanner extends StatelessWidget {
  final LearningModule module;
  final bool isDark;

  const _ActiveModuleBanner({required this.module, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.lgYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.lgYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline_rounded,
              color: AppPalette.lgYellow, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'In progress: ${module.title}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppPalette.lgYellow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Module Card ──────────────────────────────────────────────────────────────

class _ModuleCard extends ConsumerWidget {
  final LearningModule module;
  final bool isDark;
  final bool isActiveModule;

  const _ModuleCard({
    required this.module,
    required this.isDark,
    required this.isActiveModule,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = module.status == ModuleStatus.locked;
    final isCompleted = module.status == ModuleStatus.completed;
    final isAvailable = module.status == ModuleStatus.available ||
        module.status == ModuleStatus.inProgress;

    final bg = isDark ? const Color(0xFF2A2A2D) : Colors.white;
    final border = isActiveModule
        ? AppPalette.lgYellow.withValues(alpha: 0.5)
        : isDark
            ? Colors.white.withValues(alpha: isLocked ? 0.04 : 0.07)
            : Colors.black.withValues(alpha: isLocked ? 0.04 : 0.06);

    return AnimatedOpacity(
      opacity: isLocked ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        onTap: isAvailable || isActiveModule || isCompleted
            ? () => _startModule(context, ref)
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: isActiveModule
                ? [
                    BoxShadow(
                      color: AppPalette.lgYellow.withValues(alpha: 0.15),
                      blurRadius: 12,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _statusColor(module.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isLocked
                      ? Icon(Icons.lock_outline_rounded,
                          size: 18,
                          color: isDark ? Colors.white30 : Colors.black38)
                      : isCompleted
                          ? const Icon(Icons.check_circle_rounded,
                              size: 22, color: Color(0xFF1E8E3E))
                          : Icon(
                                Icons.play_circle_outline_rounded,
                                size: 20,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF1F1F1F),
                              ),
                ),
              ),

              const SizedBox(width: 12),

              // Title + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isLocked
                            ? (isDark ? Colors.white38 : Colors.black38)
                            : (isDark ? Colors.white : const Color(0xFF1F1F1F)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 11,
                            color: isDark ? Colors.white30 : Colors.black38),
                        const SizedBox(width: 3),
                        Text(
                          _formatDuration(module.estimatedTime),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white30 : Colors.black38,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: module.status),
                      ],
                    ),
                  ],
                ),
              ),

              // CTA chevron
              if (!isLocked)
                Icon(
                  isCompleted
                      ? Icons.replay_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _startModule(BuildContext context, WidgetRef ref) {
    ref.read(guidedModeControllerProvider.notifier).startModule(module);
    // Navigate to the target screen
    _navigateTo(context, module.targetFeatureRoute);
  }

  void _navigateTo(BuildContext context, String route) {
    switch (route) {
      case AppRoutes.settings:
        // Shell handles tab index; open settings as a push
        Navigator.of(context).pushNamed(AppRoutes.settings);
        break;
      case AppRoutes.modelBuilder:
        Navigator.of(context).pushNamed(AppRoutes.modelBuilder);
        break;
      case AppRoutes.architectureExplorer:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ArchitectureExplorerScreen(),
        ));
        break;
      case AppRoutes.dashboard:
        // Switch to home tab (index 0) via shell
        _switchToHomeTab(context);
        break;
    }
  }

  void _switchToHomeTab(BuildContext context) {
    // The AppShell exposes a ValueNotifier for tab index;
    // fall back to a simple pop-to-root if not available.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Color _statusColor(ModuleStatus status) {
    switch (status) {
      case ModuleStatus.locked:
        return Colors.grey;
      case ModuleStatus.available:
        return AppPalette.lgYellow;
      case ModuleStatus.inProgress:
        return const Color(0xFFE37400);
      case ModuleStatus.completed:
        return const Color(0xFF1E8E3E);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '~${d.inMinutes} min';
    return '~${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
}

class _StatusBadge extends StatelessWidget {
  final ModuleStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ModuleStatus.locked => ('Locked', Colors.grey),
      ModuleStatus.available => ('Available', AppPalette.lgYellow),
      ModuleStatus.inProgress => ('In Progress', const Color(0xFFE37400)),
      ModuleStatus.completed => ('Completed', const Color(0xFF1E8E3E)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Architecture Explorer Entry ──────────────────────────────────────────────

class _ExplorerCard extends StatelessWidget {
  final bool isDark;
  const _ExplorerCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ArchitectureExplorerScreen(),
      )),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E1E20), const Color(0xFF2A2A2D)]
                : [const Color(0xFFF8F9FA), Colors.white],
          ),
          border: Border.all(
            color: const Color(0xFF4A6785).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF4A6785)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_tree_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Architecture Explorer',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Interactive diagrams: Master-Slave topology, ViewSync, '
                    'SSH flow, KML propagation.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF4A6785)),
          ],
        ),
      ),
    );
  }
}
