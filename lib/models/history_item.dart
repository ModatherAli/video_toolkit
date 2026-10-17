import '../utils/formatters.dart';

class HistoryItem {
  final String id;
  final String fileName;
  final String originalPath;
  final String compressedPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int durationMs;
  final String resolution;
  final String? thumbnailPath;
  final DateTime timestamp;
  final bool savedToGallery;

  const HistoryItem({
    required this.id,
    required this.fileName,
    required this.originalPath,
    required this.compressedPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.durationMs,
    required this.resolution,
    this.thumbnailPath,
    required this.timestamp,
    this.savedToGallery = false,
  });

  int get savedBytes => originalSizeBytes - compressedSizeBytes;

  double get savingsPercentage {
    if (originalSizeBytes <= 0) return 0.0;
    final diff = originalSizeBytes - compressedSizeBytes;
    return (diff / originalSizeBytes * 100).clamp(-100.0, 100.0);
  }

  bool get isSmaller => compressedSizeBytes < originalSizeBytes;

  String get formattedOriginalSize => Formatters.formatBytes(originalSizeBytes);

  String get formattedCompressedSize => Formatters.formatBytes(compressedSizeBytes);

  String get formattedSavedBytes => Formatters.formatBytes(savedBytes.abs());

  String get formattedDate => Formatters.formatDate(timestamp);

  String get formattedDuration => Formatters.formatDuration(Duration(milliseconds: durationMs));

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'originalPath': originalPath,
      'compressedPath': compressedPath,
      'originalSizeBytes': originalSizeBytes,
      'compressedSizeBytes': compressedSizeBytes,
      'durationMs': durationMs,
      'resolution': resolution,
      'thumbnailPath': thumbnailPath,
      'timestamp': timestamp.toIso8601String(),
      'savedToGallery': savedToGallery,
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? 'video.mp4',
      originalPath: json['originalPath'] as String? ?? '',
      compressedPath: json['compressedPath'] as String? ?? '',
      originalSizeBytes: (json['originalSizeBytes'] as num?)?.toInt() ?? 0,
      compressedSizeBytes: (json['compressedSizeBytes'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      resolution: json['resolution'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      savedToGallery: json['savedToGallery'] as bool? ?? false,
    );
  }

  HistoryItem copyWith({
    String? id,
    String? fileName,
    String? originalPath,
    String? compressedPath,
    int? originalSizeBytes,
    int? compressedSizeBytes,
    int? durationMs,
    String? resolution,
    String? thumbnailPath,
    DateTime? timestamp,
    bool? savedToGallery,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      originalPath: originalPath ?? this.originalPath,
      compressedPath: compressedPath ?? this.compressedPath,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      compressedSizeBytes: compressedSizeBytes ?? this.compressedSizeBytes,
      durationMs: durationMs ?? this.durationMs,
      resolution: resolution ?? this.resolution,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      timestamp: timestamp ?? this.timestamp,
      savedToGallery: savedToGallery ?? this.savedToGallery,
    );
  }
}
