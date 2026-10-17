import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_toolkit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and displays Home screen elements', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('OptiVideo'), findsOneWidget);
    expect(find.text('100% Offline & Private'), findsOneWidget);
    expect(find.text('Compress Any Video'), findsOneWidget);
    expect(find.text('Select Video'), findsOneWidget);
  });
}
