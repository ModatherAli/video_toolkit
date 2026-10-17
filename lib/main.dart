import 'package:flutter/material.dart';
import 'app.dart';
import 'services/history_repository.dart';
import 'services/video_compressor_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final compressorService = VideoCompressorService();
  final historyRepository = HistoryRepository();
  await historyRepository.init();

  runApp(
    OptiVideoApp(
      compressorService: compressorService,
      historyRepository: historyRepository,
    ),
  );
}
