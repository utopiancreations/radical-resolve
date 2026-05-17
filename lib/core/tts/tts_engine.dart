import 'dart:typed_data';

/// PCM audio chunk emitted by a TtsEngine.
class TtsAudioChunk {
  const TtsAudioChunk({
    required this.pcm,
    required this.sampleRate,
    required this.isFinal,
  });

  /// Mono int16 PCM samples.
  final Int16List pcm;

  /// Sample rate in Hz (Kokoro emits 24000).
  final int sampleRate;

  /// True when this is the last chunk for the current `speak` call.
  final bool isFinal;
}

/// Voice identifier — one of the bundled Kokoro voices.
/// Naming follows Kokoro's voice catalog (e.g. af_bella, am_michael, bf_emma).
typedef VoiceId = String;

/// Abstract interface so we can swap engines (Kokoro now, F5-TTS or Piper
/// later) without touching the UI or the streaming orchestrator.
abstract class TtsEngine {
  /// Load the model weights into memory and prepare the inference session.
  Future<void> load({required VoiceId voice});

  /// Hot-swap voice without reloading the model graph.
  Future<void> setVoice(VoiceId voice);

  bool get isLoaded;

  VoiceId get currentVoice;

  /// Synthesize [text] into PCM audio chunks. Stream so playback can start
  /// before the full waveform is generated (matters most for long passages).
  Stream<TtsAudioChunk> speak(String text);

  /// Cancel any in-flight synthesis.
  void cancel();

  Future<void> unload();
}
