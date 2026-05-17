class ModelConfig {
  const ModelConfig({
    required this.id,
    required this.version,
    required this.fileName,
    required this.downloadUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.contextLength,
    required this.gpuLayers,
  });

  final String id;
  final String version;
  final String fileName;
  final String downloadUrl;
  final String sha256;
  final int sizeBytes;
  final int contextLength;
  final int gpuLayers;

  /// Radical Resolve v3 — Gemma 4 E4B fine-tuned on the scrubbed
  /// radical_resolve_v3 corpus (8,376 samples, no first-person fabrications).
  /// Produced 2026-05-17 via training/train_radical_resolve_e4b_v3.py +
  /// merge + llama.cpp convert + Q5_K_M quantize.
  static const ModelConfig radicalResolveV3 = ModelConfig(
    id: 'radical-resolve-gemma-4-e4b',
    version: '3.0.0',
    fileName: 'radical-resolve-v3-Q5_K_M.gguf',
    downloadUrl:
        'https://models.radicalresolve.app/radical-resolve-v3-Q5_K_M.gguf',
    sha256:
        'd924d2f08131eb71cf3f911d0703c5a2809aea348fbd28ec0f29462ea3a5cff7',
    sizeBytes: 5762912576,
    contextLength: 4096,
    gpuLayers: 99,
  );
}
