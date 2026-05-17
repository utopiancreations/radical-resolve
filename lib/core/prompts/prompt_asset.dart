import 'package:flutter/foundation.dart';

@immutable
class GenerationConfig {
  const GenerationConfig({
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.maxTokens,
    required this.repeatPenalty,
    required this.stopSequences,
  });

  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final double repeatPenalty;
  final List<String> stopSequences;

  factory GenerationConfig.fromJson(Map<String, dynamic> json) =>
      GenerationConfig(
        temperature: (json['temperature'] as num).toDouble(),
        topP: (json['topP'] as num).toDouble(),
        topK: (json['topK'] as num).toInt(),
        maxTokens: (json['maxTokens'] as num).toInt(),
        repeatPenalty: (json['repeatPenalty'] as num).toDouble(),
        stopSequences:
            (json['stopSequences'] as List<dynamic>).cast<String>(),
      );
}

@immutable
class PromptAsset {
  const PromptAsset({
    required this.schemaVersion,
    required this.id,
    required this.version,
    required this.mode,
    required this.title,
    required this.systemInstruction,
    required this.openingMessage,
    required this.generation,
    required this.behaviorContract,
  });

  final int schemaVersion;
  final String id;
  final String version;
  final String mode;
  final String title;
  final String systemInstruction;
  final String openingMessage;
  final GenerationConfig generation;
  final Map<String, dynamic> behaviorContract;

  factory PromptAsset.fromJson(Map<String, dynamic> json) => PromptAsset(
        schemaVersion: json['schemaVersion'] as int,
        id: json['id'] as String,
        version: json['version'] as String,
        mode: json['mode'] as String,
        title: json['title'] as String,
        systemInstruction: json['systemInstruction'] as String,
        openingMessage: json['openingMessage'] as String,
        generation: GenerationConfig.fromJson(
          json['generation'] as Map<String, dynamic>,
        ),
        behaviorContract:
            (json['behaviorContract'] as Map<String, dynamic>?) ?? const {},
      );
}
