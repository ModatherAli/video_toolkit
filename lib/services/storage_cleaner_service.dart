import 'package:flutter/foundation.dart';
import '../models/storage_cleaner_item.dart';
import '../models/video_info.dart';
import 'video_compressor_service.dart';

class StorageCleanerService {
  final VideoCompressorService compressorService;

  final ValueNotifier<List<StorageCleanerItem>> itemsNotifier =
      ValueNotifier<List<StorageCleanerItem>>([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  StorageCleanerService({
    required this.compressorService,
  });

  List<StorageCleanerItem> get items => itemsNotifier.value;

  List<StorageCleanerItem> get selectedItems =>
      items.where((it) => it.isSelected).toList();

  int get totalOccupiedBytes =>
      items.fold(0, (sum, it) => sum + it.sizeBytes);

  int get totalSelectedBytes =>
      selectedItems.fold(0, (sum, it) => sum + it.sizeBytes);

  /// Estimates ~70% space reclaimable by compressing selected high-bitrate media.
  int get estimatedReclaimableBytes => (totalSelectedBytes * 0.70).round();

  Future<void> scanLargestMedia({int limit = 40}) async {
    isLoadingNotifier.value = true;
    try {
      final rawList = await compressorService.queryLargestMediaFiles(limit: limit);
      final list = rawList.map((m) => StorageCleanerItem.fromMap(m)).toList();
      itemsNotifier.value = list;
    } catch (e) {
      debugPrint('Error scanning largest media: $e');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  void toggleItem(String id) {
    final list = List<StorageCleanerItem>.from(items);
    final idx = list.indexWhere((it) => it.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isSelected: !list[idx].isSelected);
      itemsNotifier.value = list;
    }
  }

  void selectAll(bool select) {
    final list = items.map((it) => it.copyWith(isSelected: select)).toList();
    itemsNotifier.value = list;
  }

  /// Converts selected items into VideoInfo models ready for batch compression.
  List<VideoInfo> toVideoInfoList() {
    return selectedItems.map((item) {
      return VideoInfo(
        uri: item.uri,
        fileName: item.name,
        fileSize: item.sizeBytes,
        duration: Duration(milliseconds: item.durationMs),
        width: 1920, // default if not yet probed
        height: 1080,
        rotation: 0,
        bitrate: 0,
        mimeType: 'video/mp4',
      );
    }).toList();
  }

  /// Trashes selected original files using Android 11+ System Trash (30-day recovery).
  Future<bool> trashSelectedOriginals() async {
    final selected = selectedItems;
    if (selected.isEmpty) return true;

    final uris = selected.map((s) => s.uri).toList();
    final success = await compressorService.requestTrashOriginals(uris);

    if (success) {
      // Remove trashed items from the list
      final remaining = items.where((it) => !it.isSelected).toList();
      itemsNotifier.value = remaining;
    }
    return success;
  }

  void dispose() {
    itemsNotifier.dispose();
    isLoadingNotifier.dispose();
  }
}
