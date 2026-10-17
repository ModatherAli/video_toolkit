import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/history_item.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class HistoryScreen extends StatefulWidget {
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const HistoryScreen({
    super.key,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) {
        var alsoDeleteFiles = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Clear All History?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Are you sure you want to clear your compression history?'),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Also delete video files from device',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: alsoDeleteFiles,
                    onChanged: (val) {
                      setDialogState(() {
                        alsoDeleteFiles = val ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.historyRepository.clearAll(deleteFilesFromDisk: alsoDeleteFiles);
                  },
                  child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteItem(HistoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        var alsoDeleteFile = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete History Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remove "${item.fileName}" from history?'),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Also delete video file from device',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: alsoDeleteFile,
                    onChanged: (val) {
                      setDialogState(() {
                        alsoDeleteFile = val ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.historyRepository.deleteHistoryItem(
                      item.id,
                      deleteFileFromDisk: alsoDeleteFile,
                    );
                  },
                  child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compression History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Verify files on disk',
            onPressed: () => widget.historyRepository.loadHistory(),
          ),
          ValueListenableBuilder<List<HistoryItem>>(
            valueListenable: widget.historyRepository.historyNotifier,
            builder: (context, items, _) {
              if (items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Clear All History',
                onPressed: _confirmClearAll,
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<HistoryItem>>(
        valueListenable: widget.historyRepository.historyNotifier,
        builder: (context, items, _) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          if (items.isEmpty) {
            return _buildEmptyView(isDark);
          }

          final filteredItems = _searchQuery.isEmpty
              ? items
              : items.where((i) => i.fileName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          final totalSavedBytes = items.fold<int>(0, (sum, i) => sum + (i.isSmaller ? i.savedBytes : 0));

          return Column(
            children: [
              // Statistics Banner (ui_ideas design)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: colorScheme.primaryContainer.withAlpha(120),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.savings_rounded,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Storage Reclaimed',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${Formatters.formatBytes(totalSavedBytes)} across ${items.length} ${items.length == 1 ? 'video' : 'videos'}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search compressed videos...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceVariantLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              // History items list
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          'No videos match "$_searchQuery"',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final fileExists = File(item.compressedPath).existsSync();

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                    child: item.thumbnailPath != null && File(item.thumbnailPath!).existsSync()
                                        ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                                        : const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 30),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            item.formattedOriginalSize,
                                            style: TextStyle(
                                              fontSize: 12,
                                              decoration: TextDecoration.lineThrough,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_right_alt_rounded, size: 14, color: AppColors.savings),
                                          const SizedBox(width: 6),
                                          Text(
                                            item.formattedCompressedSize,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.savings,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: item.isSmaller
                                                  ? (isDark ? AppColors.savingsContainerDark : AppColors.savingsContainerLight)
                                                  : (isDark ? AppColors.warningContainer.withAlpha(50) : AppColors.warningContainer),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.isSmaller
                                                  ? '-${item.savingsPercentage.toStringAsFixed(0)}%'
                                                  : '+${(-item.savingsPercentage).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: item.isSmaller ? AppColors.savings : AppColors.warning,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!fileExists)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? AppColors.errorContainer.withAlpha(50) : AppColors.errorContainer,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'File Missing',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              Formatters.formatDate(item.timestamp),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (fileExists) ...[
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 28),
                                        onPressed: () {
                                          widget.compressorService.openVideoFile(item.compressedPath);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.share_outlined,
                                          size: 20,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                        onPressed: () {
                                          SharePlus.instance.share(
                                            ShareParams(
                                              files: [XFile(item.compressedPath)],
                                              text: 'Compressed with OptiVideo (${item.formattedCompressedSize})',
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                      onPressed: () => _confirmDeleteItem(item),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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


  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No Compression History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Videos you compress will appear here for easy playback, sharing, and storage tracking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
