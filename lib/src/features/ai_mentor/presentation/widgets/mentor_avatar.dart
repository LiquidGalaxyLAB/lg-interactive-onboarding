import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/app_shell.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';

/// A floating animated avatar that slides in from the bottom-right corner
/// when a proactive trigger fires — nudging the user to open the AI Mentor.
///
/// Tapping the avatar navigates to the Mentor tab (index 2) and clears
/// the pending notification.
class MentorAvatar extends ConsumerStatefulWidget {
  const MentorAvatar({super.key});

  @override
  ConsumerState<MentorAvatar> createState() => _MentorAvatarState();
}

class _MentorAvatarState extends ConsumerState<MentorAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mentor = ref.read(mentorServiceProvider);
    final tabIndex = ref.watch(shellTabIndexProvider);

    return ListenableBuilder(
      listenable: mentor,
      builder: (context, _) {
    final hasPending = mentor.hasPendingNotification;

    // Show the avatar only when:
    //  - There is a pending notification
    //  - The user is NOT already on the Mentor tab
    //  - The avatar hasn't been manually dismissed
    final shouldShow = hasPending && tabIndex != 2 && !_dismissed;

    if (shouldShow) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    // Reset the dismissed flag when the notification is cleared.
    if (!hasPending) {
      _dismissed = false;
    }

    return Positioned(
      bottom: 90, // Above the bottom nav bar
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildAvatar(context),
        ),
      ),
    );
      },
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF7C4DFF);

    return GestureDetector(
      onTap: _onTap,
      onHorizontalDragEnd: (_) => _dismiss(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Speech bubble ──────────────────────────────────────────────
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Need some help? 🤔\nTap to chat with me!',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Avatar circle ──────────────────────────────────────────────
          _PulsingAvatar(accent: accent),
        ],
      ),
    );
  }

  void _onTap() {
    // Navigate to Mentor tab.
    ref.read(shellTabIndexProvider.notifier).set(2);
    ref.read(mentorServiceProvider).clearNotification();
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    _controller.reverse();
  }
}

/// A pulsing circle avatar that draws attention to the floating mentor nudge.
class _PulsingAvatar extends StatefulWidget {
  final Color accent;

  const _PulsingAvatar({required this.accent});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              widget.accent,
              widget.accent.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.psychology_alt,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
