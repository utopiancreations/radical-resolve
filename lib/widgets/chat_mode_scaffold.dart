import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/inference/inference_service.dart';
import '../core/state/app_mode.dart';
import '../core/state/app_mode_controller.dart';
import 'chat_bubble.dart';

/// Shared shell for any AppMode that's a chat surface (SOS, journal,
/// lessons, chat). Handles mode entry on push, mode exit on pop, the
/// streaming conversation list, and the send-message input row.
///
/// Each feature screen just wraps this with its own [mode], [title], and
/// [theme] — the conversation state, prompt selection, and engine plumbing
/// are all handled by InferenceService and the AppMode controller.
class ChatModeScaffold extends ConsumerStatefulWidget {
  const ChatModeScaffold({
    super.key,
    required this.mode,
    required this.title,
    required this.hintText,
    this.theme = ChatTheme.warm,
  });

  final AppMode mode;
  final String title;
  final String hintText;
  final ChatTheme theme;

  @override
  ConsumerState<ChatModeScaffold> createState() => _ChatModeScaffoldState();
}

class _ChatModeScaffoldState extends ConsumerState<ChatModeScaffold> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(appModeControllerProvider.notifier);
      switch (widget.mode) {
        case AppMode.sos:
          controller.enterSos();
          break;
        case AppMode.journal:
          controller.enterJournal();
          break;
        case AppMode.lesson:
          controller.enterLesson();
          break;
        case AppMode.chat:
          controller.enterChat();
          break;
        case AppMode.idle:
          controller.exitToIdle();
          break;
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final convo = ref.watch(inferenceServiceProvider);
    final theme = widget.theme;
    _scrollToBottom();

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        foregroundColor: theme.foreground,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(appModeControllerProvider.notifier).exitToIdle();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: convo.turns.length +
                    (convo.streamingAssistantText.isEmpty ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index < convo.turns.length) {
                    final turn = convo.turns[index];
                    return ChatBubble(
                      text: turn.text,
                      isAssistant: turn.role.name == 'assistant',
                      assistantColor: theme.assistantBubble,
                      userColor: theme.userBubble,
                      textColor: theme.foreground,
                    );
                  }
                  return ChatBubble(
                    text: convo.streamingAssistantText,
                    isAssistant: true,
                    assistantColor: theme.assistantBubble,
                    userColor: theme.userBubble,
                    textColor: theme.foreground,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: theme.foreground),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: convo.isGenerating ? null : _send,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: theme.foreground.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: theme.inputFill,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: convo.isGenerating
                        ? null
                        : () => _send(_textController.text),
                    icon: Icon(
                      convo.isGenerating ? Icons.hourglass_empty : Icons.send,
                      color: theme.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(inferenceServiceProvider.notifier).sendUserMessage(text);
  }
}

@immutable
class ChatTheme {
  const ChatTheme({
    required this.background,
    required this.foreground,
    required this.assistantBubble,
    required this.userBubble,
    required this.inputFill,
  });

  final Color background;
  final Color foreground;
  final Color assistantBubble;
  final Color userBubble;
  final Color inputFill;

  /// Dark, grounding palette — used for SOS where calm is the priority.
  static const ChatTheme dark = ChatTheme(
    background: Color(0xFF0E1116),
    foreground: Colors.white,
    assistantBubble: Color(0xFF1A1F26),
    userBubble: Color(0xFF2E4A8B),
    inputFill: Color(0xFF1A1F26),
  );

  /// Warm, daylight palette — used for journal, lessons, and chat.
  static const ChatTheme warm = ChatTheme(
    background: Color(0xFFF7F3EE),
    foreground: Color(0xFF1F1B16),
    assistantBubble: Color(0xFFEDE4D6),
    userBubble: Color(0xFF7C5CFF),
    inputFill: Color(0xFFEDE4D6),
  );
}
