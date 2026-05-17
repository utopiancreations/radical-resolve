import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inference/inference_service.dart';
import '../../core/state/app_mode_controller.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convo = ref.watch(inferenceServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1116),
        foregroundColor: Colors.white,
        title: const Text('SOS — Grounding'),
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
                padding: const EdgeInsets.all(16),
                itemCount: convo.turns.length +
                    (convo.streamingAssistantText.isEmpty ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index < convo.turns.length) {
                    final turn = convo.turns[index];
                    return _Bubble(
                      text: turn.text,
                      isAssistant: turn.role.name == 'assistant',
                    );
                  }
                  return _Bubble(
                    text: convo.streamingAssistantText,
                    isAssistant: true,
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type a word, anything…',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Color(0xFF1A1F26),
                        border: OutlineInputBorder(
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
                        : () {
                            final text = _textController.text;
                            _textController.clear();
                            ref
                                .read(inferenceServiceProvider.notifier)
                                .sendUserMessage(text);
                          },
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isAssistant});
  final String text;
  final bool isAssistant;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isAssistant
              ? const Color(0xFF1A1F26)
              : const Color(0xFF2E4A8B),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
