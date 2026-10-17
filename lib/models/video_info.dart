import '../utils/formatters.dart';
import '../utils/video_calculator.dart';

class VideoInfo {
  final String uri;
  final String fileName;
  final int fileSize; // bytes
  final Duration duration;
  final int width;
  final int height;
  final int rotation;
  final int bitrate; // bps
  final String mimeType;
  final String? thumbnailPath;

  const VideoInfo({
    required this.uri,
    required this.fileName,
    required this.fileSize,
    required this.duration,
    required this.width,
    required this.height,
    required this.rotation,
    required this.bitrate,
    required this.mimeType,
    this.thumbnailPath,
  });

  factory VideoInfo.fromMap(Map<dynamic, dynamic> map) {
    return VideoInfo(
      uri: map['uri'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'video.mp4',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      rotation: (map['rotation'] as num?)?.toInt() ?? 0,
      bitrate: (map['bitrate'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String? ?? 'video/mp4',
      thumbnailPath: map['thumbnailPath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uri': uri,
      'fileName': fileName,
      'fileSize': fileSize,
      'durationMs': duration.inMilliseconds,
      'width': width,
      'height': height,
      'rotation': rotation,
      'bitrate': bitrate,
      'mimeType': mimeType,
      'thumbnailPath': thumbnailPath,
    };
  }

  bool get isPortrait => height > width;

  double get aspectRatio {
    if (width <= 0 || height <= 0) return 16 / 9;
    return width / height;
  }

  String get formattedDuration => Formatters.formatDuration(duration);

  String get formattedFileSize => Formatters.formatBytes(fileSize);

  String get formattedBitrate => Formatters.formatBitrate(bitrate);

  String get resolutionLabel => VideoCalculator.getResolutionLabel(width, height);

  String get formatExtension {
    if (fileName.contains('.')) {
      return fileName.split('.').last.toUpperCase();
    }
    return 'MP4';
  }

  VideoInfo copyWith({
    String? uri,
    String? fileName,
    int? fileSize,
    Duration? duration,
    int? width,
    int? height,
    int? rotation,
    int? bitrate,
    String? mimeType,
    String? thumbnailPath,
  }) {
    return VideoInfo(
      uri: uri ?? this.uri,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      bitrate: bitrate ?? this.bitrate,
      mimeType: mimeType ?? this.mimeType,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
