import 'package:flutter/material.dart';

import '../../core/state/app_mode.dart';
import '../../widgets/chat_mode_scaffold.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatModeScaffold(
      mode: AppMode.lesson,
      title: 'Lessons',
      hintText: 'Ask a question about the lesson…',
      theme: ChatTheme.warm,
    );
  }
}
