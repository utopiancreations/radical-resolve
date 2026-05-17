import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../config/model_config.dart';

class ModelStorage {
  ModelStorage(this.config);

  final ModelConfig config;

  Future<Directory> _modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> targetFile() async {
    final dir = await _modelsDir();
    return File('${dir.path}/${config.fileName}');
  }

  Future<File> partFile() async {
    final dir = await _modelsDir();
    return File('${dir.path}/${config.fileName}.part');
  }

  Future<bool> isInstalled() async {
    final file = await targetFile();
    if (!await file.exists()) return false;
    final size = await file.length();
    return size == config.sizeBytes;
  }
}
