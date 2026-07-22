import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/logo_overlay_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/presentation/mentor_screen.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/presentation/widgets/mentor_avatar.dart';
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
///   2 — AI Mentor ([MentorScreen])
///
/// The guided-mode overlay is mounted at the shell level so it persists
/// across tabs without being recreated.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Clears the logo and disconnects SSH when the app is gracefully exited.
  /// [AppLifecycleState.detached] fires when the Flutter engine is about to
  /// be torn down (back-button exit on Android, swipe-close on iOS, etc.).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      final ssh = ref.read(sshServiceProvider);
      if (ssh.isConnected) {
        final logo = ref.read(logoOverlayServiceProvider);
        // Fire-and-forget — best-effort before process is killed.
        logo.clearLogo().then((_) => ssh.disconnect());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guidedState = ref.watch(guidedModeControllerProvider);
    final mentor = ref.read(mentorServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF1A73E8);
    const mentorAccent = Color(0xFF7C4DFF);

    // ── Sync local index ↔ provider (for programmatic tab switches) ────────
    // The MentorAvatar widget sets the provider to navigate here.
    ref.listen<int>(shellTabIndexProvider, (previous, next) {
      if (next != _selectedIndex) {
        setState(() => _selectedIndex = next);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Main content (tab views) ─────────────────────────────────────
          IndexedStack(
            index: _selectedIndex,
            children: const [
              DashboardScreen(),
              LearnScreen(),
              MentorScreen(),
            ],
          ),

          // ── Guided-mode overlay (lives at shell level) ───────────────────
          if (guidedState.isActive)
            const GuidedModeOverlay(),

          // ── Proactive mentor avatar overlay ──────────────────────────────
          const MentorAvatar(),
        ],
      ),

      // ── Bottom navigation bar ──────────────────────────────────────────
      bottomNavigationBar: ListenableBuilder(
        listenable: mentor,
        builder: (context, _) => NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          ref.read(shellTabIndexProvider.notifier).set(i);
        },
        backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
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
            selectedIcon: const Icon(Icons.home_rounded, color: Color(0xFF1A73E8)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: guidedState.isActive && _selectedIndex != 1,
              backgroundColor: const Color(0xFFB3261E),
              child: Icon(
                Icons.school_outlined,
                color: _selectedIndex == 1
                    ? accent
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            selectedIcon:
                const Icon(Icons.school_rounded, color: Color(0xFF1A73E8)),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  mentor.hasPendingNotification && _selectedIndex != 2,
              backgroundColor: mentorAccent,
              child: Icon(
                Icons.psychology_alt_outlined,
                color: _selectedIndex == 2
                    ? mentorAccent
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            selectedIcon:
                const Icon(Icons.psychology_alt, color: Color(0xFF7C4DFF)),
            label: 'AI Mentor',
          ),
        ],
      ),
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
