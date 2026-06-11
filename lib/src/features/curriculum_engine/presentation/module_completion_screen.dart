import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/learning_module.dart';
import 'package:lg_interactive_onboarding/src/features/curriculum_engine/providers/curriculum_providers.dart';

/// Full-screen celebration shown when a guided module is completed.
///
/// Displayed as a push route so the user can navigate back to the Learn tab
/// or immediately start the next module.
class ModuleCompletionScreen extends ConsumerStatefulWidget {
  final LearningModule completedModule;

  const ModuleCompletionScreen({
    super.key,
    required this.completedModule,
  });

  @override
  ConsumerState<ModuleCompletionScreen> createState() =>
      _ModuleCompletionScreenState();
}

class _ModuleCompletionScreenState extends ConsumerState<ModuleCompletionScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiCtrl;
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Mark module completed in the status notifier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(curriculumStatusProvider.notifier)
          .setStatus(widget.completedModule.id, ModuleStatus.completed);
      ref.read(guidedModeControllerProvider.notifier).acknowledgeCompletion();
    });

    // Generate confetti particles
    final rng = Random();
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.6,
        speed: 0.3 + rng.nextDouble() * 0.7,
        color: _confettiColors[rng.nextInt(_confettiColors.length)],
        size: 4 + rng.nextDouble() * 6,
        rotationSpeed: rng.nextDouble() * 2 - 1,
      ));
    }

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.elasticOut,
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scaleCtrl.forward();
    });
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  static const _confettiColors = [
    Color(0xFF6C5CE7),
    Color(0xFF00D2FF),
    Color(0xFFFD79A8),
    Color(0xFF55EFC4),
    Color(0xFFFDCB6E),
    Color(0xFFE17055),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final modules = ref.watch(curriculumModulesProvider);
    final currentIndex =
        modules.indexWhere((m) => m.id == widget.completedModule.id);
    final nextModule = currentIndex >= 0 && currentIndex < modules.length - 1
        ? modules[currentIndex + 1]
        : null;
    final canStartNext = nextModule?.status == ModuleStatus.available;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          // ── Confetti animation ─────────────────────────────────────────────
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiCtrl.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C5CE7)
                                  .withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.completedModule.iconEmoji ?? '✅',
                            style: const TextStyle(fontSize: 42),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'Module Complete!',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      widget.completedModule.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // CTA buttons
                    if (canStartNext && nextModule != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ref
                                .read(guidedModeControllerProvider.notifier)
                                .startModule(nextModule);
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text('Start: ${nextModule.title}'),
                        ),
                      ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to Learn'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confetti Particles ───────────────────────────────────────────────────────

class _ConfettiParticle {
  final double x;
  final double delay;
  final double speed;
  final Color color;
  final double size;
  final double rotationSpeed;

  const _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0) * p.speed;
      if (t <= 0) continue;

      final x = p.x * size.width;
      final y = t * (size.height + 40) - 20;
      final opacity = (1.0 - t * 0.8).clamp(0.0, 1.0);
      final angle = t * p.rotationSpeed * 6;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.4,
          ),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
