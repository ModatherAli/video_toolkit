import '../utils/formatters.dart';

class StorageCleanerItem {
  final String id;
  final String name;
  final String uri;
  final String? path;
  final int sizeBytes;
  final int durationMs;
  final int dateModified;
  final bool isSelected;

  const StorageCleanerItem({
    required this.id,
    required this.name,
    required this.uri,
    this.path,
    required this.sizeBytes,
    required this.durationMs,
    required this.dateModified,
    this.isSelected = true, // Selected by default for quick cleanup
  });

  factory StorageCleanerItem.fromMap(Map<String, dynamic> map) {
    final rawSize = map['size'] ?? map['sizeBytes'];
    return StorageCleanerItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Media',
      uri: map['uri']?.toString() ?? '',
      path: map['path']?.toString(),
      sizeBytes: (rawSize is num) ? rawSize.toInt() : 0,
      durationMs: (map['durationMs'] is num) ? (map['durationMs'] as num).toInt() : 0,
      dateModified: (map['dateModified'] is num) ? (map['dateModified'] as num).toInt() : 0,
      isSelected: true,
    );
  }

  String get formattedSize => Formatters.formatBytes(sizeBytes);
  String get formattedDuration => Formatters.formatDuration(durationMs);

  StorageCleanerItem copyWith({
    bool? isSelected,
  }) {
    return StorageCleanerItem(
      id: id,
      name: name,
      uri: uri,
      path: path,
      sizeBytes: sizeBytes,
      durationMs: durationMs,
      dateModified: dateModified,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
