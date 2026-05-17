import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../config/model_config.dart';

/// Where the on-device GGUF lives and how the app finds it.
///
/// Two sources are supported, checked in order:
/// 1. **Sideloaded** at `<Documents>/manual_models/<filename>`. User drops
///    the file there via Xcode "Devices and Simulators → Files" or the iOS
///    Files app (Documents is visible there if `UIFileSharingEnabled` and
///    `LSSupportsOpeningDocumentsInPlace` are set in Info.plist). Bypasses
///    the R2 download flow and the sha check — for local dev only.
/// 2. **Downloaded** at `<ApplicationSupport>/models/<filename>`. Managed by
///    [ModelDownloader] — verified by size + sha256.
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

  Future<Directory> _sideloadDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/manual_models');
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

  Future<File> sideloadFile() async {
    final dir = await _sideloadDir();
    return File('${dir.path}/${config.fileName}');
  }

  /// Returns the file path the engine should load from, preferring a
  /// sideloaded file if present. Returns null if neither source has it yet.
  Future<File?> resolveInstalledFile() async {
    final sideload = await sideloadFile();
    if (await sideload.exists() && await sideload.length() > 0) {
      return sideload;
    }
    final target = await targetFile();
    if (await target.exists() && await target.length() == config.sizeBytes) {
      return target;
    }
    return null;
  }

  Future<bool> isInstalled() async => (await resolveInstalledFile()) != null;

  Future<bool> isSideloaded() async {
    final sideload = await sideloadFile();
    return await sideload.exists() && await sideload.length() > 0;
  }
}
