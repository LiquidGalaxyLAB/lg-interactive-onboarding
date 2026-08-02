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
    // Determine if the accent color is light (like LG Yellow) or dark (like LG Blue/Red/Green)
    // to ensure the text and icons contrast perfectly against the solid background.
    final textColor = widget.accentColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    final subTextColor = textColor.withValues(alpha: 0.8);

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
          color: widget.accentColor, // Solid LG Color
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!_pressed)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: widget.isDark ? 0.2 : 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.15), // Subtle tint over the solid color
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                size: 28,
                color: textColor,
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
