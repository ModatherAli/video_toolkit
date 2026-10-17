import 'package:flutter/material.dart';
import '../../models/compression_config.dart';
import '../../models/video_info.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../processing/compression_progress_screen.dart';
import 'widgets/custom_settings_panel.dart';
import 'widgets/preset_card.dart';
import 'widgets/video_summary_card.dart';

class CompressionSetupScreen extends StatefulWidget {
  final VideoInfo sourceVideo;
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const CompressionSetupScreen({
    super.key,
    required this.sourceVideo,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  State<CompressionSetupScreen> createState() => _CompressionSetupScreenState();
}

class _CompressionSetupScreenState extends State<CompressionSetupScreen> {
  late CompressionPreset _selectedPreset;
  late CompressionConfig _currentConfig;
  int _freeStorageBytes = 0;
  bool _isCustomExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedPreset = CompressionPreset.balanced; // Default recommended
    _currentConfig = CompressionConfig.fromPreset(
      preset: _selectedPreset,
      source: widget.sourceVideo,
    );
    _checkStorage();
  }

  Future<void> _checkStorage() async {
    final free = await widget.compressorService.getAvailableStorage();
    if (mounted) {
      setState(() {
        _freeStorageBytes = free;
      });
    }
  }

  void _onPresetSelected(CompressionPreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset == CompressionPreset.custom) {
        _isCustomExpanded = true;
      } else {
        _isCustomExpanded = false;
        _currentConfig = CompressionConfig.fromPreset(
          preset: preset,
          source: widget.sourceVideo,
        );
      }
    });
  }

  Future<void> _startCompression() async {
    // Storage check: ensure at least 50MB and source size available
    if (_freeStorageBytes > 0 && _freeStorageBytes < (widget.sourceVideo.fileSize + 50 * 1024 * 1024)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Low Storage Warning'),
          content: Text(
            'Your device has only ${Formatters.formatBytes(_freeStorageBytes)} of free space. Compression might fail if storage runs out. Do you want to proceed anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed', style: TextStyle(color: AppColors.warning)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final outputPath = await widget.compressorService.generateOutputPath(
      widget.sourceVideo.fileName,
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CompressionProgressScreen(
          sourceVideo: widget.sourceVideo,
          config: _currentConfig,
          outputPath: outputPath,
          compressorService: widget.compressorService,
          historyRepository: widget.historyRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Compression'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Summary Card
            VideoSummaryCard(
              video: widget.sourceVideo,
              onPreview: () {
                widget.compressorService.openVideoFile(widget.sourceVideo.uri);
              },
              onChangeVideo: () async {
                final newVideo = await widget.compressorService.pickVideo();
                if (newVideo != null && context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CompressionSetupScreen(
                        sourceVideo: newVideo,
                        compressorService: widget.compressorService,
                        historyRepository: widget.historyRepository,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Presets Header
            Text(
              'Select Compression Preset',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // Presets List
            PresetCard(
              preset: CompressionPreset.balanced,
              isSelected: _selectedPreset == CompressionPreset.balanced,
              sourceVideo: widget.sourceVideo,
              onTap: () => _onPresetSelected(CompressionPreset.balanced),
            ),
            PresetCard(
              preset: CompressionPreset.highQuality,
              isSelected: _selectedPreset == CompressionPreset.highQuality,
              sourceVideo: widget.sourceVideo,
              onTap: () => _onPresetSelected(CompressionPreset.highQuality),
            ),
            PresetCard(
              preset: CompressionPreset.smallSize,
              isSelected: _selectedPreset == CompressionPreset.smallSize,
              sourceVideo: widget.sourceVideo,
              onTap: () => _onPresetSelected(CompressionPreset.smallSize),
            ),
            PresetCard(
              preset: CompressionPreset.custom,
              isSelected: _selectedPreset == CompressionPreset.custom,
              sourceVideo: widget.sourceVideo,
              onTap: () => _onPresetSelected(CompressionPreset.custom),
            ),

            // Custom Settings Panel (Collapsible)
            if (_isCustomExpanded || _selectedPreset == CompressionPreset.custom)
              CustomSettingsPanel(
                sourceVideo: widget.sourceVideo,
                currentConfig: _currentConfig,
                onChanged: (newConfig) {
                  setState(() {
                    _currentConfig = newConfig;
                  });
                },
              ),

            const SizedBox(height: 12),

            // Quality & Privacy note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The original video will NOT be modified or overwritten. Output is encoded to universal MP4 with AAC audio.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Start Compression CTA
            FilledButton.icon(
              onPressed: _startCompression,
              icon: const Icon(Icons.bolt_rounded, size: 22),
              label: const Text('Start Compression'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
