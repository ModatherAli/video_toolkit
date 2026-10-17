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
