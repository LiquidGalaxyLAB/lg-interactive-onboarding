import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/presentation/widgets/chat_bubble.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/presentation/widgets/typing_indicator.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/presentation/widgets/suggested_prompts.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/stt_service.dart';

/// The AI Mentor chat screen — rendered as Tab 2 in the [AppShell].
///
/// Shows a full-screen conversational UI with:
/// - A scrollable message list (user + AI bubbles)
/// - Typing indicator during loading
/// - Suggested prompt chips when the history is empty
/// - Text input bar with send button
/// - TTS toggle + clear history in the app bar
class MentorScreen extends ConsumerStatefulWidget {
  const MentorScreen({super.key});

  @override
  ConsumerState<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends ConsumerState<MentorScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(mentorServiceProvider).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    // Slight delay to let the new message render.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() {
    final stt = ref.read(sttServiceProvider);
    if (stt.isListening) {
      stt.stopListening();
      if (_textController.text.trim().isNotEmpty) {
        _send();
      }
    } else {
      stt.startListening((text) {
        _textController.text = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mentor = ref.read(mentorServiceProvider);
    final stt = ref.read(sttServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF7C4DFF);

    // Clear notification when user is viewing this tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mentor.clearNotification();
    });

    return ListenableBuilder(
      listenable: Listenable.merge([mentor, stt]),
      builder: (context, _) {
    // Auto-scroll when new messages arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFFAFAFC),

      // ── App Bar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology_alt,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Mentor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          // TTS toggle
          IconButton(
            icon: Icon(
              mentor.ttsEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: mentor.ttsEnabled
                  ? accent
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            tooltip: mentor.ttsEnabled ? 'Mute voice' : 'Unmute voice',
            onPressed: () => ref.read(mentorServiceProvider).toggleTts(),
          ),

          // Clear history
          if (mentor.history.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              tooltip: 'Clear chat',
              onPressed: () => _showClearDialog(context),
            ),
          const SizedBox(width: 8),
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // ── Messages ─────────────────────────────────────────────────────
          Expanded(
            child: mentor.history.isEmpty && !mentor.isLoading
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    itemCount: mentor.history.length +
                        (mentor.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Typing indicator at the end
                      if (index == mentor.history.length) {
                        return const TypingIndicator();
                      }

                      final message = mentor.history[index];
                      return ChatBubble(
                        text: message.content,
                        isUser: message.role == 'user',
                        timestamp: message.timestamp,
                      );
                    },
                  ),
          ),

          // ── Input bar ────────────────────────────────────────────────────
          _buildInputBar(isDark, accent, stt),
        ],
      ),
    );
    },
    );
  }

  /// Shows a centered welcome + suggested prompts when chat is empty.
  Widget _buildEmptyState(bool isDark) {
    const accent = Color(0xFF7C4DFF);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated AI icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.15),
                    accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.psychology_alt,
                size: 40,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Hi! I\'m LG Mentor',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about Liquid Galaxy,\nKML, SSH setup, or the app\'s features.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 28),

            SuggestedPrompts(
              onPromptTap: (prompt) {
                _textController.text = prompt;
                _send();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The bottom text input bar with send button.
  Widget _buildInputBar(bool isDark, Color accent, SttService stt) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E20) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              maxLines: 3,
              minLines: 1,
              style: TextStyle(
                fontSize: 14.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Ask LG Mentor…',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A2A2E)
                    : const Color(0xFFF5F5F8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MicButton(
            isDark: isDark,
            isListening: stt.isListening,
            onPressed: _toggleListening,
          ),
          const SizedBox(width: 8),
          _SendButton(accent: accent, onPressed: _send),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'This will remove the entire conversation history. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(mentorServiceProvider).clearHistory();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular send button with gradient fill.
class _SendButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onPressed;

  const _SendButton({required this.accent, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.send_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Circular mic button for Speech-to-Text.
class _MicButton extends StatelessWidget {
  final bool isDark;
  final bool isListening;
  final VoidCallback onPressed;

  const _MicButton({
    required this.isDark,
    required this.isListening,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isListening
                ? Colors.redAccent
                : (isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF5F5F8)),
            boxShadow: isListening
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            color: isListening
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
            size: 20,
          ),
        ),
      ),
    );
  }
}
