import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prompt_asset.dart';

class PromptRegistry {
  PromptRegistry._(this._byId);

  final Map<String, PromptAsset> _byId;

  PromptAsset byId(String id) {
    final asset = _byId[id];
    if (asset == null) {
      throw StateError('No prompt asset registered for id "$id"');
    }
    return asset;
  }

  Iterable<PromptAsset> get all => _byId.values;

  static const List<String> _bundledAssetPaths = [
    'assets/prompts/sos_grounding.json',
    'assets/prompts/analytical_planner.json',
    'assets/prompts/lesson_companion.json',
  ];

  static Future<PromptRegistry> loadBundled() async {
    final map = <String, PromptAsset>{};
    for (final path in _bundledAssetPaths) {
      final raw = await rootBundle.loadString(path);
      final asset = PromptAsset.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      map[asset.id] = asset;
    }
    return PromptRegistry._(map);
  }
}

final promptRegistryProvider = FutureProvider<PromptRegistry>(
  (ref) => PromptRegistry.loadBundled(),
);
