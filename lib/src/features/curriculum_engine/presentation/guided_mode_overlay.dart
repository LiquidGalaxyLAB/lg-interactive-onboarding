import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/learning_module.dart';

/// The floating instructional overlay that appears during guided mode.
///
/// Rendered as an [OverlayEntry] by [GuidedModeController] so it persists
/// across route transitions within the navigation shell.
///
/// Layout:
/// - A semi-transparent scrim covers the whole screen (pointer events pass
///   through so the user can still interact with the underlying UI).
/// - A slide-up card at the bottom shows step instructions, progress, and
///   Skip / Exit controls.
class GuidedModeOverlay extends ConsumerStatefulWidget {
  const GuidedModeOverlay({super.key});

  @override
  ConsumerState<GuidedModeOverlay> createState() => _GuidedModeOverlayState();
}

class _GuidedModeOverlayState extends ConsumerState<GuidedModeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guidedModeControllerProvider);

    // Only show during active running/advancing phases
    if (!state.isActive ||
        state.phase == GuidedModePhase.completed ||
        state.phase == GuidedModePhase.cancelled ||
        state.phase == GuidedModePhase.idle) {
      return const SizedBox.shrink();
    }

    final step = state.currentStep;
    final module = state.activeModule;
    if (step == null || module == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Scrim (pointer events pass through) ──────────────────────────
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),

          // ── Backdrop blur (subtle) ────────────────────────────────────────
          IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: Container(color: Colors.transparent),
            ),
          ),

          // ── Instruction card (slides up from bottom) ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: _InstructionCard(
                module: module,
                step: step,
                stepIndex: state.currentStepIndex,
                totalSteps: state.totalSteps,
                phaseMessage: state.phaseMessage,
                isDark: isDark,
                onSkip: () => ref
                    .read(guidedModeControllerProvider.notifier)
                    .skipCurrentStep(),
                onExit: () => ref
                    .read(guidedModeControllerProvider.notifier)
                    .cancelModule(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Instruction Card ─────────────────────────────────────────────────────────

class _InstructionCard extends StatelessWidget {
  final LearningModule module;
  final ModuleStep step;
  final int stepIndex;
  final int totalSteps;
  final String? phaseMessage;
  final bool isDark;
  final VoidCallback onSkip;
  final VoidCallback onExit;

  const _InstructionCard({
    required this.module,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.phaseMessage,
    required this.isDark,
    required this.onSkip,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1F33) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    const accent = Color(0xFF6C5CE7);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: border, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ─────────────────────────────────────────────
                Row(
                  children: [
                    // Module icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          module.iconEmoji ?? '📚',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'Step ${stepIndex + 1} of $totalSteps',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress ring
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: totalSteps > 0
                                ? (stepIndex + 1) / totalSteps
                                : 0,
                            strokeWidth: 3,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.black12,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(accent),
                          ),
                          Center(
                            child: Text(
                              '${stepIndex + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Step instruction ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    step.instruction,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.55,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),

                // ── Phase message (timeout warning) ─────────────────────────
                if (phaseMessage != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.amber.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phaseMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.amber.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // ── Action buttons ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: onExit,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Exit Module'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white38 : Colors.black38,
                        textStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Verification pulse indicator
                    Row(
                      children: [
                        _PulseDot(isDark: isDark),
                        const SizedBox(width: 6),
                        Text(
                          'Waiting for action...',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: onSkip,
                      icon: const Icon(Icons.skip_next_rounded, size: 16),
                      label: const Text('Skip'),
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                        textStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pulse Dot ────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final bool isDark;
  const _PulseDot({required this.isDark});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF6C5CE7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
