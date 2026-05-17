import 'dart:async';

import 'package:fllama/fllama.dart';

import '../prompts/prompt_asset.dart';
import '../state/conversation_state.dart';
import 'llm_engine.dart';

class FllamaEngine implements LlmEngine {
  String? _modelPath;
  int? _contextLength;
  int? _activeRequestId;

  @override
  bool get isLoaded => _modelPath != null;

  @override
  Future<void> load({
    required String modelPath,
    required int contextLength,
  }) async {
    _modelPath = modelPath;
    _contextLength = contextLength;
  }

  @override
  Future<void> unload() async {
    cancel();
    _modelPath = null;
    _contextLength = null;
  }

  @override
  Stream<String> generate({
    required PromptAsset prompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) {
    final modelPath = _modelPath;
    final contextLength = _contextLength;
    if (modelPath == null || contextLength == null) {
      throw StateError('FllamaEngine.generate called before load()');
    }

    final controller = StreamController<String>();

    final messages = <Message>[
      Message(Role.system, prompt.systemInstruction),
      for (final turn in history)
        Message(
          turn.role == ChatRole.user ? Role.user : Role.assistant,
          turn.text,
        ),
      Message(Role.user, userMessage),
    ];

    final request = OpenAiRequest(
      modelPath: modelPath,
      contextSize: contextLength,
      maxTokens: prompt.generation.maxTokens,
      temperature: prompt.generation.temperature,
      topP: prompt.generation.topP,
      frequencyPenalty: 0.0,
      presencePenalty: prompt.generation.repeatPenalty - 1.0,
      messages: messages,
      numGpuLayers: 99,
      logger: null,
    );

    String previous = '';

    fllamaChat(request, (chunk, done) {
      final delta = chunk.startsWith(previous)
          ? chunk.substring(previous.length)
          : chunk;
      previous = chunk;
      if (delta.isNotEmpty) {
        controller.add(delta);
      }
      if (done) {
        controller.close();
      }
    }).then((requestId) {
      _activeRequestId = requestId;
    }).catchError((Object error, StackTrace stack) {
      controller.addError(error, stack);
      controller.close();
    });

    controller.onCancel = () {
      cancel();
    };

    return controller.stream;
  }

  @override
  void cancel() {
    final id = _activeRequestId;
    if (id != null) {
      try {
        fllamaCancelInference(id);
      } catch (_) {}
      _activeRequestId = null;
    }
  }
}
