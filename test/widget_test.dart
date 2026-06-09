import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_mate/main.dart';

void main() {
  testWidgets('Media Mate Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MediaMateApp(),
      ),
    );

    // Verify that branding text is found.
    expect(find.text('Media Mate'), findsWidgets);
  });
}
