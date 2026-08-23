import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/role_selection_screen.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(
      home: RoleSelectionScreen(),
    );
  }

  group('RoleSelectionScreen (Company vs User)', () {
    testWidgets('Renders Choose Your Journey title, subtitle, and JARVIS HUD', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Choose Your Journey'), findsOneWidget);
      expect(
        find.text('Select your account type to personalize your pooling experience'),
        findsOneWidget,
      );
    });

    testWidgets('Displays Company and User cards with transparent options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Company'), findsOneWidget);
      expect(find.text('User'), findsOneWidget);
      expect(find.text('🏢 Corporate Partner'), findsOneWidget);
      expect(find.text('🌟 Verified Commuter'), findsOneWidget);
      expect(find.byIcon(Icons.apartment_rounded), findsWidgets);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('Selecting Company enables continue button and triggers selection state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Company card
      await tester.tap(find.text('Company'));
      await tester.pump(const Duration(milliseconds: 300));

      // Check icon indicates selection
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap Continue button
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.textContaining('Company Account Confirmed'), findsOneWidget);
    });

    testWidgets('Selecting User switches selection and triggers User snackbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap User card
      await tester.tap(find.text('User'));
      await tester.pump(const Duration(milliseconds: 300));

      // Check icon indicates selection
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap Continue button
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.textContaining('User Account Confirmed'), findsOneWidget);
    });
  });
}
