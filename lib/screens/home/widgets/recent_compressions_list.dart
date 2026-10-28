import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/history_item.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/formatters.dart';

class RecentCompressionsList extends StatelessWidget {
  final List<HistoryItem> items;
  final Function(HistoryItem) onPlay;
  final Function(HistoryItem) onShare;
  final Function(HistoryItem) onDelete;
  final VoidCallback onViewAll;

  const RecentCompressionsList({
    super.key,
    required this.items,
    required this.onPlay,
    required this.onShare,
    required this.onDelete,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (items.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    final displayItems = items.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Compressions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                letterSpacing: -0.3,
              ),
            ),
            if (items.length > 4)
              TextButton(
                onPressed: onViewAll,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < displayItems.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildItem(displayItems[i], isDark),
        ],
      ],
    );
  }

  Widget _buildItem(HistoryItem item, bool isDark) {
    final fileExists = File(item.compressedPath).existsSync();

    return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                      child: item.thumbnailPath != null && File(item.thumbnailPath!).existsSync()
                          ? Image.file(
                              File(item.thumbnailPath!),
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              item.formattedOriginalSize,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const Icon(Icons.arrow_right_alt_rounded, size: 14, color: AppColors.savings),
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Savings pill
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
                            if (!fileExists)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.errorContainer.withAlpha(50) : AppColors.errorContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Missing',
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
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 30),
                          tooltip: 'Play video',
                          onPressed: () => onPlay(item),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.share_outlined,
                            size: 20,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          tooltip: 'Share video',
                          onPressed: () => onShare(item),
                        ),
                      ],
                      const SizedBox(width: 4),
                      IconButton(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        tooltip: 'Remove',
                        onPressed: () => onDelete(item),
                      ),
                    ],
                  ),
                ],
              ),
            );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildStepRow(
              context,
              '1',
              'Select Video',
              'Choose any video from your device storage or gallery.',
              colorScheme,
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              context,
              '2',
              'Choose Preset',
              'Pick High Quality, Balanced (Recommended), or Small Size.',
              colorScheme,
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              context,
              '3',
              'Fast On-Device Transcoding',
              'Hardware-accelerated processing without uploading to the cloud.',
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context,
    String number,
    String title,
    String description,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
