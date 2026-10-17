import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/compression_config.dart';
import '../../../models/video_info.dart';
import '../../../utils/formatters.dart';
import '../../../utils/video_calculator.dart';

class CustomSettingsPanel extends StatefulWidget {
  final VideoInfo sourceVideo;
  final CompressionConfig currentConfig;
  final ValueChanged<CompressionConfig> onChanged;

  const CustomSettingsPanel({
    super.key,
    required this.sourceVideo,
    required this.currentConfig,
    required this.onChanged,
  });

  @override
  State<CustomSettingsPanel> createState() => _CustomSettingsPanelState();
}

class _CustomSettingsPanelState extends State<CustomSettingsPanel> {
  late int _selectedMaxDimension;
  late int _selectedBitrate;
  late bool _preserveAudio;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    final shortSide = math.min(widget.sourceVideo.width, widget.sourceVideo.height);
    _selectedMaxDimension = shortSide;
    _selectedBitrate = widget.currentConfig.videoBitrate > 0
        ? widget.currentConfig.videoBitrate
        : 2200000;
    _preserveAudio = widget.currentConfig.preserveAudio;
  }

  void _updateConfig() {
    final dims = VideoCalculator.calculateDimensions(
      sourceWidth: widget.sourceVideo.width,
      sourceHeight: widget.sourceVideo.height,
      maxDimension: _selectedMaxDimension,
    );

    widget.onChanged(
      widget.currentConfig.copyWith(
        preset: CompressionPreset.custom,
        targetWidth: dims.$1,
        targetHeight: dims.$2,
        videoBitrate: _selectedBitrate,
        preserveAudio: _preserveAudio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCustom = widget.currentConfig.preset == CompressionPreset.custom;
    final sourceShortSide = math.min(widget.sourceVideo.width, widget.sourceVideo.height);

    final resolutionOptions = <int, String>{
      sourceShortSide: 'Original (${widget.sourceVideo.width}×${widget.sourceVideo.height})',
    };
    if (sourceShortSide >= 1080) {
      resolutionOptions[1080] = '1080p Full HD';
    }
    if (sourceShortSide >= 720) {
      resolutionOptions[720] = '720p HD';
    }
    if (sourceShortSide >= 480) {
      resolutionOptions[480] = '480p SD';
    }
    resolutionOptions[360] = '360p Compact';

    final currentDims = VideoCalculator.calculateDimensions(
      sourceWidth: widget.sourceVideo.width,
      sourceHeight: widget.sourceVideo.height,
      maxDimension: _selectedMaxDimension,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_suggest_rounded,
                    color: isCustom
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Advanced Settings',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isCustom) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Custom Active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fine-tune resolution, bitrate, and audio track',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: colorScheme.outlineVariant.withAlpha(80)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resolution Dropdown
                  Text(
                    'Target Resolution',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(80),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withAlpha(100),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: resolutionOptions.containsKey(_selectedMaxDimension)
                            ? _selectedMaxDimension
                            : sourceShortSide,
                        items: resolutionOptions.entries.map((entry) {
                          return DropdownMenuItem<int>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: theme.textTheme.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMaxDimension = val;
                            });
                            _updateConfig();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Output Dimensions: ${currentDims.$1} × ${currentDims.$2}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bitrate Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Video Bitrate',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          Formatters.formatBitrate(_selectedBitrate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _selectedBitrate.toDouble().clamp(400000, 8000000),
                    min: 400000,
                    max: 8000000,
                    divisions: 38,
                    label: Formatters.formatBitrate(_selectedBitrate),
                    onChanged: (val) {
                      setState(() {
                        _selectedBitrate = val.toInt();
                      });
                      _updateConfig();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Smaller (400 kbps)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Higher Quality (8 Mbps)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Preserve Audio Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preserve Audio Track',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _preserveAudio
                                ? 'Encodes AAC audio track'
                                : 'Mute audio track (video stream only)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _preserveAudio,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (val) {
                          setState(() {
                            _preserveAudio = val;
                          });
                          _updateConfig();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
