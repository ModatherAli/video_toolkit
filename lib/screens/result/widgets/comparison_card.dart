import 'package:flutter/material.dart';
import '../../../models/history_item.dart';

class ComparisonCard extends StatelessWidget {
  final HistoryItem historyItem;
  final Duration processingDuration;

  const ComparisonCard({
    super.key,
    required this.historyItem,
    required this.processingDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmaller = historyItem.isSmaller;

    final compressedRatio = historyItem.originalSizeBytes > 0
        ? (historyItem.compressedSizeBytes / historyItem.originalSizeBytes).clamp(0.08, 1.0)
        : 0.5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning if output is larger than original
            if (!isSmaller) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The output file is slightly larger than the original because the source was already heavily compressed.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Visual comparison bars
            _SizeComparisonBar(
              label: 'Original Video',
              sizeText: historyItem.formattedOriginalSize,
              fraction: 1.0,
              barColor: colorScheme.outlineVariant,
              textColor: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            _SizeComparisonBar(
              label: 'Compressed Video',
              sizeText: historyItem.formattedCompressedSize,
              fraction: compressedRatio,
              barColor: isSmaller ? colorScheme.primary : colorScheme.error,
              textColor: isSmaller ? colorScheme.primary : colorScheme.error,
              isHighlighted: true,
            ),
            const SizedBox(height: 20),

            // Space saved highlight card
            if (isSmaller) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(90),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha(50),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.savings_rounded,
                        color: colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved ${historyItem.formattedSavedBytes}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            'Reduced file size by ${historyItem.savingsPercentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Technical details footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn(
                  theme,
                  label: 'Encoding Time',
                  value: '${processingDuration.inSeconds}s',
                ),
                Container(height: 24, width: 1, color: colorScheme.outlineVariant.withAlpha(80)),
                _buildMetricColumn(
                  theme,
                  label: 'Output Resolution',
                  value: historyItem.resolution,
                ),
                Container(height: 24, width: 1, color: colorScheme.outlineVariant.withAlpha(80)),
                _buildMetricColumn(
                  theme,
                  label: 'Video Codec',
                  value: 'H.264 / AAC',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SizeComparisonBar extends StatelessWidget {
  final String label;
  final String sizeText;
  final double fraction;
  final Color barColor;
  final Color textColor;
  final bool isHighlighted;

  const _SizeComparisonBar({
    required this.label,
    required this.sizeText,
    required this.fraction,
    required this.barColor,
    required this.textColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                color: isHighlighted ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              sizeText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 10,
            width: double.infinity,
            color: colorScheme.surfaceContainerHighest,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.04, 1.0),
              child: Container(color: barColor),
            ),
          ),
        ),
      ],
    );
  }
}
