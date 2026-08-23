import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/aadhaar_kyc_screen.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(
      home: AadhaarKycScreen(),
    );
  }

  group('AadhaarKycScreen - Phase 2 Scaffold & Header Tests', () {
    testWidgets('TC-6.01-UI: Screen loads with Stardust rainfall, Top Navigation Bar and Back Button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Back Button
      expect(find.byKey(const Key('aadhaar_back_button')), findsOneWidget);

      // HUD Telemetry Badge
      expect(find.byKey(const Key('aadhaar_hud_telemetry_badge')), findsOneWidget);
      expect(find.text('SYS.AUTH // GOVT_KYC'), findsOneWidget);
    });

    testWidgets('TC-6.02-UI: Renders Holographic Header, UIDAI Trust Shield badge, Title and Subtitle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Trust Badge
      expect(find.byKey(const Key('aadhaar_trust_badge')), findsOneWidget);
      expect(find.text('UIDAI Trust Gateway // DPDP 2023'), findsOneWidget);

      // Title & Subtitle
      expect(find.text('Verify Government Identity'), findsOneWidget);
      expect(
        find.text('Mandatory KYC under DPDP Act 2023 for 100% verified & safe commuter carpools.'),
        findsOneWidget,
      );

      // Main content card
      expect(find.byKey(const Key('aadhaar_main_content_card')), findsOneWidget);
    });
  });
}
