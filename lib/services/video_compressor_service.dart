import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/compression_config.dart';
import '../models/compression_progress.dart';
import '../models/video_info.dart';

class VideoCompressorService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.modatherali.video_toolkit/compressor');
  static const EventChannel _eventChannel =
      EventChannel('com.modatherali.video_toolkit/compression_events');

  Stream<CompressionProgress>? _progressStream;

  /// Stream of live compression progress and completion events from native Media3 Transformer.
  Stream<CompressionProgress> get compressionEvents {
    _progressStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          if (event is Map) {
            return CompressionProgress.fromEvent(event);
          }
          return const CompressionProgress(status: CompressionStatus.idle);
        })
        .asBroadcastStream();
    return _progressStream!;
  }

  /// Picks a video using native Android picker, falling back to system FilePicker if needed.
  Future<VideoInfo?> pickVideo() async {
    try {
      // First try native Android picker via MethodChannel
      final dynamic result = await _methodChannel.invokeMethod('pickVideo');
      if (result != null && result is Map) {
        return VideoInfo.fromMap(result);
      }
    } on PlatformException catch (e) {
      debugPrint('Native pickVideo failed or not implemented: ${e.message}, falling back to FilePicker');
    }

    // Fallback: Use FilePicker
    try {
      final pickerResult = await FilePicker.pickFiles(
        type: FileType.video,
      );

      if (pickerResult.isNotEmpty) {
        final file = pickerResult.first;
        if (file.path != null) {
          return await getVideoMetadata(file.path!);
        }
      }
    } catch (e) {
      debugPrint('FilePicker fallback error: $e');
    }

    return null;
  }

  /// Extracts video metadata from a URI or local file path via Android MediaMetadataRetriever.
  Future<VideoInfo?> getVideoMetadata(String pathOrUri) async {
    try {
      final dynamic result = await _methodChannel.invokeMethod(
        'getVideoMetadata',
        {'uri': pathOrUri},
      );
      if (result != null && result is Map) {
        return VideoInfo.fromMap(result);
      }
    } catch (e) {
      debugPrint('Error getting video metadata: $e');
    }
    return null;
  }

  /// Starts transcoding the source video using AndroidX Media3 Transformer.
  Future<bool> startCompression({
    required VideoInfo source,
    required CompressionConfig config,
    required String outputPath,
  }) async {
    try {
      final args = config.toMap(
        sourceUri: source.uri,
        outputPath: outputPath,
      );
      final bool? success = await _methodChannel.invokeMethod<bool>(
        'startCompression',
        args,
      );
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error starting compression: ${e.message}');
      rethrow;
    }
  }

  /// Cancels any currently running compression job and cleans up partial files.
  Future<bool> cancelCompression() async {
    try {
      final bool? success = await _methodChannel.invokeMethod<bool>('cancelCompression');
      return success ?? false;
    } catch (e) {
      debugPrint('Error cancelling compression: $e');
      return false;
    }
  }

  /// Saves the compressed video into the public Android Movies/OptiVideo MediaStore collection.
  Future<String?> saveToGallery({
    required String filePath,
    required String displayName,
  }) async {
    try {
      final String? uri = await _methodChannel.invokeMethod<String>(
        'saveToGallery',
        {
          'filePath': filePath,
          'displayName': displayName,
        },
      );
      return uri;
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      return null;
    }
  }

  /// Queries available free storage in bytes.
  Future<int> getAvailableStorage() async {
    try {
      final int? bytes = await _methodChannel.invokeMethod<int>('getAvailableStorage');
      return bytes ?? 0;
    } catch (e) {
      debugPrint('Error getting storage: $e');
      return 0;
    }
  }

  /// Opens the video using external player / system intent.
  Future<bool> openVideoFile(String filePath) async {
    try {
      final bool? success = await _methodChannel.invokeMethod<bool>(
        'openVideoFile',
        {'filePath': filePath},
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Error opening video file: $e');
      return false;
    }
  }

  /// Generates a unique output file path in the app's cache directory.
  Future<String> generateOutputPath(String originalFileName) async {
    final tempDir = await getTemporaryDirectory();
    final outDir = Directory('${tempDir.path}/compressed');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = originalFileName.contains('.')
        ? originalFileName.substring(0, originalFileName.lastIndexOf('.'))
        : originalFileName;
    return '${outDir.path}/${baseName}_opti_$timestamp.mp4';
  }
}
