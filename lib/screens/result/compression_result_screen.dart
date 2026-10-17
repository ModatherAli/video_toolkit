import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/history_item.dart';
import '../../models/video_info.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import 'widgets/comparison_card.dart';
import 'widgets/video_preview_player.dart';

class CompressionResultScreen extends StatefulWidget {
  final HistoryItem historyItem;
  final VideoInfo sourceVideo;
  final Duration processingDuration;
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const CompressionResultScreen({
    super.key,
    required this.historyItem,
    required this.sourceVideo,
    required this.processingDuration,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  State<CompressionResultScreen> createState() => _CompressionResultScreenState();
}

class _CompressionResultScreenState extends State<CompressionResultScreen> {
  late HistoryItem _item;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _item = widget.historyItem;
    _isSaved = _item.savedToGallery;
  }

  Future<void> _saveToDevice() async {
    if (_isSaved || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final uri = await widget.compressorService.saveToGallery(
        filePath: _item.compressedPath,
        displayName: 'Opti_${_item.fileName}',
      );

      if (uri != null) {
        final updated = _item.copyWith(savedToGallery: true);
        await widget.historyRepository.updateHistoryItem(updated);

        if (mounted) {
          setState(() {
            _isSaved = true;
            _item = updated;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video saved to Gallery (Movies/OptiVideo)'),
              backgroundColor: AppColors.savings,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save video to gallery storage'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _shareVideo() {
    if (File(_item.compressedPath).existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(_item.compressedPath)],
          text: 'Compressed with OptiVideo (${_item.formattedCompressedSize})',
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compressed file not found on disk.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _openInExternalPlayer() {
    widget.compressorService.openVideoFile(_item.compressedPath);
  }

  Future<void> _discardResult() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Video?'),
        content: const Text(
          'Are you sure you want to delete this compressed video and remove it from history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.historyRepository.deleteHistoryItem(
        _item.id,
        deleteFileFromDisk: true,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compression Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Discard',
            onPressed: _discardResult,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _item.isSmaller
                          ? (isDark ? AppColors.savingsContainerDark : AppColors.savingsContainerLight)
                          : (isDark ? AppColors.warningContainer.withAlpha(60) : AppColors.warningContainer),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _item.isSmaller ? Icons.check_circle_rounded : Icons.info_rounded,
                      color: _item.isSmaller ? AppColors.savings : AppColors.warning,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _item.isSmaller ? 'Compression Successful!' : 'Video Processed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _item.isSmaller
                        ? 'Reduced file size by ${_item.savingsPercentage.toStringAsFixed(0)}%'
                        : 'Transcoding complete',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Comparison Metrics Card
            ComparisonCard(
              historyItem: _item,
              processingDuration: widget.processingDuration,
            ),
            const SizedBox(height: 20),

            // Video Preview Player
            Text(
              'Preview Output',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            VideoPreviewPlayer(videoPath: _item.compressedPath),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaved ? null : _saveToDevice,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(_isSaved ? Icons.check_rounded : Icons.save_alt_rounded),
                    label: Text(_isSaved ? 'Saved to Gallery' : 'Save to Device'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareVideo,
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text('Share Video'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Secondary Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openInExternalPlayer,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open Player'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Video'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
