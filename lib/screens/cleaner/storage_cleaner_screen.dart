import 'package:flutter/material.dart';
import '../../models/storage_cleaner_item.dart';
import '../../services/history_repository.dart';
import '../../services/storage_cleaner_service.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../batch/batch_queue_screen.dart';

class StorageCleanerScreen extends StatefulWidget {
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const StorageCleanerScreen({
    super.key,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  State<StorageCleanerScreen> createState() => _StorageCleanerScreenState();
}

class _StorageCleanerScreenState extends State<StorageCleanerScreen> {
  late final StorageCleanerService _cleanerService;

  @override
  void initState() {
    super.initState();
    _cleanerService = StorageCleanerService(compressorService: widget.compressorService);
    _cleanerService.scanLargestMedia();
  }

  @override
  void dispose() {
    _cleanerService.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmTrash() async {
    final selectedCount = _cleanerService.selectedItems.length;
    final totalSize = Formatters.formatBytes(_cleanerService.totalSelectedBytes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Move to System Trash?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move $selectedCount selected files ($totalSize) to Android System Trash?',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restore_rounded, size: 18, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Safe: Files stay recoverable in your Gallery trash for 30 days.',
                      style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _cleanerService.trashSelectedOriginals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Files moved to System Trash successfully.'
                  : 'Could not trash files or action was cancelled.',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  void _handleStartBatchCompression() {
    final videoList = _cleanerService.toVideoInfoList();
    if (videoList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one video to compress.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchQueueScreen(
          initialVideos: videoList,
          compressorService: widget.compressorService,
          historyRepository: widget.historyRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Cleaner'),
        actions: [
          IconButton(
            tooltip: 'Rescan Storage',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _cleanerService.scanLargestMedia(),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _cleanerService.isLoadingNotifier,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning device for large media files...'),
                ],
              ),
            );
          }

          return ValueListenableBuilder<List<StorageCleanerItem>>(
            valueListenable: _cleanerService.itemsNotifier,
            builder: (context, items, _) {
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
                        const SizedBox(height: 16),
                        const Text(
                          'Your Storage is Optimized',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No large uncompressed media files found on your device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final selectedCount = _cleanerService.selectedItems.length;
              final reclaimable = Formatters.formatBytes(_cleanerService.estimatedReclaimableBytes);
              final totalOccupied = Formatters.formatBytes(_cleanerService.totalSelectedBytes);
              final allSelected = selectedCount == items.length;

              return Column(
                children: [
                  // Reclaim Hero Dashboard
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [colorScheme.primaryContainer.withAlpha(120), AppColors.surfaceDark]
                            : [colorScheme.primaryContainer.withAlpha(90), AppColors.surfaceLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.primary.withAlpha(80)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.cleaning_services_rounded, color: colorScheme.onPrimary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reclaim up to $reclaimable',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '$selectedCount of ${items.length} files selected ($totalOccupied)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _cleanerService.selectAll(!allSelected),
                              icon: Icon(
                                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                                size: 18,
                              ),
                              label: Text(allSelected ? 'Deselect All' : 'Select All'),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Top 40 Largest Videos',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Media Files List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            value: item.isSelected,
                            onChanged: (_) => _cleanerService.toggleItem(item.id),
                            title: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              '${item.formattedSize} • ${item.formattedDuration}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            secondary: IconButton(
                              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
                              onPressed: () {
                                widget.compressorService.openVideoFile(item.path ?? item.uri);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Action Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      border: Border(top: BorderSide(color: colorScheme.outlineVariant.withAlpha(80))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                            onPressed: selectedCount > 0 ? _handleConfirmTrash : null,
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            label: const Text('Move to Trash'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: selectedCount > 0 ? _handleStartBatchCompression : null,
                            icon: const Icon(Icons.compress_rounded, size: 20),
                            label: Text('Compress ($selectedCount)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
