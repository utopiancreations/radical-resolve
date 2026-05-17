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

  static const ModelConfig gemma4E4bRadicalResolveV1 = ModelConfig(
    id: 'gemma-4-e4b-radical-resolve',
    version: '1.0.0',
    fileName: 'gemma-4-e4b-radical-resolve-v1-q5_k_m.gguf',
    downloadUrl:
        'https://models.radicalresolve.app/gemma-4-e4b-radical-resolve-v1-q5_k_m.gguf',
    sha256: 'TBD_FILLED_AFTER_TRAINING_CONVERT',
    sizeBytes: 3300000000,
    contextLength: 4096,
    gpuLayers: 99,
  );
}
