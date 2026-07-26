import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// A styled chat message bubble for the AI Mentor conversation.
///
/// User messages are right-aligned with the accent color.
/// AI messages are left-aligned with a subtle surface color.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── Colors ──────────────────────────────────────────────────────────────
    const accent = Color(0xFF7C4DFF); // Deep purple accent for AI branding
    final userBubbleColor = accent;
    final aiBubbleColor = isDark
        ? const Color(0xFF2A2A2E)
        : const Color(0xFFF0F0F5);
    final userTextColor = Colors.white;
    final aiTextColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── AI avatar ────────────────────────────────────────────────────
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: accent.withValues(alpha: 0.15),
              child: const Icon(
                Icons.psychology_alt,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // ── Bubble ────────────────────────────────────────────────────────
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? userBubbleColor : aiBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? SelectableText(
                      text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        color: userTextColor,
                      ),
                    )
                  : MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: aiTextColor,
                        ),
                        h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: aiTextColor),
                        h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: aiTextColor),
                        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: aiTextColor),
                        listBullet: TextStyle(color: aiTextColor),
                        code: TextStyle(
                          backgroundColor: isDark ? const Color(0xFF1E1E20) : const Color(0xFFE0E0E5),
                          color: aiTextColor,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E20) : const Color(0xFFE0E0E5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
          ),

          // ── User spacing ─────────────────────────────────────────────────
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
