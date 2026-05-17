import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prompts/prompt_asset.dart';
import '../prompts/prompt_registry.dart';
import '../state/app_mode.dart';
import '../state/app_mode_controller.dart';
import '../state/conversation_state.dart';
import 'fllama_engine.dart';
import 'llm_engine.dart';

class InferenceService extends StateNotifier<ConversationState> {
  InferenceService({
    required LlmEngine engine,
    required PromptRegistry registry,
    required Stream<AppMode> modeStream,
    required AppMode initialMode,
  })  : _engine = engine,
        _registry = registry,
        super(_seedFor(registry, initialMode)) {
    _modeSub = modeStream.listen(_onModeChanged);
  }

  final LlmEngine _engine;
  final PromptRegistry _registry;
  late final StreamSubscription<AppMode> _modeSub;
  StreamSubscription<String>? _activeGenSub;

  static ConversationState _seedFor(PromptRegistry registry, AppMode mode) {
    final asset = registry.byId(mode.promptId);
    return ConversationState(
      promptId: asset.id,
      turns: [
        ChatTurn(role: ChatRole.assistant, text: asset.openingMessage),
      ],
    );
  }

  void _onModeChanged(AppMode mode) {
    _cancelActive();
    final asset = _registry.byId(mode.promptId);
    if (asset.id == state.promptId) return;
    state = _seedFor(_registry, mode);
  }

  Future<void> sendUserMessage(String text) async {
    if (text.trim().isEmpty || state.isGenerating || !_engine.isLoaded) return;

    final asset = _registry.byId(state.promptId);
    final updatedTurns = [
      ...state.turns,
      ChatTurn(role: ChatRole.user, text: text),
    ];
    state = state.copyWith(
      turns: updatedTurns,
      streamingAssistantText: '',
      isGenerating: true,
    );

    final buffer = StringBuffer();
    final stream = _engine.generate(
      prompt: asset,
      history: updatedTurns.sublist(0, updatedTurns.length - 1),
      userMessage: text,
    );

    final completer = Completer<void>();
    _activeGenSub = stream.listen(
      (delta) {
        buffer.write(delta);
        state = state.copyWith(streamingAssistantText: buffer.toString());
      },
      onError: (Object error, StackTrace stack) {
        state = state.copyWith(
          isGenerating: false,
          streamingAssistantText: '',
          turns: [
            ...state.turns,
            ChatTurn(
              role: ChatRole.assistant,
              text: 'I had trouble responding just now. Try once more?',
            ),
          ],
        );
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        state = state.copyWith(
          isGenerating: false,
          streamingAssistantText: '',
          turns: [
            ...state.turns,
            ChatTurn(role: ChatRole.assistant, text: buffer.toString()),
          ],
        );
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
  }

  void _cancelActive() {
    _activeGenSub?.cancel();
    _activeGenSub = null;
    _engine.cancel();
  }

  @override
  void dispose() {
    _modeSub.cancel();
    _cancelActive();
    super.dispose();
  }
}

final llmEngineProvider = Provider<LlmEngine>((ref) => FllamaEngine());

final inferenceServiceProvider =
    StateNotifierProvider<InferenceService, ConversationState>((ref) {
  final registry = ref.watch(promptRegistryProvider).requireValue;
  final engine = ref.watch(llmEngineProvider);
  final modeNotifier = ref.watch(appModeControllerProvider.notifier);
  final initialMode = ref.read(appModeControllerProvider);
  final modeStream = Stream<AppMode>.multi((controller) {
    final remove = modeNotifier.addListener(controller.add);
    controller.onCancel = remove;
  });
  return InferenceService(
    engine: engine,
    registry: registry,
    modeStream: modeStream,
    initialMode: initialMode,
  );
});
