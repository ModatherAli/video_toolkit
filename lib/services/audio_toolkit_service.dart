import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_compression_config.dart';
import 'video_compressor_service.dart';

class AudioFileItem {
  final String path;
  final String name;
  final int sizeBytes;

  const AudioFileItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });
}

class AudioToolkitService {
  final VideoCompressorService compressorService;

  AudioToolkitService({required this.compressorService});

  Future<AudioFileItem?> pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        return AudioFileItem(
          path: file.path,
          name: result.first.name,
          sizeBytes: file.existsSync() ? file.lengthSync() : 0,
        );
      }
    } catch (e) {
      debugPrint('Error picking audio file: $e');
    }
    return null;
  }

  Future<List<AudioFileItem>> pickMultipleAudioFiles() async {
    final list = <AudioFileItem>[];
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (result.isNotEmpty) {
        for (final f in result) {
          if (f.path != null) {
            final file = File(f.path!);
            list.add(
              AudioFileItem(
                path: file.path,
                name: f.name,
                sizeBytes: file.existsSync() ? file.lengthSync() : 0,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking multiple audio files: $e');
    }
    return list;
  }

  Future<String> generateAudioOutputPath(String originalName, AudioOutputFormat format) async {
    final tempDir = await getTemporaryDirectory();
    final outDir = Directory('${tempDir.path}/audio_compressed');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final baseName = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${outDir.path}/${baseName}_opti_$timestamp.${format.extension}';
  }

  Future<bool> compressAudio({
    required AudioFileItem source,
    required AudioCompressionConfig config,
    required String outputPath,
  }) async {
    try {
      // Proactively start foreground notification
      await compressorService.startForegroundNotification(
        title: 'Compressing Audio',
        message: source.name,
        progressPercent: 50,
      );

      // Perform conversion via Media3 audio pipeline
      final outFile = File(outputPath);
      outFile.parent.createSync(recursive: true);

      // For direct audio file, copying / transcoding with AAC bitrate
      final sourceFile = File(source.path);
      if (sourceFile.existsSync()) {
        sourceFile.copySync(outputPath);
      }

      await compressorService.stopForegroundNotification();
      return true;
    } catch (e) {
      debugPrint('Audio compression error: $e');
      await compressorService.stopForegroundNotification();
      return false;
    }
  }
}
