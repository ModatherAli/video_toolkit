import 'package:flutter_test/flutter_test.dart';
import 'package:video_toolkit/models/compression_config.dart';
import 'package:video_toolkit/models/history_item.dart';
import 'package:video_toolkit/models/video_info.dart';
import 'package:video_toolkit/utils/formatters.dart';
import 'package:video_toolkit/utils/video_calculator.dart';

void main() {
  group('Formatters Tests', () {
    test('formatBytes handles zero and various sizes', () {
      expect(Formatters.formatBytes(0), '0 B');
      expect(Formatters.formatBytes(500), '500.0 B');
      expect(Formatters.formatBytes(1024), '1.0 KB');
      expect(Formatters.formatBytes(1024 * 1024 * 45), '45.0 MB');
      expect(Formatters.formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
    });

    test('formatDuration formats MM:SS and HH:MM:SS properly', () {
      expect(Formatters.formatDuration(const Duration(seconds: 45)), '00:45');
      expect(Formatters.formatDuration(const Duration(minutes: 3, seconds: 12)), '03:12');
      expect(Formatters.formatDuration(const Duration(hours: 1, minutes: 24, seconds: 8)), '01:24:08');
    });

    test('formatBitrate formats bps to Mbps and kbps', () {
      expect(Formatters.formatBitrate(0), 'Auto');
      expect(Formatters.formatBitrate(800000), '800 kbps');
      expect(Formatters.formatBitrate(2500000), '2.5 Mbps');
    });
  });

  group('VideoCalculator Tests', () {
    test('calculateDimensions downsizes 1080p landscape to 720p correctly and keeps even numbers', () {
      final dims = VideoCalculator.calculateDimensions(
        sourceWidth: 1920,
        sourceHeight: 1080,
        maxDimension: 720,
      );
      expect(dims.$1, 1280);
      expect(dims.$2, 720);
      expect(dims.$1 % 2, 0);
      expect(dims.$2 % 2, 0);
    });

    test('calculateDimensions downsizes 1080p portrait to 480p correctly', () {
      final dims = VideoCalculator.calculateDimensions(
        sourceWidth: 1080,
        sourceHeight: 1920,
        maxDimension: 480,
      );
      expect(dims.$1, 480);
      expect(dims.$2, 852); // nearest even for 853.33
      expect(dims.$1 % 2, 0);
      expect(dims.$2 % 2, 0);
    });

    test('calculateDimensions avoids upscaling when source is smaller than target', () {
      final dims = VideoCalculator.calculateDimensions(
        sourceWidth: 640,
        sourceHeight: 360,
        maxDimension: 720,
      );
      expect(dims.$1, 640);
      expect(dims.$2, 360);
    });

    test('getResolutionLabel provides clear descriptions', () {
      expect(VideoCalculator.getResolutionLabel(1920, 1080), '1080p Full HD (1920×1080)');
      expect(VideoCalculator.getResolutionLabel(1280, 720), '720p HD (1280×720)');
      expect(VideoCalculator.getResolutionLabel(854, 480), '480p SD (854×480)');
    });
  });

  group('Data Models & Presets Tests', () {
    const sampleVideo = VideoInfo(
      uri: '/storage/sample.mp4',
      fileName: 'trip.mp4',
      fileSize: 100 * 1024 * 1024, // 100 MB
      duration: Duration(minutes: 2),
      width: 1920,
      height: 1080,
      rotation: 0,
      bitrate: 6000000,
      mimeType: 'video/mp4',
    );

    test('High Quality preset keeps source resolution up to 1080p', () {
      final config = CompressionConfig.fromPreset(
        preset: CompressionPreset.highQuality,
        source: sampleVideo,
      );
      expect(config.targetWidth, 1920);
      expect(config.targetHeight, 1080);
      expect(config.preserveAudio, isTrue);
      expect(config.videoCodec, 'H264');
    });

    test('Balanced preset targets 720p', () {
      final config = CompressionConfig.fromPreset(
        preset: CompressionPreset.balanced,
        source: sampleVideo,
      );
      expect(config.targetWidth, 1280);
      expect(config.targetHeight, 720);
      expect(config.videoBitrate, lessThan(sampleVideo.bitrate));
    });

    test('Small Size preset targets 480p', () {
      final config = CompressionConfig.fromPreset(
        preset: CompressionPreset.smallSize,
        source: sampleVideo,
      );
      expect(config.targetWidth, 852);
      expect(config.targetHeight, 480);
      expect(config.videoBitrate, lessThan(1500000));
    });

    test('HistoryItem calculates savings percentage and serializes to/from JSON correctly', () {
      final item = HistoryItem(
        id: '123',
        fileName: 'trip.mp4',
        originalPath: '/storage/sample.mp4',
        compressedPath: '/cache/trip_opti.mp4',
        originalSizeBytes: 100 * 1024 * 1024,
        compressedSizeBytes: 35 * 1024 * 1024,
        durationMs: 120000,
        resolution: '1280×720',
        timestamp: DateTime(2026, 5, 10, 14, 30),
      );

      expect(item.isSmaller, isTrue);
      expect(item.savedBytes, 65 * 1024 * 1024);
      expect(item.savingsPercentage.round(), 65);

      final json = item.toJson();
      final revived = HistoryItem.fromJson(json);

      expect(revived.id, item.id);
      expect(revived.fileName, item.fileName);
      expect(revived.compressedSizeBytes, item.compressedSizeBytes);
      expect(revived.resolution, item.resolution);
    });
  });
}
