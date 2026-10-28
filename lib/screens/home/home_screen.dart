import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/history_item.dart';
import '../../services/device_safety_service.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../audio/audio_compressor_screen.dart';
import '../batch/batch_queue_screen.dart';
import '../cleaner/storage_cleaner_screen.dart';
import '../history/history_screen.dart';
import '../settings/safety_settings_screen.dart';
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
  late final DeviceSafetyService _safetyService;
  int _freeBytes = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _safetyService = DeviceSafetyService(compressorService: widget.compressorService);
    _safetyService.loadSettings();
    _loadStorageInfo();
  }

  @override
  void dispose() {
    _safetyService.dispose();
    super.dispose();
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

  Future<void> _handleBatchSelect() async {
    setState(() => _isLoading = true);
    try {
      final videos = await widget.compressorService.pickMultipleVideos();
      if (!mounted) return;

      if (videos.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BatchQueueScreen(
              initialVideos: videos,
              compressorService: widget.compressorService,
              historyRepository: widget.historyRepository,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting videos: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openStorageCleaner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StorageCleanerScreen(
          compressorService: widget.compressorService,
          historyRepository: widget.historyRepository,
        ),
      ),
    );
  }

  void _openAudioCompressor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudioCompressorScreen(
          compressorService: widget.compressorService,
        ),
      ),
    );
  }

  void _openSafetySettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SafetySettingsScreen(
          safetyService: _safetyService,
        ),
      ),
    );
  }

  void _handlePlayHistoryItem(HistoryItem item) {
    widget.compressorService.openVideoFile(item.compressedPath);
  }

  void _handleShareHistoryItem(HistoryItem item) {
    final file = File(item.compressedPath);
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
        files: [XFile(item.compressedPath)],
        text: 'Compressed with OptiVideo (${item.savingsPercentage.toStringAsFixed(0)}% saved)',
      ),
    );
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
                  'OptiVideo is an offline video and audio compression toolkit designed for Android.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  'Key Features:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text('• 100% Offline: No internet permission, zero server uploads.'),
                Text('• Fit to App: One-tap presets for WhatsApp (14MB), Discord, and Email.'),
                Text('• Target Size: Specify exact MB limit and let bitrate adapt automatically.'),
                Text('• Batch Mode: Compress dozens of videos in background with persistent notification.'),
                Text('• Storage Cleaner: Free up GBs with safe 30-day Android System Trash.'),
                Text('• Audio Studio: Compress MP3, M4A, podcasts with vocal clarity and silence trimming.'),
                Text('• Thermal Protection: Safe compression that prevents phone overheating.'),
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
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Battery & Thermal Safety',
            onPressed: _openSafetySettings,
          ),
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
            const PrivacyBanner(),
            const SizedBox(height: 14),

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

            // Hero Select Single Video Card
            _buildSelectHeroCard(context, theme, colorScheme),
            const SizedBox(height: 18),

            // Quick Toolkit Features Grid
            Row(
              children: [
                Expanded(
                  child: _buildToolkitCard(
                    context: context,
                    icon: Icons.burst_mode_rounded,
                    title: 'Batch Mode',
                    subtitle: 'Multi-video queue',
                    onTap: _handleBatchSelect,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToolkitCard(
                    context: context,
                    icon: Icons.cleaning_services_rounded,
                    title: 'Storage Cleaner',
                    subtitle: 'Reclaim space',
                    onTap: _openStorageCleaner,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildToolkitCard(
                    context: context,
                    icon: Icons.graphic_eq_rounded,
                    title: 'Audio Studio',
                    subtitle: 'MP3 & Podcasts',
                    onTap: _openAudioCompressor,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToolkitCard(
                    context: context,
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Thermal Safety',
                    subtitle: 'Protect device',
                    onTap: _openSafetySettings,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Compressions or Empty State
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
              'Target exact MB sizes for WhatsApp, Discord, & Email, or reclaim storage in batch. 100% offline & hardware accelerated.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    onPressed: _isLoading ? null : _handleSelectVideo,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(_isLoading ? 'Opening Picker…' : 'Select Video'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    onPressed: _isLoading ? null : _handleBatchSelect,
                    icon: const Icon(Icons.burst_mode_rounded, size: 18),
                    label: const Text('Batch Mode'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolkitCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
