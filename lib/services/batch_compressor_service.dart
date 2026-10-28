import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/batch_compression_item.dart';
import '../models/compression_config.dart';
import '../models/compression_progress.dart';
import '../models/history_item.dart';
import '../models/video_info.dart';
import 'history_repository.dart';
import 'video_compressor_service.dart';

class BatchCompressorService {
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  final ValueNotifier<List<BatchCompressionItem>> itemsNotifier =
      ValueNotifier<List<BatchCompressionItem>>([]);
  final ValueNotifier<bool> isRunningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(-1);

  StreamSubscription<CompressionProgress>? _eventSub;
  bool _shouldStop = false;

  BatchCompressorService({
    required this.compressorService,
    required this.historyRepository,
  });

  List<BatchCompressionItem> get items => itemsNotifier.value;

  int get totalCount => items.length;
  int get completedCount => items.where((i) => i.status == BatchItemStatus.completed).length;
  int get failedCount => items.where((i) => i.status == BatchItemStatus.failed).length;
  int get skippedCount => items.where((i) => i.status == BatchItemStatus.skipped).length;

  int get totalSavedBytes =>
      items.fold(0, (sum, item) => sum + item.savedBytes);

  double get overallProgress {
    if (items.isEmpty) return 0.0;
    double sum = 0.0;
    for (final item in items) {
      if (item.status == BatchItemStatus.completed || item.status == BatchItemStatus.skipped) {
        sum += 1.0;
      } else if (item.status == BatchItemStatus.compressing) {
        sum += item.progress.clamp(0.0, 1.0);
      }
    }
    return (sum / items.length).clamp(0.0, 1.0);
  }

