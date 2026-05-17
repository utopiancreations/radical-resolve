import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/model_config.dart';
import '../model_download/model_downloader.dart';
import '../prompts/prompt_registry.dart';
import 'inference_service.dart';

final engineReadyProvider = FutureProvider<void>((ref) async {
  await ref.watch(promptRegistryProvider.future);
  final modelFile = await ref.watch(modelInstallProvider.future);
  final engine = ref.read(llmEngineProvider);
  if (!engine.isLoaded) {
    await engine.load(
      modelPath: modelFile.path,
      contextLength: ModelConfig.radicalResolveV3.contextLength,
    );
  }
});
