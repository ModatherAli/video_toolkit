import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/history_item.dart';

class HistoryRepository {
  final ValueNotifier<List<HistoryItem>> historyNotifier = ValueNotifier<List<HistoryItem>>([]);
  File? _storageFile;

  Future<File> _getStorageFile() async {
    if (_storageFile != null) return _storageFile!;
    final dir = await getApplicationDocumentsDirectory();
    _storageFile = File('${dir.path}/optivideo_history.json');
    return _storageFile!;
  }

  Future<void> init() async {
    await loadHistory();
  }

  /// Loads history from local persistent JSON file.
  Future<List<HistoryItem>> loadHistory() async {
    try {
      final file = await _getStorageFile();
      if (!file.existsSync()) {
        historyNotifier.value = [];
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        historyNotifier.value = [];
        return [];
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is List) {
        final items = decoded.map((dynamic item) {
          return HistoryItem.fromJson(item as Map<String, dynamic>);
        }).toList();

        // Sort newest first
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        historyNotifier.value = items;
        return items;
      }
      historyNotifier.value = [];
      return [];
    } catch (e) {
      debugPrint('Error loading history: $e');
      historyNotifier.value = [];
      return [];
    }
  }

  /// Adds a new compression record to history.
  Future<void> addHistoryItem(HistoryItem item) async {
    try {
      final file = await _getStorageFile();
      final current = List<HistoryItem>.from(historyNotifier.value);
      current.insert(0, item);

      final jsonString = jsonEncode(current.map((i) => i.toJson()).toList());
      await file.writeAsString(jsonString, flush: true);
      historyNotifier.value = current;
    } catch (e) {
      debugPrint('Error adding history item: $e');
    }
  }

  /// Updates an existing history item (e.g. when saved to gallery).
  Future<void> updateHistoryItem(HistoryItem item) async {
    try {
      final file = await _getStorageFile();
      final current = List<HistoryItem>.from(historyNotifier.value);
      final index = current.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        current[index] = item;
        final jsonString = jsonEncode(current.map((i) => i.toJson()).toList());
        await file.writeAsString(jsonString, flush: true);
        historyNotifier.value = current;
      }
    } catch (e) {
      debugPrint('Error updating history item: $e');
    }
  }

  /// Removes an entry from history, optionally deleting the video file from disk.
  Future<void> deleteHistoryItem(String id, {bool deleteFileFromDisk = false}) async {
    try {
      final file = await _getStorageFile();
      final current = List<HistoryItem>.from(historyNotifier.value);
      final itemIndex = current.indexWhere((i) => i.id == id);

      if (itemIndex != -1) {
        final item = current[itemIndex];
        if (deleteFileFromDisk) {
          try {
            final videoFile = File(item.compressedPath);
            if (videoFile.existsSync()) {
              videoFile.deleteSync();
            }
          } catch (e) {
            debugPrint('Could not delete file from disk: $e');
          }
        }

        current.removeAt(itemIndex);
        final jsonString = jsonEncode(current.map((i) => i.toJson()).toList());
        await file.writeAsString(jsonString, flush: true);
        historyNotifier.value = current;
      }
    } catch (e) {
      debugPrint('Error deleting history item: $e');
    }
  }

  /// Clears the entire compression history.
  Future<void> clearAll({bool deleteFilesFromDisk = false}) async {
    try {
      final file = await _getStorageFile();
      if (deleteFilesFromDisk) {
        for (final item in historyNotifier.value) {
          try {
            final videoFile = File(item.compressedPath);
            if (videoFile.existsSync()) {
              videoFile.deleteSync();
            }
          } catch (_) {}
        }
      }
      if (file.existsSync()) {
        await file.delete();
      }
      historyNotifier.value = [];
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  /// Checks if the physical file for this item still exists on disk.
  bool fileExists(HistoryItem item) {
    if (item.compressedPath.isEmpty) return false;
    return File(item.compressedPath).existsSync();
  }
}
