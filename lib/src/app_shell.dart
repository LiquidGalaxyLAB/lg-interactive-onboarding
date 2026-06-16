import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/features/curriculum_engine/presentation/learn_screen.dart';
import 'package:lg_interactive_onboarding/src/features/curriculum_engine/presentation/guided_mode_overlay.dart';
import 'package:lg_interactive_onboarding/src/features/dashboard/presentation/dashboard_screen.dart';

/// Root scaffold with bottom navigation bar.
///
/// Uses [IndexedStack] to preserve state across tab switches.
///
/// Tabs:
///   0 — Home ([DashboardScreen])
///   1 — Learn ([LearnScreen])
///
/// The guided-mode overlay is mounted at the shell level so it persists
/// across tabs without being recreated.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final guidedState = ref.watch(guidedModeControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF6C5CE7);

    return Scaffold(
      body: Stack(
        children: [
          // ── Main content (tab views) ─────────────────────────────────────
          IndexedStack(
            index: _selectedIndex,
            children: const [
              DashboardScreen(),
              LearnScreen(),
            ],
          ),

          // ── Guided-mode overlay (lives at shell level) ───────────────────
          if (guidedState.isActive)
            const GuidedModeOverlay(),
        ],
      ),

      // ── Bottom navigation bar ──────────────────────────────────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: isDark ? const Color(0xFF141929) : Colors.white,
        indicatorColor: accent.withValues(alpha: 0.15),
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
              color: _selectedIndex == 0
                  ? accent
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            selectedIcon: const Icon(Icons.home_rounded, color: Color(0xFF6C5CE7)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: guidedState.isActive && _selectedIndex != 1,
              backgroundColor: const Color(0xFFFD79A8),
              child: Icon(
                Icons.school_outlined,
                color: _selectedIndex == 1
                    ? accent
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            selectedIcon:
                const Icon(Icons.school_rounded, color: Color(0xFF6C5CE7)),
            label: 'Learn',
          ),
        ],
      ),
    );
  }
}

class ShellTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}

/// Provider that exposes the shell's tab index for switching tabs
/// programmatically (e.g., from guided mode navigate-to-home).
///
/// Currently used as a signal; [AppShell] can be extended to read this
/// provider if cross-widget tab switching is needed.
final shellTabIndexProvider = NotifierProvider<ShellTabIndexNotifier, int>(
  ShellTabIndexNotifier.new,
);
