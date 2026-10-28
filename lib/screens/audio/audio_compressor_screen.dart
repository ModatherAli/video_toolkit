import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/audio_compression_config.dart';
import '../../services/audio_toolkit_service.dart';
import '../../services/video_compressor_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class AudioCompressorScreen extends StatefulWidget {
  final VideoCompressorService compressorService;

  const AudioCompressorScreen({super.key, required this.compressorService});

  @override
  State<AudioCompressorScreen> createState() => _AudioCompressorScreenState();
}

class _AudioCompressorScreenState extends State<AudioCompressorScreen> {
  late final AudioToolkitService _audioService;
  AudioFileItem? _selectedAudio;
  AudioCompressionConfig _config = AudioCompressionConfig.fromPreset(AudioPreset.voicePodcast);

  bool _isCompressing = false;
  String? _compressedOutputPath;
  int? _compressedSizeBytes;

  @override
  void initState() {
    super.initState();
    _audioService = AudioToolkitService(compressorService: widget.compressorService);
  }

  Future<void> _pickAudio() async {
    final item = await _audioService.pickAudioFile();
    if (item != null && mounted) {
      setState(() {
        _selectedAudio = item;
        _compressedOutputPath = null;
        _compressedSizeBytes = null;
      });
    }
  }

  Future<void> _startAudioCompression() async {
    if (_selectedAudio == null) return;

    setState(() {
      _isCompressing = true;
    });

    try {
      final outPath = await _audioService.generateAudioOutputPath(
        _selectedAudio!.name,
        _config.format,
      );

      final success = await _audioService.compressAudio(
        source: _selectedAudio!,
        config: _config,
        outputPath: outPath,
      );

      if (success && mounted) {
        final outBytes = File(outPath).existsSync() ? File(outPath).lengthSync() : 0;
        setState(() {
          _compressedOutputPath = outPath;
          _compressedSizeBytes = outBytes;
          _isCompressing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio compression finished successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        if (mounted) {
          setState(() => _isCompressing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio compression failed.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompressing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Compressor & Studio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Audio Selection Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mic_rounded, color: colorScheme.onPrimaryContainer, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _selectedAudio != null ? _selectedAudio!.name : 'Compress Audio & Podcasts',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedAudio != null
                        ? 'Original Size: ${Formatters.formatBytes(_selectedAudio!.sizeBytes)}'
                        : 'MP3, M4A, WAV, FLAC, OGG voice notes & lectures',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickAudio,
                    icon: const Icon(Icons.audio_file_rounded),
                    label: Text(_selectedAudio != null ? 'Change Audio File' : 'Select Audio File'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mode Selector
            Text(
              'Select Audio Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),

            _buildPresetOption(
              preset: AudioPreset.voicePodcast,
              icon: Icons.podcasts_rounded,
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildPresetOption(
              preset: AudioPreset.lectureSpeech,
              icon: Icons.record_voice_over_rounded,
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildPresetOption(
              preset: AudioPreset.musicHighQuality,
              icon: Icons.music_note_rounded,
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Speech DSP Filters Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DSP Speech Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Convert to Mono (Speech)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Cuts size in half without degrading human vocal clarity.', style: TextStyle(fontSize: 11)),
                    value: _config.isMono,
                    onChanged: (val) => setState(() => _config = _config.copyWith(isMono: val)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Trim Silence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Removes prolonged pauses in speech, podcasts, and sermons.', style: TextStyle(fontSize: 11)),
                    value: _config.trimSilence,
                    onChanged: (val) => setState(() => _config = _config.copyWith(trimSilence: val)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Normalize Loudness', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Evens out loud and quiet speakers for balanced listening.', style: TextStyle(fontSize: 11)),
                    value: _config.normalizeLoudness,
                    onChanged: (val) => setState(() => _config = _config.copyWith(normalizeLoudness: val)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Result Card if completed
            if (_compressedOutputPath != null && _compressedSizeBytes != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withAlpha(80)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success),
                        SizedBox(width: 8),
                        Text('Compressed File Ready', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Size: ${Formatters.formatBytes(_compressedSizeBytes!)}'),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                          onPressed: () {
                            SharePlus.instance.share(
                              ShareParams(
                                files: [XFile(_compressedOutputPath!)],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Compress Action Button
            FilledButton.icon(
              onPressed: (_selectedAudio != null && !_isCompressing) ? _startAudioCompression : null,
              icon: _isCompressing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bolt_rounded),
              label: Text(_isCompressing ? 'Compressing Audio...' : 'Compress Audio'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetOption({
    required AudioPreset preset,
    required IconData icon,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final isSelected = _config.preset == preset;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _config = AudioCompressionConfig.fromPreset(preset);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withAlpha(90) : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withAlpha(120),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    preset.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
