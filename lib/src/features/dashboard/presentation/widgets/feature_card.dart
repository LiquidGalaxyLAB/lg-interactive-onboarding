import 'package:flutter/material.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';

class FeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final String? spotlightKey;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    this.spotlightKey,
    required this.onTap,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = widget.isDark ? const Color(0xFF2A2A2D) : Colors.white;
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      key: widget.spotlightKey != null ? GuidedModeController.spotlightKey(widget.spotlightKey!) : null,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.98 : 1.0,
          _pressed ? 0.98 : 1.0,
          1.0,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDark ? Colors.white12 : const Color(0xFFDADCE0),
          ),
          boxShadow: [
            if (!_pressed)
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                size: 28,
                color: widget.accentColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: textColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
