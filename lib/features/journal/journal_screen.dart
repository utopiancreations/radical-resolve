import 'package:flutter/material.dart';

import '../../core/state/app_mode.dart';
import '../../widgets/chat_mode_scaffold.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatModeScaffold(
      mode: AppMode.journal,
      title: 'Journal',
      hintText: "What's sitting with you?",
      theme: ChatTheme.warm,
    );
  }
}
