import 'package:flutter/material.dart';

/// A row of tappable suggestion chips shown when the Mentor chat is empty.
///
/// Helps the user get started without having to think of what to ask.
class SuggestedPrompts extends StatelessWidget {
  final void Function(String prompt) onPromptTap;

  const SuggestedPrompts({super.key, required this.onPromptTap});

  static const _suggestions = [
    'How do I connect via SSH?',
    'What is KML?',
    'Explain the LG rig architecture',
    'How do I place a 3D model?',
    'What learning modules are available?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF7C4DFF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Try asking…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Chips ─────────────────────────────────────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _suggestions.map((prompt) {
            return ActionChip(
              label: Text(
                prompt,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              backgroundColor: isDark
                  ? const Color(0xFF2A2A2E)
                  : const Color(0xFFF0F0F5),
              side: BorderSide(
                color: accent.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => onPromptTap(prompt),
            );
          }).toList(),
        ),
      ],
    );
  }
}
