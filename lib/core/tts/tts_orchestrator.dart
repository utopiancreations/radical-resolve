import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inference/inference_service.dart';
import '../state/conversation_state.dart';
import 'tts_engine.dart';

/// Subscribes to the LLM streaming text and feeds the TTS engine
/// sentence-by-sentence so audio playback starts ~1s after generation begins,
/// not after the full reply is done.
///
/// Sentence boundary heuristic: end-of-sentence punctuation followed by a
/// space or end-of-string. Conservative — we'd rather wait one extra word
/// than truncate a sentence mid-clause and create a stutter at playback.
class TtsOrchestrator {
  TtsOrchestrator({required this.engine});

  final TtsEngine engine;

  String _buffered = '';
  StreamSubscription<ConversationState>? _convoSub;

  static final RegExp _sentenceEnd = RegExp(r'([.!?])\s');

  void attach(WidgetRef ref) {
    String lastSeen = '';
    _convoSub = ref.listenManual<ConversationState>(
      inferenceServiceProvider,
      (prev, next) {
        if (!next.isGenerating || !engine.isLoaded) {
          lastSeen = '';
          _buffered = '';
          return;
        }
        final current = next.streamingAssistantText;
        if (current.length < lastSeen.length) {
          lastSeen = '';
        }
        final delta = current.substring(lastSeen.length);
        lastSeen = current;
        _buffered += delta;
        _flushCompleteSentences();
      },
      fireImmediately: false,
    ).read;
  }

  void _flushCompleteSentences() {
    while (true) {
      final match = _sentenceEnd.firstMatch(_buffered);
      if (match == null) return;
      final cut = match.end;
      final sentence = _buffered.substring(0, cut).trim();
      _buffered = _buffered.substring(cut);
      if (sentence.isNotEmpty) {
        engine.speak(sentence).listen((_) {
          // Audio playback is wired separately (audio_player_service).
        });
      }
    }
  }

  void dispose() {
    _convoSub?.cancel();
    _convoSub = null;
    engine.cancel();
  }
}

final ttsEngineProvider = Provider<TtsEngine>((ref) {
  throw UnimplementedError(
    'Bind to KokoroEngine in main.dart after voice assets are downloaded',
  );
});

final ttsOrchestratorProvider = Provider<TtsOrchestrator>((ref) {
  final engine = ref.watch(ttsEngineProvider);
  return TtsOrchestrator(engine: engine);
});
