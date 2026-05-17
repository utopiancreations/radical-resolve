import 'package:flutter/material.dart';

import '../../core/state/app_mode.dart';
import '../../widgets/chat_mode_scaffold.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatModeScaffold(
      mode: AppMode.chat,
      title: 'Open Chat',
      hintText: "What's on your mind?",
      theme: ChatTheme.warm,
    );
  }
}