  /// Sets up a new batch from a list of selected videos with a shared default preset.
  void initializeBatch(List<VideoInfo> videos, {CompressionPreset defaultPreset = CompressionPreset.balanced, double? targetMB}) {
    final list = <BatchCompressionItem>[];
    for (var i = 0; i < videos.length; i++) {
      final video = videos[i];
      final config = CompressionConfig.fromPreset(
        preset: defaultPreset,
        source: video,
        customTargetMB: targetMB,
      );
      list.add(
        BatchCompressionItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          source: video,
          config: config,
        ),
      );
    }
    itemsNotifier.value = list;
    currentIndexNotifier.value = -1;
    isRunningNotifier.value = false;
    isPausedNotifier.value = false;
  }

  /// Updates configuration for a specific item in the queue.
  void updateItemConfig(String id, CompressionConfig newConfig) {
    final current = List<BatchCompressionItem>.from(itemsNotifier.value);
    final idx = current.indexWhere((it) => it.id == id);
    if (idx != -1 && current[idx].status == BatchItemStatus.pending) {
      current[idx] = current[idx].copyWith(config: newConfig);
      itemsNotifier.value = current;
    }
  }

  /// Applies a preset configuration across all pending items in the queue.
  void applyConfigToAll(CompressionPreset preset, {double? targetMB}) {
    final current = List<BatchCompressionItem>.from(itemsNotifier.value);
    for (var i = 0; i < current.length; i++) {
      if (current[i].status == BatchItemStatus.pending) {
        final newConfig = CompressionConfig.fromPreset(
          preset: preset,
          source: current[i].source,
          customTargetMB: targetMB,
        );
        current[i] = current[i].copyWith(config: newConfig);
      }
    }
    itemsNotifier.value = current;
  }

  /// Starts or resumes batch execution.
  Future<void> startBatch() async {
    if (isRunningNotifier.value && !isPausedNotifier.value) return;

    isRunningNotifier.value = true;
    isPausedNotifier.value = false;
    _shouldStop = false;

    // Start Android Foreground Service for persistent execution
    await compressorService.startForegroundNotification(
      title: 'Compressing Videos',
      message: 'Processing batch (0/${items.length})...',
      progressPercent: 0,
    );

    await _processQueue();
  }

  /// Pauses after current job or immediately if possible.
  void pauseBatch() {
    isPausedNotifier.value = true;
  }

  /// Cancels entire batch and stops running job.
  Future<void> cancelBatch() async {
    _shouldStop = true;
    isPausedNotifier.value = false;
    isRunningNotifier.value = false;
    await compressorService.cancelCompression();
    await compressorService.stopForegroundNotification();

    final current = List<BatchCompressionItem>.from(itemsNotifier.value);
    for (var i = 0; i < current.length; i++) {
      if (current[i].status == BatchItemStatus.pending ||
          current[i].status == BatchItemStatus.compressing) {
        current[i] = current[i].copyWith(status: BatchItemStatus.cancelled);
      }
    }
    itemsNotifier.value = current;
    currentIndexNotifier.value = -1;
  }

  /// Retries failed items.
  Future<void> retryFailed() async {
    final current = List<BatchCompressionItem>.from(itemsNotifier.value);
    for (var i = 0; i < current.length; i++) {
      if (current[i].status == BatchItemStatus.failed ||
          current[i].status == BatchItemStatus.cancelled) {
        current[i] = current[i].copyWith(
          status: BatchItemStatus.pending,
          progress: 0.0,
          errorMessage: null,
        );
      }
    }
    itemsNotifier.value = current;
    await startBatch();
  }

  Future<void> _processQueue() async {
    while (_shouldStop == false) {
      if (isPausedNotifier.value) {
        break;
      }

      final pendingIdx = itemsNotifier.value.indexWhere(
        (it) => it.status == BatchItemStatus.pending,
      );

      if (pendingIdx == -1) {
        // All items processed
        break;
      }

      currentIndexNotifier.value = pendingIdx;
      final item = itemsNotifier.value[pendingIdx];

      // Check if file is already smaller than target size (Search 2 rule: skip if already below limit)
      if (item.config.targetFileSizeMB != null) {
        final targetBytes = (item.config.targetFileSizeMB! * 1024 * 1024).round();
        if (item.source.fileSizeBytes <= targetBytes) {
          _updateItemStatus(pendingIdx, BatchItemStatus.skipped, progress: 1.0);
          continue;
        }
      }

      // Mark compressing
      _updateItemStatus(pendingIdx, BatchItemStatus.compressing, progress: 0.0);

      // Update Foreground Notification
      final done = completedCount + skippedCount;
      final pct = (overallProgress * 100).round();
      await compressorService.updateForegroundNotification(
        title: 'Compressing (${done + 1}/$totalCount)',
        message: item.source.fileName,
        progressPercent: pct,
      );

      // Execute single item
      try {
        final outputPath = await compressorService.generateOutputPath(item.source.fileName);
        final completer = Completer<bool>();

        _eventSub?.cancel();
        _eventSub = compressorService.compressionEvents.listen(
          (event) async {
            if (event.status == CompressionStatus.compressing) {
              _updateItemProgress(pendingIdx, event.progressFraction);
              final updatedPct = (overallProgress * 100).round();
              compressorService.updateForegroundNotification(
                title: 'Compressing (${done + 1}/$totalCount)',
                message: '${event.progress}% • ${item.source.fileName}',
                progressPercent: updatedPct,
              );
            } else if (event.status == CompressionStatus.completed) {
              if (!completer.isCompleted) {
                // Save to history repository
                final historyItem = HistoryItem(
                  id: item.id,
                  fileName: item.source.fileName,
                  originalPath: item.source.uri,
                  compressedPath: event.outputPath ?? outputPath,
                  originalSizeBytes: item.source.fileSizeBytes,
                  compressedSizeBytes: event.compressedSizeBytes ?? 0,
                  durationMs: item.source.durationMs,
                  resolution: '${item.config.targetWidth}×${item.config.targetHeight}',
                  timestamp: DateTime.now(),
                );
                await historyRepository.addHistoryItem(historyItem);

                _updateItemStatus(
                  pendingIdx,
                  BatchItemStatus.completed,
                  progress: 1.0,
                  outputPath: event.outputPath ?? outputPath,
                  compressedSizeBytes: event.compressedSizeBytes,
                );
                completer.complete(true);
              }
            } else if (event.status == CompressionStatus.error) {
              if (!completer.isCompleted) {
                _updateItemStatus(
                  pendingIdx,
                  BatchItemStatus.failed,
                  errorMessage: event.errorMessage ?? 'Compression error',
                );
                completer.complete(false);
              }
            }
          },
          onError: (e) {
            if (!completer.isCompleted) {
              _updateItemStatus(
                pendingIdx,
                BatchItemStatus.failed,
                errorMessage: e.toString(),
              );
              completer.complete(false);
            }
          },
        );

        final started = await compressorService.startCompression(
          source: item.source,
          config: item.config,
          outputPath: outputPath,
        );

        if (!started) {
          _updateItemStatus(
            pendingIdx,
            BatchItemStatus.failed,
            errorMessage: 'Failed to start compression transformer',
          );
        } else {
          await completer.future;
        }
      } catch (e) {
        _updateItemStatus(
          pendingIdx,
          BatchItemStatus.failed,
          errorMessage: e.toString(),
        );
      } finally {
        await _eventSub?.cancel();
        _eventSub = null;
      }
    }

    isRunningNotifier.value = false;
    currentIndexNotifier.value = -1;
    await compressorService.stopForegroundNotification();
  }

  void _updateItemStatus(
    int index,
    BatchItemStatus status, {
    double? progress,
    String? outputPath,
    int? compressedSizeBytes,
    String? errorMessage,
  }) {
    final list = List<BatchCompressionItem>.from(itemsNotifier.value);
    if (index >= 0 && index < list.length) {
      list[index] = list[index].copyWith(
        status: status,
        progress: progress,
        outputPath: outputPath,
        compressedSizeBytes: compressedSizeBytes,
        errorMessage: errorMessage,
      );
      itemsNotifier.value = list;
    }
  }

  void _updateItemProgress(int index, double progress) {
    final list = List<BatchCompressionItem>.from(itemsNotifier.value);
    if (index >= 0 && index < list.length) {
      list[index] = list[index].copyWith(progress: progress);
      itemsNotifier.value = list;
    }
  }

  void dispose() {
    _eventSub?.cancel();
    itemsNotifier.dispose();
    isRunningNotifier.dispose();
    isPausedNotifier.dispose();
    currentIndexNotifier.dispose();
  }
}
