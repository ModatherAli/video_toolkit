import 'package:flutter_test/flutter_test.dart';
import 'package:video_toolkit/models/audio_compression_config.dart';
import 'package:video_toolkit/models/batch_compression_item.dart';
import 'package:video_toolkit/models/compression_config.dart';
import 'package:video_toolkit/models/history_item.dart';
import 'package:video_toolkit/models/storage_cleaner_item.dart';
import 'package:video_toolkit/models/video_info.dart';
import 'package:video_toolkit/services/device_safety_service.dart';
import 'package:video_toolkit/services/video_compressor_service.dart';
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

  group('Milestone 1: Target Size & App Presets Tests', () {
    const testVideo = VideoInfo(
      uri: '/storage/vacation.mp4',
      fileName: 'vacation.mp4',
      fileSize: 80 * 1024 * 1024, // 80 MB
      duration: Duration(seconds: 60), // 1 minute
      width: 1920,
      height: 1080,
      rotation: 0,
      bitrate: 10000000,
      mimeType: 'video/mp4',
    );

    test('calculateBitrateForTargetSize calculates correct budget for 14 MB WhatsApp target', () {
      final bitrate = VideoCalculator.calculateBitrateForTargetSize(
        targetSizeBytes: 14 * 1024 * 1024,
        durationMs: 60000,
      );
      // Expected: (14 * 1024 * 1024 * 8 * 0.95 / 60) - 128000 ≈ 1.64 Mbps
      expect(bitrate, greaterThan(1500000));
      expect(bitrate, lessThan(1800000));
    });

    test('getRecommendedMaxDimensionForBitrate downscales gracefully under low bitrate budgets', () {
      expect(VideoCalculator.getRecommendedMaxDimensionForBitrate(3000000), 1080);
      expect(VideoCalculator.getRecommendedMaxDimensionForBitrate(1500000), 720);
      expect(VideoCalculator.getRecommendedMaxDimensionForBitrate(600000), 480);
      expect(VideoCalculator.getRecommendedMaxDimensionForBitrate(280000), 360);
      expect(VideoCalculator.getRecommendedMaxDimensionForBitrate(180000), 240);
    });

    test('CompressionConfig.fromPreset WhatsApp targets 14MB with appropriate dimension', () {
      final config = CompressionConfig.fromPreset(
        preset: CompressionPreset.whatsApp,
        source: testVideo,
      );
      expect(config.targetFileSizeMB, 14.0);
      expect(config.targetHeight, lessThanOrEqualTo(720));
      expect(config.videoBitrate, lessThan(2000000));
    });

    test('CompressionConfig.fromPreset Discord targets 9MB with appropriate dimension', () {
      final config = CompressionConfig.fromPreset(
        preset: CompressionPreset.discord,
        source: testVideo,
      );
      expect(config.targetFileSizeMB, 9.0);
      expect(config.targetHeight, lessThanOrEqualTo(720));
      expect(config.videoBitrate, lessThan(1300000));
    });

    test('CompressionConfig.fromPreset Email targets 20MB', () {
      final config = CompressionConfig.fromPreset(
        preset: CompressionPreset.email,
        source: testVideo,
      );
      expect(config.targetFileSizeMB, 20.0);
      expect(config.targetHeight, lessThanOrEqualTo(1080));
    });

    test('H.265 codec preset applies bitrate reduction factor', () {
      final configH264 = CompressionConfig.fromPreset(
        preset: CompressionPreset.balanced,
        source: testVideo,
        videoCodec: 'H264',
      );
      final configH265 = CompressionConfig.fromPreset(
        preset: CompressionPreset.balanced,
        source: testVideo,
        videoCodec: 'H265',
      );
      expect(configH265.videoBitrate, lessThan(configH264.videoBitrate));
      expect(configH265.videoCodec, 'H265');
    });
  });

  group('Milestone 2: Storage Cleaner Models Tests', () {
    test('StorageCleanerItem parses map and formats size correctly', () {
      final map = {
        'id': 'item_101',
        'uri': 'content://media/external/video/media/101',
        'path': '/storage/DCIM/Camera/VID_2026.mp4',
        'name': 'VID_2026.mp4',
        'sizeBytes': 2 * 1024 * 1024 * 1024, // 2 GB
        'durationMs': 180000,
        'dateModified': 1715000000,
      };

      final item = StorageCleanerItem.fromMap(map);
      expect(item.id, 'item_101');
      expect(item.name, 'VID_2026.mp4');
      expect(item.sizeBytes, 2 * 1024 * 1024 * 1024);
      expect(item.formattedSize, '2.0 GB');
      expect(item.isSelected, isTrue);
    });
  });

  group('Milestone 3: Audio Toolkit Models Tests', () {
    test('AudioCompressionConfig provides correct bitrates for presets', () {
      final voiceConfig = AudioCompressionConfig.fromPreset(
        AudioPreset.voicePodcast,
      );
      expect(voiceConfig.bitrateKbps, 64);
      expect(voiceConfig.isMono, isTrue);
      expect(voiceConfig.trimSilence, isTrue);
      expect(voiceConfig.normalizeLoudness, isTrue);

      final musicConfig = AudioCompressionConfig.fromPreset(
        AudioPreset.musicHighQuality,
      );
      expect(musicConfig.bitrateKbps, 192);
      expect(musicConfig.isMono, isFalse);
      expect(musicConfig.trimSilence, isFalse);
    });

    test('AudioOutputFormat extensions are consistent', () {
      expect(AudioOutputFormat.m4a.extension, 'm4a');
      expect(AudioOutputFormat.mp3.extension, 'mp3');
      expect(AudioOutputFormat.ogg.extension, 'ogg');
    });
  });

  group('Milestone 4: Device Safety & Batch Status Tests', () {
    test('DeviceSafetyService evaluateSafety triggers warning when battery is below threshold', () {
      final dummyCompressor = VideoCompressorService();
      final safetyService = DeviceSafetyService(compressorService: dummyCompressor);

      safetyService.pauseOnLowBattery = true;
      safetyService.requireCharging = false;
      safetyService.lowBatteryThreshold = 20;

      // Simulate battery = 15%, not charging
      safetyService.batteryLevelNotifier.value = 15;
      safetyService.isChargingNotifier.value = false;
      safetyService.isThermalThrottlingNotifier.value = false;

      final result = safetyService.evaluateSafety();
      expect(result.isSafe, isFalse);
      expect(result.reason, contains('below the safe 20% threshold'));
    });

    test('DeviceSafetyService evaluateSafety allows compression when plugged in even if low battery', () {
      final dummyCompressor = VideoCompressorService();
      final safetyService = DeviceSafetyService(compressorService: dummyCompressor);

      safetyService.pauseOnLowBattery = true;
      safetyService.requireCharging = false;
      safetyService.lowBatteryThreshold = 20;

      // Battery 10% but isCharging = true
      safetyService.batteryLevelNotifier.value = 10;
      safetyService.isChargingNotifier.value = true;
      safetyService.isThermalThrottlingNotifier.value = false;

      final result = safetyService.evaluateSafety();
      expect(result.isSafe, isTrue);
      expect(result.reason, isNull);
    });

    test('BatchCompressionItem state transitions calculate progress correctly', () {
      const vid = VideoInfo(
        uri: '/storage/1.mp4',
        fileName: '1.mp4',
        fileSize: 50 * 1024 * 1024,
        duration: Duration(seconds: 30),
        width: 1920,
        height: 1080,
        rotation: 0,
        bitrate: 4000000,
        mimeType: 'video/mp4',
      );
      final cfg = CompressionConfig.fromPreset(
        preset: CompressionPreset.balanced,
        source: vid,
      );

      var item = BatchCompressionItem(
        id: 'b1',
        source: vid,
        config: cfg,
      );

      expect(item.status, BatchItemStatus.pending);
      expect(item.progress, 0.0);

      item = item.copyWith(
        status: BatchItemStatus.compressing,
        progress: 0.65,
      );
      expect(item.status, BatchItemStatus.compressing);
      expect(item.progress, 0.65);

      item = item.copyWith(
        status: BatchItemStatus.completed,
        progress: 1.0,
        compressedSizeBytes: 15 * 1024 * 1024,
      );
      expect(item.status, BatchItemStatus.completed);
      expect(item.savingsPercentage.round(), 70);
    });
  });
}
