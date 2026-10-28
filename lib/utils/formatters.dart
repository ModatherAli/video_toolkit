import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// Formats byte size into human-readable string (B, KB, MB, GB).
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Formats duration (either Duration or milliseconds int) into MM:SS or HH:MM:SS.
  static String formatDuration(dynamic duration) {
    final Duration d = duration is Duration
        ? duration
        : Duration(milliseconds: (duration is num ? duration.toInt() : 0));
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Formats bitrate in bps to human-readable string (e.g. 2.4 Mbps).
  static String formatBitrate(int bitrateBps) {
    if (bitrateBps <= 0) return 'Auto';
    if (bitrateBps >= 1000000) {
      return '${(bitrateBps / 1000000).toStringAsFixed(1)} Mbps';
    }
    return '${(bitrateBps / 1000).toStringAsFixed(0)} kbps';
  }

  /// Formats date for history display.
  static String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, HH:mm').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}
