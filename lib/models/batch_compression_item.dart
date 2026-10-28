import 'compression_config.dart';
import 'video_info.dart';

enum BatchItemStatus {
  pending,
  compressing,
  completed,
  failed,
  skipped,
  cancelled;

  String get label {
    switch (this) {
      case BatchItemStatus.pending:
        return 'Queued';
      case BatchItemStatus.compressing:
        return 'Compressing...';
      case BatchItemStatus.completed:
        return 'Completed';
      case BatchItemStatus.failed:
        return 'Failed';
      case BatchItemStatus.skipped:
        return 'Skipped (Already Small)';
      case BatchItemStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isFinished =>
      this == BatchItemStatus.completed ||
      this == BatchItemStatus.failed ||
      this == BatchItemStatus.skipped ||
      this == BatchItemStatus.cancelled;
}

class BatchCompressionItem {
  final String id;
  final VideoInfo source;
  final CompressionConfig config;
  final BatchItemStatus status;
  final double progress; // 0.0 to 1.0
  final String? outputPath;
  final int? compressedSizeBytes;
  final String? errorMessage;

  const BatchCompressionItem({
    required this.id,
    required this.source,
    required this.config,
    this.status = BatchItemStatus.pending,
    this.progress = 0.0,
    this.outputPath,
    this.compressedSizeBytes,
    this.errorMessage,
  });

  int get originalSizeBytes => source.fileSizeBytes;

  int get savedBytes {
    if (compressedSizeBytes != null && compressedSizeBytes! < originalSizeBytes) {
      return originalSizeBytes - compressedSizeBytes!;
    }
    return 0;
  }

  double get savingsPercentage {
    if (originalSizeBytes <= 0 || compressedSizeBytes == null) return 0.0;
    final diff = originalSizeBytes - compressedSizeBytes!;
    return (diff / originalSizeBytes * 100).clamp(0.0, 100.0);
  }

  BatchCompressionItem copyWith({
    BatchItemStatus? status,
    double? progress,
    String? outputPath,
    int? compressedSizeBytes,
    String? errorMessage,
    CompressionConfig? config,
  }) {
    return BatchCompressionItem(
      id: id,
      source: source,
      config: config ?? this.config,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      compressedSizeBytes: compressedSizeBytes ?? this.compressedSizeBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
