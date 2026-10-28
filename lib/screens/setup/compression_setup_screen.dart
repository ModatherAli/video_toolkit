import 'package:flutter/material.dart';
import '../../models/compression_config.dart';
import '../../models/video_info.dart';
import '../../services/history_repository.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/video_calculator.dart';
import '../processing/compression_progress_screen.dart';
import 'widgets/custom_settings_panel.dart';
import 'widgets/preset_card.dart';
import 'widgets/quick_sample_preview_dialog.dart';
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
  int _selectedTabIndex = 0; // 0: Fit to App, 1: Smart Presets, 2: Target Size, 3: Advanced
  late CompressionPreset _selectedPreset;
  late CompressionConfig _currentConfig;
  double _customTargetMB = 10.0;
  String _selectedCodec = 'H264';
  int _freeStorageBytes = 0;

  @override
  void initState() {
    super.initState();
    _selectedPreset = CompressionPreset.whatsApp; // Hero feature from search findings
    _updateConfig();
    _checkStorage();
  }

  void _updateConfig() {
    _currentConfig = CompressionConfig.fromPreset(
      preset: _selectedPreset,
      source: widget.sourceVideo,
      customTargetMB: _customTargetMB,
      videoCodec: _selectedCodec,
    );
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
      _updateConfig();
    });
  }

  Future<void> _showQuickSample() async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuickSamplePreviewDialog(
        sourceVideo: widget.sourceVideo,
        config: _currentConfig,
        compressorService: widget.compressorService,
      ),
    );

    if (proceed == true && mounted) {
      _startCompression();
    }
  }

  Future<void> _startCompression() async {
    if (_freeStorageBytes > 0 &&
        _freeStorageBytes < (widget.sourceVideo.fileSize + 50 * 1024 * 1024)) {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final estimatedBytes = VideoCalculator.estimateCompressedSizeBytes(
      videoBitrate: _currentConfig.videoBitrate,
      durationMs: widget.sourceVideo.durationMs,
    );
    final savingsPct = widget.sourceVideo.fileSize > 0
        ? (((widget.sourceVideo.fileSize - estimatedBytes) / widget.sourceVideo.fileSize) * 100)
            .clamp(0.0, 99.0)
        : 0.0;
    final quality = VideoCalculator.estimateQualityDescription(
      videoBitrate: _currentConfig.videoBitrate,
      width: _currentConfig.targetWidth,
      height: _currentConfig.targetHeight,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Compression'),
        actions: [
          IconButton(
            tooltip: 'Quick 5s Sample Preview',
            icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary),
            onPressed: _showQuickSample,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 18),

            // Mode Selector Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip(0, 'Fit to App', Icons.apps_rounded),
                  const SizedBox(width: 8),
                  _buildTabChip(1, 'Target Size', Icons.straighten_rounded),
                  const SizedBox(width: 8),
                  _buildTabChip(2, 'Smart Quality', Icons.auto_awesome_rounded),
                  const SizedBox(width: 8),
                  _buildTabChip(3, 'Advanced', Icons.tune_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            if (_selectedTabIndex == 0) ...[
              PresetCard(
                preset: CompressionPreset.whatsApp,
                isSelected: _selectedPreset == CompressionPreset.whatsApp,
                sourceVideo: widget.sourceVideo,
                onTap: () => _onPresetSelected(CompressionPreset.whatsApp),
              ),
              const SizedBox(height: 10),
              PresetCard(
                preset: CompressionPreset.discord,
                isSelected: _selectedPreset == CompressionPreset.discord,
                sourceVideo: widget.sourceVideo,
                onTap: () => _onPresetSelected(CompressionPreset.discord),
              ),
              const SizedBox(height: 10),
              PresetCard(
                preset: CompressionPreset.email,
                isSelected: _selectedPreset == CompressionPreset.email,
                sourceVideo: widget.sourceVideo,
                onTap: () => _onPresetSelected(CompressionPreset.email),
              ),
            ] else if (_selectedTabIndex == 1) ...[
              // Target Size Slider Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _selectedPreset == CompressionPreset.targetSize
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withAlpha(120),
                    width: _selectedPreset == CompressionPreset.targetSize ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          'Choose Max File Size',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '< ${_customTargetMB.toStringAsFixed(1)} MB',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Slider(
                      value: _customTargetMB,
                      min: 3.0,
                      max: 100.0,
                      divisions: 97,
                      label: '${_customTargetMB.toStringAsFixed(0)} MB',
                      onChanged: (val) {
                        setState(() {
                          _selectedPreset = CompressionPreset.targetSize;
                          _customTargetMB = val;
                          _updateConfig();
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickTargetBtn(5.0),
                        _buildQuickTargetBtn(10.0),
                        _buildQuickTargetBtn(16.0),
                        _buildQuickTargetBtn(25.0),
                        _buildQuickTargetBtn(50.0),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_selectedTabIndex == 2) ...[
              PresetCard(
                preset: CompressionPreset.balanced,
                isSelected: _selectedPreset == CompressionPreset.balanced,
                sourceVideo: widget.sourceVideo,
                onTap: () => _onPresetSelected(CompressionPreset.balanced),
              ),
              const SizedBox(height: 10),
              PresetCard(
                preset: CompressionPreset.highQuality,
                isSelected: _selectedPreset == CompressionPreset.highQuality,
                sourceVideo: widget.sourceVideo,
                onTap: () => _onPresetSelected(CompressionPreset.highQuality),
              ),
              const SizedBox(height: 10),
              PresetCard(
                preset: CompressionPreset.smallSize,
                isSelected: _selectedPreset == CompressionPreset.smallSize,
                sourceVideo: widget.sourceVideo,
                onTap: () => _onPresetSelected(CompressionPreset.smallSize),
              ),
            ] else ...[
              // Advanced / Custom Panel
              CustomSettingsPanel(
                sourceVideo: widget.sourceVideo,
                currentConfig: _currentConfig,
                onChanged: (newConfig) {
                  setState(() {
                    _currentConfig = newConfig;
                  });
                },
              ),
            ],

            const SizedBox(height: 18),

            // Codec Selection Pills (Compatible H.264 vs Smaller H.265)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.memory_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text('Video Codec:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  ChoiceChip(
                    label: const Text('H.264 (Compatible)', style: TextStyle(fontSize: 11)),
                    selected: _selectedCodec == 'H264',
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _selectedCodec = 'H264';
                          _updateConfig();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('H.265 (Smaller)', style: TextStyle(fontSize: 11)),
                    selected: _selectedCodec == 'H265',
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _selectedCodec = 'H265';
                          _updateConfig();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Quality & Estimation Dashboard Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.primary.withAlpha(70)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated Output • ${Formatters.formatBytes(estimatedBytes)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${savingsPct.toStringAsFixed(0)}% space',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          quality.label,
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quality.detail,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons: Quick 5s Sample & Start Compression
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _showQuickSample,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Quick 5s Sample'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: _startCompression,
                    icon: const Icon(Icons.bolt_rounded, size: 22),
                    label: const Text('Compress Video'),
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

  Widget _buildTabChip(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
      ),
      selectedColor: colorScheme.primary,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTabIndex = index;
            if (index == 0) {
              _selectedPreset = CompressionPreset.whatsApp;
            } else if (index == 1) {
              _selectedPreset = CompressionPreset.targetSize;
            } else if (index == 2) {
              _selectedPreset = CompressionPreset.balanced;
            } else {
              _selectedPreset = CompressionPreset.custom;
            }
            _updateConfig();
          });
        }
      },
    );
  }

  Widget _buildQuickTargetBtn(double mb) {
    final isSelected = (_customTargetMB - mb).abs() < 0.1 && _selectedPreset == CompressionPreset.targetSize;
    return ChoiceChip(
      label: Text('${mb.toInt()}MB', style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _selectedPreset = CompressionPreset.targetSize;
            _customTargetMB = mb;
            _updateConfig();
          });
        }
      },
    );
  }
}
