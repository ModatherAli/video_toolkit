import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'services/history_repository.dart';
import 'services/video_compressor_service.dart';
import 'theme/app_theme.dart';

class OptiVideoApp extends StatelessWidget {
  final VideoCompressorService compressorService;
  final HistoryRepository historyRepository;

  const OptiVideoApp({
    super.key,
    required this.compressorService,
    required this.historyRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OptiVideo: Offline Video Compressor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: HomeScreen(
        compressorService: compressorService,
        historyRepository: historyRepository,
      ),
    );
  }
}
