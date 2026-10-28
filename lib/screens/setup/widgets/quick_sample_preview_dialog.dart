import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../models/compression_config.dart';
import '../../../models/video_info.dart';
import '../../../services/video_compressor_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/formatters.dart';

class QuickSamplePreviewDialog extends StatefulWidget {
  final VideoInfo sourceVideo;
  final CompressionConfig config;
  final VideoCompressorService compressorService;

  const QuickSamplePreviewDialog({
    super.key,
    required this.sourceVideo,
    required this.config,
    required this.compressorService,
  });

  @override
  State<QuickSamplePreviewDialog> createState() => _QuickSamplePreviewDialogState();
}

class _QuickSamplePreviewDialogState extends State<QuickSamplePreviewDialog> {
  bool _isLoading = true;
  String? _samplePath;
  String? _errorMessage;
  VideoPlayerController? _controller;
  int _sampleSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _generateSample();
  }

  Future<void> _generateSample() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final path = await widget.compressorService.createQuickSample(
        source: widget.sourceVideo,
        config: widget.config,
        sampleDurationSeconds: 5,
      );

      if (path != null && File(path).existsSync()) {
        final bytes = File(path).lengthSync();
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        await controller.setLooping(true);
        await controller.play();

        if (mounted) {
          setState(() {
            _samplePath = path;
            _sampleSizeBytes = bytes;
            _controller = controller;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Could not generate 5-second sample preview.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_samplePath != null) {
      try {
        final f = File(_samplePath!);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.speed_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '5-Second Quality Preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rendered with ${widget.config.preset.title}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 16),
                    Text(
                      'Encoding 5-second test sample...',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                    const SizedBox(height: 8),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ] else if (_controller != null && _controller!.value.isInitialized) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(_controller!),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: Colors.black54,
                        child: Row(
                          children: [
                            const Icon(Icons.hd_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.config.targetWidth}×${widget.config.targetHeight} • ${Formatters.formatBitrate(widget.config.videoBitrate)}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              'Sample: ${Formatters.formatBytes(_sampleSizeBytes)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Adjust Settings'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context, true); // True means proceed with compression
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Looks Good!'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
