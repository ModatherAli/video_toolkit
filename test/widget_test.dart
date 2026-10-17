import 'package:flutter_test/flutter_test.dart';
import 'package:video_toolkit/app.dart';
import 'package:video_toolkit/models/history_item.dart';
import 'package:video_toolkit/services/history_repository.dart';
import 'package:video_toolkit/services/video_compressor_service.dart';

void main() {
  testWidgets('OptiVideoApp renders Home screen with brand and CTA', (WidgetTester tester) async {
    final compressorService = VideoCompressorService();
    final historyRepository = HistoryRepository();

    await tester.pumpWidget(
      OptiVideoApp(
        compressorService: compressorService,
        historyRepository: historyRepository,
      ),
    );

    await tester.pumpAndSettle();

    // Verify OptiVideo title is present
    expect(find.text('OptiVideo'), findsOneWidget);

    // Verify Privacy message is present
    expect(find.text('100% Offline & Private'), findsOneWidget);

    // Verify Select Video CTA button is present
    expect(find.text('Select Video'), findsAtLeastNWidgets(1));
    expect(find.text('Shrink Video Size in Seconds'), findsOneWidget);

    // Verify Empty State is displayed initially
    expect(find.text('How It Works'), findsOneWidget);
  });

  testWidgets('HomeScreen renders recent items when history is populated', (WidgetTester tester) async {
    final compressorService = VideoCompressorService();
    final historyRepository = HistoryRepository();

    final testItem = HistoryItem(
      id: 'test_1',
      fileName: 'nature.mp4',
      originalPath: '/storage/nature.mp4',
      compressedPath: '/cache/nature_compressed.mp4',
      originalSizeBytes: 50 * 1024 * 1024,
      compressedSizeBytes: 15 * 1024 * 1024,
      durationMs: 60000,
      resolution: '1280×720',
      timestamp: DateTime.now(),
    );

    historyRepository.historyNotifier.value = [testItem];

    await tester.pumpWidget(
      OptiVideoApp(
        compressorService: compressorService,
        historyRepository: historyRepository,
      ),
    );

    await tester.pumpAndSettle();

    // Verify Recent Compressions title appears
    expect(find.text('Recent Compressions'), findsOneWidget);
    expect(find.text('nature.mp4'), findsOneWidget);
    expect(find.text('-70%'), findsOneWidget);
  });
}
