import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/model_config.dart';
import 'model_storage.dart';

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.received,
    required this.total,
    required this.status,
  });
  final int received;
  final int total;
  final ModelDownloadStatus status;

  double get fraction => total == 0 ? 0 : received / total;
}

enum ModelDownloadStatus { idle, downloading, verifying, ready, failed }

class ModelDownloader {
  ModelDownloader({required this.config, Dio? dio})
      : _dio = dio ?? Dio(),
        storage = ModelStorage(config);

  final ModelConfig config;
  final Dio _dio;
  final ModelStorage storage;

  final _progress = StreamController<ModelDownloadProgress>.broadcast();
  Stream<ModelDownloadProgress> get progress => _progress.stream;

  CancelToken? _cancelToken;

  Future<File> ensureInstalled() async {
    final installed = await storage.resolveInstalledFile();
    if (installed != null) {
      _emit(ModelDownloadStatus.ready, 1, 1);
      return installed;
    }
    return _download();
  }

  Future<File> _download() async {
    final target = await storage.targetFile();
    final part = await storage.partFile();
    final start = await part.exists() ? await part.length() : 0;

    _cancelToken = CancelToken();
    _emit(ModelDownloadStatus.downloading, start, config.sizeBytes);

    try {
      await _dio.download(
        config.downloadUrl,
        part.path,
        cancelToken: _cancelToken,
        deleteOnError: false,
        options: Options(
          headers: start > 0 ? {'Range': 'bytes=$start-'} : null,
          responseType: ResponseType.stream,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 30),
        ),
        onReceiveProgress: (received, total) {
          _emit(
            ModelDownloadStatus.downloading,
            start + received,
            config.sizeBytes,
          );
        },
      );

      _emit(ModelDownloadStatus.verifying, config.sizeBytes, config.sizeBytes);
      final digest = await _sha256(part);
      if (config.sha256 != 'TBD_FILLED_AFTER_TRAINING_CONVERT' &&
          digest != config.sha256) {
        await part.delete();
        throw StateError('SHA256 mismatch for ${config.fileName}');
      }

      await part.rename(target.path);
      _emit(ModelDownloadStatus.ready, config.sizeBytes, config.sizeBytes);
      return target;
    } catch (e) {
      _emit(ModelDownloadStatus.failed, 0, config.sizeBytes);
      rethrow;
    }
  }

  void cancel() => _cancelToken?.cancel('User cancelled');

  Future<String> _sha256(File file) async {
    final sink = AccumulatorSink<Digest>();
    final hasher = sha256.startChunkedConversion(sink);
    final stream = file.openRead();
    await for (final chunk in stream) {
      hasher.add(chunk);
    }
    hasher.close();
    return sink.events.single.toString();
  }

  void _emit(ModelDownloadStatus status, int received, int total) {
    _progress.add(ModelDownloadProgress(
      received: received,
      total: total,
      status: status,
    ));
  }
}

final modelDownloaderProvider = Provider<ModelDownloader>(
  (ref) => ModelDownloader(config: ModelConfig.radicalResolveV3),
);

final modelInstallProvider = FutureProvider<File>((ref) async {
  final downloader = ref.watch(modelDownloaderProvider);
  return downloader.ensureInstalled();
});
