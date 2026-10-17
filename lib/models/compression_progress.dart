enum CompressionStatus {
  idle,
  preparing,
  compressing,
  completed,
  cancelled,
  error;

  bool get isInProgress => this == preparing || this == compressing;
  bool get isDone => this == completed;
  bool get isFailed => this == error;
  bool get isCancelled => this == cancelled;
}

class CompressionProgress {
  final CompressionStatus status;
  final int progress; // 0 to 100
  final String? message;
  final String? outputPath;
  final int? outputSize;

  const CompressionProgress({
    required this.status,
    this.progress = 0,
    this.message,
    this.outputPath,
    this.outputSize,
  });

  factory CompressionProgress.initial() {
    return const CompressionProgress(status: CompressionStatus.idle, progress: 0);
  }

  factory CompressionProgress.fromEvent(Map<dynamic, dynamic> event) {
    final statusStr = event['status'] as String? ?? '';
    switch (statusStr) {
      case 'progress':
        final prog = (event['progress'] as num?)?.toInt() ?? 0;
        return CompressionProgress(
          status: CompressionStatus.compressing,
          progress: prog.clamp(0, 100),
          message: 'Compressing video...',
        );
      case 'completed':
        return CompressionProgress(
          status: CompressionStatus.completed,
          progress: 100,
          outputPath: event['outputPath'] as String?,
          outputSize: (event['fileSize'] as num?)?.toInt(),
          message: 'Compression finished successfully',
        );
      case 'cancelled':
        return const CompressionProgress(
          status: CompressionStatus.cancelled,
          progress: 0,
          message: 'Compression cancelled',
        );
      case 'error':
        return CompressionProgress(
          status: CompressionStatus.error,
          progress: 0,
          message: event['message'] as String? ?? 'An error occurred during compression',
        );
      default:
        return CompressionProgress(
          status: CompressionStatus.idle,
          progress: 0,
          message: statusStr,
        );
    }
  }

  CompressionProgress copyWith({
    CompressionStatus? status,
    int? progress,
    String? message,
    String? outputPath,
    int? outputSize,
  }) {
    return CompressionProgress(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      outputPath: outputPath ?? this.outputPath,
      outputSize: outputSize ?? this.outputSize,
    );
  }
}
