/// Kokoro-82M voice asset configuration. The model graph is one ONNX file
/// (~140 MB) shared across voices; each voice is a small embedding file
/// (~50 KB) so we can ship multiple voices cheaply.
class VoiceAsset {
  const VoiceAsset({
    required this.id,
    required this.label,
    required this.description,
    required this.embeddingUrl,
    required this.embeddingSha256,
  });

  final String id;
  final String label;
  final String description;
  final String embeddingUrl;
  final String embeddingSha256;
}

class VoiceConfig {
  const VoiceConfig._();

  static const String kokoroModelUrl =
      'https://models.radicalresolve.app/kokoro-82m-v1.onnx';
  static const String kokoroModelSha256 = 'TBD_AFTER_R2_UPLOAD';
  static const int kokoroModelSizeBytes = 145000000;

  static const String defaultVoiceId = 'af_bella';

  static const List<VoiceAsset> bundledVoices = [
    VoiceAsset(
      id: 'af_bella',
      label: 'Bella',
      description: 'Warm, grounded American female — default for SOS mode',
      embeddingUrl: 'https://models.radicalresolve.app/voices/af_bella.bin',
      embeddingSha256: 'TBD_AFTER_R2_UPLOAD',
    ),
    VoiceAsset(
      id: 'af_nicole',
      label: 'Nicole',
      description: 'Soft, intimate American female',
      embeddingUrl: 'https://models.radicalresolve.app/voices/af_nicole.bin',
      embeddingSha256: 'TBD_AFTER_R2_UPLOAD',
    ),
    VoiceAsset(
      id: 'am_michael',
      label: 'Michael',
      description: 'Steady, even-keeled American male',
      embeddingUrl: 'https://models.radicalresolve.app/voices/am_michael.bin',
      embeddingSha256: 'TBD_AFTER_R2_UPLOAD',
    ),
    VoiceAsset(
      id: 'bf_emma',
      label: 'Emma',
      description: 'Calm British female',
      embeddingUrl: 'https://models.radicalresolve.app/voices/bf_emma.bin',
      embeddingSha256: 'TBD_AFTER_R2_UPLOAD',
    ),
  ];
}
