import '../prompts/prompt_asset.dart';
import '../state/conversation_state.dart';

abstract class LlmEngine {
  Future<void> load({required String modelPath, required int contextLength});

  Future<void> unload();

  bool get isLoaded;

  Stream<String> generate({
    required PromptAsset prompt,
    required List<ChatTurn> history,
    required String userMessage,
  });

  void cancel();
}
