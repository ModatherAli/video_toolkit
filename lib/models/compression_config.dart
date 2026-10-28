import '../utils/video_calculator.dart';
import 'video_info.dart';

enum CompressionPreset {
  highQuality,
  balanced,
  smallSize,
  whatsApp,
  discord,
  email,
  targetSize,
  custom;

  String get title {
    switch (this) {
      case CompressionPreset.highQuality:
        return 'High Quality';
      case CompressionPreset.balanced:
        return 'Balanced';
      case CompressionPreset.smallSize:
        return 'Small Size';
      case CompressionPreset.whatsApp:
        return 'Fit for WhatsApp';
      case CompressionPreset.discord:
        return 'Fit for Discord';
      case CompressionPreset.email:
        return 'Fit for Email';
      case CompressionPreset.targetSize:
        return 'Target File Size';
      case CompressionPreset.custom:
        return 'Custom Settings';
    }
  }

  String get subtitle {
    switch (this) {
      case CompressionPreset.highQuality:
        return 'Preserve resolution & sharp detail with moderate compression';
      case CompressionPreset.balanced:
        return 'Best balance of quality & file size. Ideal for general social sharing';
      case CompressionPreset.smallSize:
        return 'Maximum space savings. Scaled to 480p for ultra-light weight';
      case CompressionPreset.whatsApp:
        return 'Optimized to land under 14 MB (WhatsApp media limit is 16 MB)';
      case CompressionPreset.discord:
        return 'Compressed to under 9 MB for standard free Discord upload limit';
      case CompressionPreset.email:
        return 'Compressed to under 20 MB for standard email attachments (25 MB limit)';
      case CompressionPreset.targetSize:
        return 'Enter exact target size in MB; resolution & bitrate adapt automatically';
      case CompressionPreset.custom:
        return 'Manually customize target resolution, bitrate, and audio';
    }
  }

  String? get badge {
    switch (this) {
      case CompressionPreset.balanced:
        return 'RECOMMENDED';
      case CompressionPreset.whatsApp:
        return 'POPULAR';
      default:
        return null;
    }
  }

  bool get isAppPreset =>
      this == CompressionPreset.whatsApp ||
      this == CompressionPreset.discord ||
      this == CompressionPreset.email ||
      this == CompressionPreset.targetSize;
}

class CompressionConfig {
  final CompressionPreset preset;
  final int targetWidth;
  final int targetHeight;
  final int videoBitrate; // in bps (e.g. 2_000_000)
  final bool preserveAudio;
  final String videoCodec; // "H264" or "H265"
  final String audioCodec; // "AAC"
  final double? targetFileSizeMB;

  const CompressionConfig({
    required this.preset,
    required this.targetWidth,
    required this.targetHeight,
    required this.videoBitrate,
    this.preserveAudio = true,
    this.videoCodec = 'H264',
    this.audioCodec = 'AAC',
    this.targetFileSizeMB,
  });

  /// Factory to generate optimal encoder settings for a preset based on the source video.
  factory CompressionConfig.fromPreset({
    required CompressionPreset preset,
    required VideoInfo source,
    double? customTargetMB,
    String videoCodec = 'H264',
  }) {
    int targetWidth;
    int targetHeight;
    int targetBitrate;
    double? targetMB = customTargetMB;

    switch (preset) {
      case CompressionPreset.highQuality:
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

      case CompressionPreset.whatsApp:
        targetMB = 14.0;
        final targetBytes = (targetMB * 1024 * 1024).round();
        targetBitrate = VideoCalculator.calculateBitrateForTargetSize(
          targetSizeBytes: targetBytes,
          durationMs: source.durationMs,
        );
        final maxDim = VideoCalculator.getRecommendedMaxDimensionForBitrate(targetBitrate);
        final dims = VideoCalculator.calculateDimensions(
          sourceWidth: source.width,
          sourceHeight: source.height,
          maxDimension: maxDim,
        );
        targetWidth = dims.$1;
        targetHeight = dims.$2;
        break;

      case CompressionPreset.discord:
        targetMB = 9.0;
        final targetBytes = (targetMB * 1024 * 1024).round();
        targetBitrate = VideoCalculator.calculateBitrateForTargetSize(
          targetSizeBytes: targetBytes,
          durationMs: source.durationMs,
        );
        final maxDim = VideoCalculator.getRecommendedMaxDimensionForBitrate(targetBitrate);
        final dims = VideoCalculator.calculateDimensions(
          sourceWidth: source.width,
          sourceHeight: source.height,
          maxDimension: maxDim,
        );
        targetWidth = dims.$1;
        targetHeight = dims.$2;
        break;

      case CompressionPreset.email:
        targetMB = 20.0;
        final targetBytes = (targetMB * 1024 * 1024).round();
        targetBitrate = VideoCalculator.calculateBitrateForTargetSize(
          targetSizeBytes: targetBytes,
          durationMs: source.durationMs,
        );
        final maxDim = VideoCalculator.getRecommendedMaxDimensionForBitrate(targetBitrate);
        final dims = VideoCalculator.calculateDimensions(
          sourceWidth: source.width,
          sourceHeight: source.height,
          maxDimension: maxDim,
        );
        targetWidth = dims.$1;
        targetHeight = dims.$2;
        break;

      case CompressionPreset.targetSize:
        targetMB ??= 10.0;
        final targetBytes = (targetMB * 1024 * 1024).round();
        targetBitrate = VideoCalculator.calculateBitrateForTargetSize(
          targetSizeBytes: targetBytes,
          durationMs: source.durationMs,
        );
        final maxDim = VideoCalculator.getRecommendedMaxDimensionForBitrate(targetBitrate);
        final dims = VideoCalculator.calculateDimensions(
          sourceWidth: source.width,
          sourceHeight: source.height,
          maxDimension: maxDim,
        );
        targetWidth = dims.$1;
        targetHeight = dims.$2;
        break;

      case CompressionPreset.custom:
        targetWidth = source.width;
        targetHeight = source.height;
        targetBitrate = source.bitrate > 0 ? (source.bitrate * 0.7).round() : 2000000;
        break;
    }

    // H.265 (HEVC) delivers equivalent visual quality at ~30% lower bitrate
    if (videoCodec == 'H265') {
      targetBitrate = (targetBitrate * 0.70).round().clamp(120000, 20000000);
    }

    // Safety guard: if output bitrate exceeds source bitrate, don't bloat file
    if (source.bitrate > 100000 && targetBitrate > source.bitrate) {
      targetBitrate = (source.bitrate * 0.95).round();
    }

    return CompressionConfig(
      preset: preset,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      videoBitrate: targetBitrate,
      preserveAudio: true,
      videoCodec: videoCodec,
      audioCodec: 'AAC',
      targetFileSizeMB: targetMB,
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
    double? targetFileSizeMB,
  }) {
    return CompressionConfig(
      preset: preset ?? this.preset,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      preserveAudio: preserveAudio ?? this.preserveAudio,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      targetFileSizeMB: targetFileSizeMB ?? this.targetFileSizeMB,
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
      'targetFileSizeMB': targetFileSizeMB,
    };
  }
}
