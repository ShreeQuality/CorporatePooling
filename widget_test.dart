import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/main.dart';

void main() {
  testWidgets('App smoke test initializes KarmaRideApp', (WidgetTester tester) async {
    await tester.pumpWidget(const KarmaRideApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(KarmaRideApp), findsOneWidget);
  });
}
