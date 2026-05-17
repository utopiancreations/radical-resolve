import 'dart:async';
import 'dart:typed_data';

import 'tts_engine.dart';

/// Kokoro-82M TTS engine — Apache 2.0 open-source TTS, ~140 MB ONNX model,
/// 24 kHz output, multiple voices.
///
/// SCOPE-ONLY STUB. The real implementation needs:
///   1. ONNX Runtime native binding via `onnxruntime` pub package. iOS build
///      links against the prebuilt `onnxruntime.xcframework`.
///   2. Phonemizer: Kokoro consumes phoneme IDs, not raw text. The Python
///      reference uses `misaki`. For Flutter we need either:
///        - A bundled g2p model (small) called via ONNX, or
///        - A Dart port of the espeak-ng phonemizer rules for English, or
///        - A platform channel into Apple's `AVSpeechSynthesizer` for
///          phonemization only (then Kokoro renders the audio).
///      Cleanest: ship a tiny ONNX g2p model alongside Kokoro.
///   3. Voice embeddings: each Kokoro voice is a separate .pt/.bin file
///      (~50 KB). Bundle the ~10 voices we want or fetch on demand from R2.
///   4. Streaming: Kokoro's decoder is a fixed-length GAN — chunk by sentence,
///      not by token, to start playback ~1s after the LLM begins generating.
class KokoroEngine implements TtsEngine {
  KokoroEngine({
    required this.modelAssetPath,
    required this.voicesDir,
  });

  final String modelAssetPath;
  final String voicesDir;

  VoiceId _voice = 'af_bella';
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  VoiceId get currentVoice => _voice;

  @override
  Future<void> load({required VoiceId voice}) async {
    _voice = voice;
    // TODO: create ONNX inference session from modelAssetPath
    // TODO: load voice embedding from voicesDir/$voice.bin
    // TODO: initialize phonemizer (separate ONNX session or platform channel)
    _loaded = true;
  }

  @override
  Future<void> setVoice(VoiceId voice) async {
    _voice = voice;
    // TODO: swap voice embedding without reloading the model graph
  }

  @override
  Stream<TtsAudioChunk> speak(String text) async* {
    if (!_loaded) {
      throw StateError('KokoroEngine.speak called before load()');
    }
    // TODO: phonemize text → phoneme IDs
    // TODO: split into sentences (~12-25 phonemes per chunk for low latency)
    // TODO: per sentence: run ONNX session, get PCM, yield TtsAudioChunk
    yield TtsAudioChunk(
      pcm: Int16List(0),
      sampleRate: 24000,
      isFinal: true,
    );
  }

  @override
  void cancel() {
    // TODO: abort in-flight ONNX session (or just stop yielding chunks)
  }

  @override
  Future<void> unload() async {
    // TODO: release ONNX session resources
    _loaded = false;
  }
}
