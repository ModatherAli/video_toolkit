import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/history_item.dart';
import '../../models/video_info.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import 'widgets/comparison_card.dart';
import 'widgets/interactive_split_slider.dart';
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
  bool _isOriginalTrashed = false;
  bool _showSplitComparison = true;
  bool _isAudioVerified = false;

  @override
  void initState() {
    super.initState();
    _item = widget.historyItem;
    _isSaved = _item.savedToGallery;
    _verifyAudioIntegrity();
  }

  Future<void> _verifyAudioIntegrity() async {
    final result = await widget.compressorService.verifyOutputFile(_item.compressedPath);
    if (mounted) {
      setState(() {
        _isAudioVerified = result['hasAudio'] == true;
      });
    }
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

  Future<void> _handleMoveOriginalToTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Original to Trash?'),
        content: Text(
          'Move original "${widget.sourceVideo.fileName}" (${Formatters.formatBytes(_item.originalSizeBytes)}) to Android System Trash?\n\nIt can still be recovered from your gallery trash within 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Original'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.compressorService.requestTrashOriginals([widget.sourceVideo.uri]);
      if (mounted) {
        setState(() {
          _isOriginalTrashed = success;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Original video moved to System Trash.'
                  : 'Could not trash original file.',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  void _shareVideo() {
    final file = File(_item.compressedPath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found on device to share.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    SharePlus.instance.share(
      ShareParams(
        files: [XFile(_item.compressedPath)],
        text: 'Compressed with OptiVideo (${_item.savingsPercentage.toStringAsFixed(0)}% smaller)',
      ),
    );
  }

  void _openInExternalPlayer() {
    widget.compressorService.openVideoFile(_item.compressedPath);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compression Result'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 18),

            // Audio Verification & Safety Pill
            if (_isAudioVerified)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withAlpha(70)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.volume_up_rounded, color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audio Track Verified • Fully synchronized with video',
                        style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Comparison Metrics Card
            ComparisonCard(
              historyItem: _item,
              processingDuration: widget.processingDuration,
            ),
            const SizedBox(height: 20),

            // Video Preview & Split Slider Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showSplitComparison ? 'Split Comparison Slider' : 'Compressed Video Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showSplitComparison = !_showSplitComparison;
                    });
                  },
                  icon: Icon(_showSplitComparison ? Icons.videocam_rounded : Icons.compare_arrows_rounded, size: 16),
                  label: Text(_showSplitComparison ? 'Single Player' : 'Split View'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_showSplitComparison)
              InteractiveSplitSlider(
                originalPathOrUri: widget.sourceVideo.uri,
                compressedPath: _item.compressedPath,
              )
            else
              VideoPreviewPlayer(videoPath: _item.compressedPath),

            const SizedBox(height: 20),

            // Safe Deletion Button (Search 1 & 2 Workflow)
            if (!_isOriginalTrashed)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withAlpha(120)),
                ),
                onPressed: _handleMoveOriginalToTrash,
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                label: Text(
                  'Safely Trash Original (${Formatters.formatBytes(_item.originalSizeBytes)})',
                ),
              ),

            const SizedBox(height: 14),

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
