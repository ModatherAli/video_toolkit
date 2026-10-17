import '../utils/video_calculator.dart';
import 'video_info.dart';

enum CompressionPreset {
  highQuality,
  balanced,
  smallSize,
  custom;

  String get title {
    switch (this) {
      case CompressionPreset.highQuality:
        return 'High Quality';
      case CompressionPreset.balanced:
        return 'Balanced';
      case CompressionPreset.smallSize:
        return 'Small Size';
      case CompressionPreset.custom:
        return 'Custom Settings';
    }
  }

  String get subtitle {
    switch (this) {
      case CompressionPreset.highQuality:
        return 'Preserve resolution & sharp detail with moderate compression';
      case CompressionPreset.balanced:
        return 'Best balance of quality & file size. Ideal for messaging & social apps';
      case CompressionPreset.smallSize:
        return 'Maximum space savings. Scaled to 480p for fast sending';
      case CompressionPreset.custom:
        return 'Manually customize target resolution, bitrate, and audio';
    }
  }

  String? get badge {
    switch (this) {
      case CompressionPreset.balanced:
        return 'RECOMMENDED';
      default:
        return null;
    }
  }
}

class CompressionConfig {
  final CompressionPreset preset;
  final int targetWidth;
  final int targetHeight;
  final int videoBitrate; // in bps (e.g. 2_000_000)
  final bool preserveAudio;
  final String videoCodec; // "H264"
  final String audioCodec; // "AAC"

  const CompressionConfig({
    required this.preset,
    required this.targetWidth,
    required this.targetHeight,
    required this.videoBitrate,
    this.preserveAudio = true,
    this.videoCodec = 'H264',
    this.audioCodec = 'AAC',
  });

  /// Factory to generate optimal encoder settings for a preset based on the source video.
  factory CompressionConfig.fromPreset({
    required CompressionPreset preset,
    required VideoInfo source,
  }) {
    int targetWidth;
    int targetHeight;
    int targetBitrate;

    switch (preset) {
      case CompressionPreset.highQuality:
        // Cap at 1080p if source is 4K, otherwise preserve source resolution (no upscaling)
        final dims = VideoCalculator.calculateDimensions(
          sourceWidth: source.width,
          sourceHeight: source.height,
          maxDimension: 1080,
        );
        targetWidth = dims.$1;
        targetHeight = dims.$2;
        targetBitrate = VideoCalculator.calculateTargetBitrate(
          targetWidth: targetWidth,
          targetHeight: targetHeight,
          sourceBitrate: source.bitrate,
          qualityMultiplier: 0.85,
        );
        break;

      case CompressionPreset.balanced:
        // Cap at 720p (no upscaling)
        final dims = VideoCalculator.calculateDimensions(
          sourceWidth: source.width,
          sourceHeight: source.height,
          maxDimension: 720,
        );
        targetWidth = dims.$1;
        targetHeight = dims.$2;
        targetBitrate = VideoCalculator.calculateTargetBitrate(
          targetWidth: targetWidth,
          targetHeight: targetHeight,
          sourceBitrate: source.bitrate,
          qualityMultiplier: 0.65,
        );
        break;

      case CompressionPreset.smallSize:
        // Cap at 480p (no upscaling)
        final dims = VideoCalculator.calculateDimensions(
          sourceWidth: source.width,
          sourceHeight: source.height,
          maxDimension: 480,
        );
        targetWidth = dims.$1;
        targetHeight = dims.$2;
        targetBitrate = VideoCalculator.calculateTargetBitrate(
          targetWidth: targetWidth,
          targetHeight: targetHeight,
          sourceBitrate: source.bitrate,
          qualityMultiplier: 0.40,
        );
        break;

      case CompressionPreset.custom:
        targetWidth = source.width;
        targetHeight = source.height;
        targetBitrate = source.bitrate > 0 ? (source.bitrate * 0.7).round() : 2000000;
        break;
    }

    return CompressionConfig(
      preset: preset,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      videoBitrate: targetBitrate,
      preserveAudio: true,
      videoCodec: 'H264',
      audioCodec: 'AAC',
    );
  }

  CompressionConfig copyWith({
    CompressionPreset? preset,
    int? targetWidth,
    int? targetHeight,
    int? videoBitrate,
    bool? preserveAudio,
    String? videoCodec,
    String? audioCodec,
  }) {
    return CompressionConfig(
      preset: preset ?? this.preset,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      preserveAudio: preserveAudio ?? this.preserveAudio,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
    );
  }

  Map<String, dynamic> toMap({required String sourceUri, required String outputPath}) {
    return {
      'sourceUri': sourceUri,
      'outputPath': outputPath,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
      'videoBitrate': videoBitrate,
      'preserveAudio': preserveAudio,
      'videoCodec': videoCodec,
      'audioCodec': audioCodec,
    };
  }
}
