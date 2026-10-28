import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/batch_compression_item.dart';
import '../../models/compression_config.dart';
import '../../models/video_info.dart';
import '../../services/batch_compressor_service.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class BatchQueueScreen extends StatefulWidget {
  final List<VideoInfo> initialVideos;
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const BatchQueueScreen({
    super.key,
    required this.initialVideos,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  State<BatchQueueScreen> createState() => _BatchQueueScreenState();
}

class _BatchQueueScreenState extends State<BatchQueueScreen> {
  late final BatchCompressorService _batchService;
  CompressionPreset _selectedBatchPreset = CompressionPreset.whatsApp;

  @override
  void initState() {
    super.initState();
    _batchService = BatchCompressorService(
      compressorService: widget.compressorService,
      historyRepository: widget.historyRepository,
    );
    _batchService.initializeBatch(
      widget.initialVideos,
      defaultPreset: _selectedBatchPreset,
    );
  }

  @override
  void dispose() {
    _batchService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Video Queue'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _batchService.isRunningNotifier,
            builder: (context, isRunning, _) {
              if (isRunning) {
                return TextButton.icon(
                  onPressed: () => _batchService.cancelBatch(),
                  icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
                  label: const Text('Cancel All', style: TextStyle(color: AppColors.error)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<BatchCompressionItem>>(
        valueListenable: _batchService.itemsNotifier,
        builder: (context, items, _) {
          final totalCount = items.length;
          final completed = items.where((i) => i.status == BatchItemStatus.completed).length;
          final skipped = items.where((i) => i.status == BatchItemStatus.skipped).length;
          final failed = items.where((i) => i.status == BatchItemStatus.failed).length;
          final savedBytes = _batchService.totalSavedBytes;
          final progress = _batchService.overallProgress;

          return Column(
            children: [
              // Summary & Overall Progress Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress • $completed of $totalCount completed',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (skipped > 0)
                              Text(
                                '$skipped skipped (already small)',
                                style: const TextStyle(fontSize: 11, color: AppColors.warning),
                              ),
                          ],
                        ),
                        if (savedBytes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Saved: ${Formatters.formatBytes(savedBytes)}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 10,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Preset Application Bar
                    ValueListenableBuilder<bool>(
                      valueListenable: _batchService.isRunningNotifier,
                      builder: (context, isRunning, _) {
                        return Row(
                          children: [
                            const Text('Preset for all: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            DropdownButton<CompressionPreset>(
                              value: _selectedBatchPreset,
                              isDense: true,
                              disabledHint: Text(_selectedBatchPreset.title),
                              items: const [
                                DropdownMenuItem(
                                  value: CompressionPreset.whatsApp,
                                  child: Text('WhatsApp (14 MB)'),
                                ),
                                DropdownMenuItem(
                                  value: CompressionPreset.balanced,
                                  child: Text('Balanced (720p)'),
                                ),
                                DropdownMenuItem(
                                  value: CompressionPreset.smallSize,
                                  child: Text('Small Size (480p)'),
                                ),
                                DropdownMenuItem(
                                  value: CompressionPreset.discord,
                                  child: Text('Discord (9 MB)'),
                                ),
                                DropdownMenuItem(
                                  value: CompressionPreset.email,
                                  child: Text('Email (20 MB)'),
                                ),
                              ],
                              onChanged: isRunning
                                  ? null
                                  : (newPreset) {
                                      if (newPreset != null) {
                                        setState(() {
                                          _selectedBatchPreset = newPreset;
                                          _batchService.applyConfigToAll(newPreset);
                                        });
                                      }
                                    },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Queue List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildItemCard(item, colorScheme, isDark);
                  },
                ),
              ),

              // Bottom Action Controls
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: Border(top: BorderSide(color: colorScheme.outlineVariant.withAlpha(80))),
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _batchService.isRunningNotifier,
                  builder: (context, isRunning, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _batchService.isPausedNotifier,
                      builder: (context, isPaused, _) {
                        if (isRunning && !isPaused) {
                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _batchService.pauseBatch(),
                                  icon: const Icon(Icons.pause_rounded),
                                  label: const Text('Pause Queue'),
                                ),
                              ),
                            ],
                          );
                        } else if (isPaused) {
                          return Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _batchService.startBatch(),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Resume Queue'),
                                ),
                              ),
                            ],
                          );
                        } else if (completed + skipped == totalCount && totalCount > 0) {
                          return Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text('Batch Finished • Return Home'),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              if (failed > 0) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _batchService.retryFailed(),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text('Retry Failed ($failed)'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _batchService.startBatch(),
                                  icon: const Icon(Icons.bolt_rounded),
                                  label: Text('Start Batch ($totalCount Videos)'),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemCard(
    BatchCompressionItem item,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.source.thumbnailPath != null &&
                        File(item.source.thumbnailPath!).existsSync()
                    ? Image.file(
                        File(item.source.thumbnailPath!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: colorScheme.primaryContainer,
                        child: const Icon(Icons.movie_rounded, color: AppColors.primary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.source.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          Formatters.formatBytes(item.originalSizeBytes),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        if (item.compressedSizeBytes != null) ...[
                          const Text(' → ', style: TextStyle(fontSize: 11)),
                          Text(
                            Formatters.formatBytes(item.compressedSizeBytes!),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                        const Spacer(),
                        _buildStatusBadge(item.status, item.savingsPercentage),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.status == BatchItemStatus.compressing) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.progress > 0 ? item.progress : null,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
          if (item.status == BatchItemStatus.failed && item.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              item.errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BatchItemStatus status, double savingsPct) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case BatchItemStatus.pending:
        bg = Colors.grey.withAlpha(40);
        fg = Colors.grey;
        text = 'Queued';
        break;
      case BatchItemStatus.compressing:
        bg = AppColors.primary.withAlpha(40);
        fg = AppColors.primary;
        text = 'Compressing';
        break;
      case BatchItemStatus.completed:
        bg = AppColors.success.withAlpha(40);
        fg = AppColors.success;
        text = '-${savingsPct.toStringAsFixed(0)}%';
        break;
      case BatchItemStatus.skipped:
        bg = AppColors.warning.withAlpha(40);
        fg = AppColors.warning;
        text = 'Skipped';
        break;
      case BatchItemStatus.failed:
        bg = AppColors.error.withAlpha(40);
        fg = AppColors.error;
        text = 'Failed';
        break;
      case BatchItemStatus.cancelled:
        bg = Colors.grey.withAlpha(40);
        fg = Colors.grey;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
