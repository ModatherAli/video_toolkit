import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/compression_config.dart';
import '../../models/compression_progress.dart';
import '../../models/history_item.dart';
import '../../models/video_info.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../result/compression_result_screen.dart';

class CompressionProgressScreen extends StatefulWidget {
  final VideoInfo sourceVideo;
  final CompressionConfig config;
  final String outputPath;
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const CompressionProgressScreen({
    super.key,
    required this.sourceVideo,
    required this.config,
    required this.outputPath,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  State<CompressionProgressScreen> createState() => _CompressionProgressScreenState();
}

class _CompressionProgressScreenState extends State<CompressionProgressScreen> {
  StreamSubscription<CompressionProgress>? _subscription;
  int _progress = 0;
  String _statusText = 'Initializing hardware encoder...';
  String? _errorMessage;
  bool _isCancelled = false;

  late final DateTime _startTime;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startElapsedTimer();
    _initCompression();
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  Future<void> _initCompression() async {
    // Subscribe to native event channel
    _subscription = widget.compressorService.compressionEvents.listen(
      _handleCompressionEvent,
      onError: (err) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Native encoder error: $err';
          });
        }
      },
    );

    try {
      final success = await widget.compressorService.startCompression(
        source: widget.sourceVideo,
        config: widget.config,
        outputPath: widget.outputPath,
      );

      if (!success && mounted) {
        setState(() {
          _errorMessage = 'Could not initiate video compression engine.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start compression: $e';
        });
      }
    }
  }

  Future<void> _handleCompressionEvent(CompressionProgress event) async {
    if (!mounted || _isCancelled) return;

    switch (event.status) {
      case CompressionStatus.compressing:
        setState(() {
          _progress = event.progress;
          _statusText = 'Transcoding video ($_progress%)...';
        });
        break;

      case CompressionStatus.completed:
        _elapsedTimer?.cancel();
        final finalSize = event.outputSize ?? 0;
        final durationMs = widget.sourceVideo.duration.inMilliseconds;

        final historyItem = HistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: widget.sourceVideo.fileName,
          originalPath: widget.sourceVideo.uri,
          compressedPath: event.outputPath ?? widget.outputPath,
          originalSizeBytes: widget.sourceVideo.fileSize,
          compressedSizeBytes: finalSize,
          durationMs: durationMs,
          resolution: '${widget.config.targetWidth}×${widget.config.targetHeight}',
          thumbnailPath: widget.sourceVideo.thumbnailPath,
          timestamp: DateTime.now(),
        );

        // Save to persistent history
        await widget.historyRepository.addHistoryItem(historyItem);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CompressionResultScreen(
                historyItem: historyItem,
                sourceVideo: widget.sourceVideo,
                processingDuration: _elapsed,
                compressorService: widget.compressorService,
                historyRepository: widget.historyRepository,
              ),
            ),
          );
        }
        break;

      case CompressionStatus.cancelled:
        _elapsedTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
        break;

      case CompressionStatus.error:
        _elapsedTimer?.cancel();
        setState(() {
          _errorMessage = event.message ?? 'An unexpected compression error occurred.';
        });
        break;

      default:
        break;
    }
  }

  Future<bool> _onWillPop() async {
    if (_errorMessage != null || _isCancelled) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Compression?'),
        content: const Text(
          'Video compression is currently in progress. If you cancel, the partially compressed video will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Compressing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Job', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _cancelCompression();
      return true;
    }
    return false;
  }

  void _cancelCompression() {
    _isCancelled = true;
    _elapsedTimer?.cancel();
    widget.compressorService.cancelCompression();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compressing Video'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: _errorMessage != null
                ? _buildErrorView(isDark)
                : _buildProgressView(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressView(bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compressing on Device',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.sourceVideo.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: _progress > 0 ? _progress / 100.0 : null,
                            strokeWidth: 10,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_progress%',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              Formatters.formatDuration(_elapsed),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.memory_rounded, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Hardware-accelerated MediaCodec pipeline active',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _onWillPop,
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                  label: const Text('Cancel Compression', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
        const SizedBox(height: 20),
        const Text(
          'Compression Failed',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          _errorMessage ?? 'An unknown error occurred during media transcoding.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Setup'),
          ),
        ),
      ],
    );
  }
}
