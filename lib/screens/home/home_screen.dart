import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/history_item.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../history/history_screen.dart';
import '../setup/compression_setup_screen.dart';
import 'widgets/privacy_banner.dart';
import 'widgets/recent_compressions_list.dart';
import 'widgets/storage_indicator.dart';

class HomeScreen extends StatefulWidget {
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const HomeScreen({
    super.key,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _freeBytes = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    final bytes = await widget.compressorService.getAvailableStorage();
    if (mounted) {
      setState(() {
        _freeBytes = bytes;
      });
    }
  }

  Future<void> _handleSelectVideo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final videoInfo = await widget.compressorService.pickVideo();
      if (!mounted) return;

      if (videoInfo != null) {
        if (videoInfo.fileSize <= 0 && videoInfo.duration == Duration.zero) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected file is not a valid video or cannot be read.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CompressionSetupScreen(
              sourceVideo: videoInfo,
              compressorService: widget.compressorService,
              historyRepository: widget.historyRepository,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handlePlayHistoryItem(HistoryItem item) {
    widget.compressorService.openVideoFile(item.compressedPath);
  }

  void _handleShareHistoryItem(HistoryItem item) {
    if (File(item.compressedPath).existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(item.compressedPath)],
          text: 'Compressed with OptiVideo (${item.formattedCompressedSize})',
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video file not found on disk.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _handleDeleteHistoryItem(HistoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        var alsoDeleteFile = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Remove from History'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remove "${item.fileName}" from compression history?'),
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
                    _loadStorageInfo();
                  },
                  child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('About OptiVideo', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OptiVideo is a fast, 100% offline video compressor designed for Android.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  'Key Features:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text('• 100% Offline: No internet connection is ever requested or used.'),
                Text('• Hardware Accelerated: Powered by AndroidX Media3 Transformer for fast, battery-efficient encoding.'),
                Text('• Privacy First: Videos stay exclusively on your device storage.'),
                Text('• Scoped Storage Compliant: Saves directly to public Movies/OptiVideo album.'),
                Text('• Real Progress: Genuine hardware encoder progress monitoring.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.compress_rounded,
                size: 18,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('OptiVideo'),
          ],
        ),
        actions: [
          ValueListenableBuilder<List<HistoryItem>>(
            valueListenable: widget.historyRepository.historyNotifier,
            builder: (context, history, _) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: history.isNotEmpty,
                  label: Text('${history.length}'),
                  child: const Icon(Icons.history_rounded),
                ),
                tooltip: 'Compression History',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistoryScreen(
                        compressorService: widget.compressorService,
                        historyRepository: widget.historyRepository,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About & Privacy',
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStorageInfo();
          await widget.historyRepository.loadHistory();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Privacy Banner
            const PrivacyBanner(),
            const SizedBox(height: 14),

            // Storage and Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StorageIndicator(freeBytes: _freeBytes),
                ValueListenableBuilder<List<HistoryItem>>(
                  valueListenable: widget.historyRepository.historyNotifier,
                  builder: (context, history, _) {
                    if (history.isEmpty) return const SizedBox.shrink();
                    final totalSaved = history.fold<int>(
                      0,
                      (sum, i) => sum + (i.isSmaller ? i.savedBytes : 0),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withAlpha(70),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Total saved: ${Formatters.formatBytes(totalSaved)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Select Video Hero Card (ui_ideas design)
            _buildSelectHeroCard(context, theme, colorScheme),
            const SizedBox(height: 24),

            // Recent compressions list or How It Works empty state
            ValueListenableBuilder<List<HistoryItem>>(
              valueListenable: widget.historyRepository.historyNotifier,
              builder: (context, items, _) {
                return RecentCompressionsList(
                  items: items,
                  onPlay: _handlePlayHistoryItem,
                  onShare: _handleShareHistoryItem,
                  onDelete: _handleDeleteHistoryItem,
                  onViewAll: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryScreen(
                          compressorService: widget.compressorService,
                          historyRepository: widget.historyRepository,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _handleSelectVideo,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.add_photo_alternate_rounded),
        label: Text(
          _isLoading ? 'Opening Video Picker…' : 'Select Video',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildSelectHeroCard(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.video_file_rounded,
                size: 38,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Shrink Video Size in Seconds',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reduce large 4K and 1080p videos for fast sharing and extra storage while keeping crisp visual quality. Original videos are never overwritten.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _handleSelectVideo,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
              label: Text(
                _isLoading ? 'Opening Video Picker…' : 'Select Video',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
