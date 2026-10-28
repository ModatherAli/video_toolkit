import 'dart:math' as math;

class VideoCalculator {
  VideoCalculator._();

  /// Calculates scaled target dimensions maintaining aspect ratio, without upscaling.
  /// Ensures both width and height are even numbers (required by H.264 encoders).
  static (int, int) calculateDimensions({
    required int sourceWidth,
    required int sourceHeight,
    required int maxDimension,
  }) {
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return (1280, 720);
    }

    final isPortrait = sourceHeight > sourceWidth;
    final longSide = math.max(sourceWidth, sourceHeight);
    final shortSide = math.min(sourceWidth, sourceHeight);

    // If source is already smaller than or equal to requested dimension, keep source (no upscaling)
    if (shortSide <= maxDimension) {
      final safeW = (sourceWidth ~/ 2) * 2;
      final safeH = (sourceHeight ~/ 2) * 2;
      return (safeW, safeH);
    }

    final aspectRatio = shortSide / longSide;
    final newShortSide = maxDimension;
    final newLongSide = (newShortSide / aspectRatio).round();

    int targetWidth;
    int targetHeight;

    if (isPortrait) {
      targetWidth = newShortSide;
      targetHeight = newLongSide;
    } else {
      targetWidth = newLongSide;
      targetHeight = newShortSide;
    }

    // Ensure dimensions are even numbers (multiples of 2)
    targetWidth = (targetWidth ~/ 2) * 2;
    targetHeight = (targetHeight ~/ 2) * 2;

    return (targetWidth, targetHeight);
  }

  /// Calculates recommended video bitrate in bps based on resolution and preset.
  static int calculateTargetBitrate({
    required int targetWidth,
    required int targetHeight,
    required int sourceBitrate,
    required double qualityMultiplier, // 0.4 for small, 0.7 for balanced, 0.9 for high
  }) {
    final pixels = targetWidth * targetHeight;

    // Baseline bitrates for standard resolutions (at 30fps)
    int baseBitrate;
    if (pixels >= 1920 * 1080) {
      baseBitrate = 4500000; // 4.5 Mbps for 1080p
    } else if (pixels >= 1280 * 720) {
      baseBitrate = 2200000; // 2.2 Mbps for 720p
    } else if (pixels >= 854 * 480) {
      baseBitrate = 1000000; // 1.0 Mbps for 480p
    } else {
      baseBitrate = 600000; // 600 kbps for 360p
    }

    var target = (baseBitrate * qualityMultiplier).round();

    // If source bitrate is known and smaller than our target, don't exceed source bitrate
    if (sourceBitrate > 100000 && target > sourceBitrate) {
      target = (sourceBitrate * qualityMultiplier).round();
    }

    // Clamp between 300 kbps and 10 Mbps
    return target.clamp(300000, 10000000);
  }

  /// Calculates video bitrate in bps needed to hit an exact target file size.
  /// Deducts audio bitrate (default 128 kbps) and leaves a 5% margin for MP4 container overhead.
  static int calculateBitrateForTargetSize({
    required int targetSizeBytes,
    required int durationMs,
    int audioBitrate = 128000,
  }) {
    final durationSec = math.max(1.0, durationMs / 1000.0);
    // 95% for media payload to prevent exceeding limit due to MP4 metadata/container
    final totalAvailableBitrate = (targetSizeBytes * 8 * 0.95) / durationSec;
    final videoBitrate = (totalAvailableBitrate - audioBitrate).round();

    // Clamp between 150 kbps (ultra compact) and 25 Mbps
    return videoBitrate.clamp(150000, 25000000);
  }

  /// Determines optimal resolution cap based on available video bitrate to prevent pixelation.
  static int getRecommendedMaxDimensionForBitrate(int videoBitrate) {
    if (videoBitrate >= 2500000) return 1080;
    if (videoBitrate >= 1100000) return 720;
    if (videoBitrate >= 450000) return 480;
    if (videoBitrate >= 240000) return 360;
    return 240;
  }

  /// Estimates the compressed file size in bytes given bitrates and duration.
  static int estimateCompressedSizeBytes({
    required int videoBitrate,
    required int durationMs,
    int audioBitrate = 128000,
  }) {
    final durationSec = durationMs / 1000.0;
    final totalBitrate = videoBitrate + audioBitrate;
    // 1.03 for MP4 moov/mdat container overhead
    return ((totalBitrate / 8.0) * durationSec * 1.03).round();
  }

  /// Evaluates estimated visual quality based on target bitrate and resolution.
  static ({String label, String detail}) estimateQualityDescription({
    required int videoBitrate,
    required int width,
    required int height,
  }) {
    final pixels = width * height;
    final bitsPerPixel = videoBitrate / (pixels > 0 ? pixels : 1280 * 720);

    if (bitsPerPixel >= 2.5) {
      return (
        label: 'Excellent',
        detail: 'Sharp details, pristine faces & readable text.'
      );
    } else if (bitsPerPixel >= 1.2) {
      return (
        label: 'Great',
        detail: 'Clear faces and motion. Perfect for social sharing.'
      );
    } else if (bitsPerPixel >= 0.6) {
      return (
        label: 'Good (Fit for Chat)',
        detail: 'Good visibility. Fine background details may soften.'
      );
    } else {
      return (
        label: 'Maximum Savings',
        detail: 'High compression. Noticeable softening, small file.'
      );
    }
  }

  /// Formats resolution into a user-friendly label (e.g. 1080p, 720p, 480p).
  static String getResolutionLabel(int width, int height) {
    if (width <= 0 || height <= 0) return 'Unknown';
    final shortSide = math.min(width, height);
    if (shortSide >= 2160) return '4K UHD ($width×$height)';
    if (shortSide >= 1440) return '2K QHD ($width×$height)';
    if (shortSide >= 1080) return '1080p Full HD ($width×$height)';
    if (shortSide >= 720) return '720p HD ($width×$height)';
    if (shortSide >= 480) return '480p SD ($width×$height)';
    return '${shortSide}p ($width×$height)';
  }
}
