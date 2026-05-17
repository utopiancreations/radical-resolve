import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant }

@immutable
class ChatTurn {
  const ChatTurn({required this.role, required this.text});
  final ChatRole role;
  final String text;
}

@immutable
class ConversationState {
  const ConversationState({
    required this.promptId,
    required this.turns,
    this.streamingAssistantText = '',
    this.isGenerating = false,
  });

  final String promptId;
  final List<ChatTurn> turns;
  final String streamingAssistantText;
  final bool isGenerating;

  ConversationState copyWith({
    String? promptId,
    List<ChatTurn>? turns,
    String? streamingAssistantText,
    bool? isGenerating,
  }) =>
      ConversationState(
        promptId: promptId ?? this.promptId,
        turns: turns ?? this.turns,
        streamingAssistantText:
            streamingAssistantText ?? this.streamingAssistantText,
        isGenerating: isGenerating ?? this.isGenerating,
      );

  static const ConversationState empty = ConversationState(
    promptId: '',
    turns: [],
  );
}
