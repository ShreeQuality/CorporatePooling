import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/aadhaar_kyc_screen.dart';
import 'package:corporate_pooling_app/core/services/aadhaar_kyc_validator.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(
      home: AadhaarKycScreen(),
    );
  }

  // Generate valid 12-digit Aadhaar test vector using Verhoeff
  final testPrefix11 = '23456789012';
  final checkDigit12 = AadhaarKycValidator.generateVerhoeffCheckDigit(testPrefix11);
  final validAadhaar12 = '$testPrefix11$checkDigit12';

  // Generate valid 16-digit VID test vector using Verhoeff
  final testPrefix15 = '987654321098765';
  final checkDigit16 = AadhaarKycValidator.generateVerhoeffCheckDigit(testPrefix15);
  final validVid16 = '$testPrefix15$checkDigit16';

  group('AadhaarKycScreen - Phase 2 & 3 Tests', () {
    testWidgets('TC-6.01-UI: Screen loads with Stardust rainfall, Top Navigation Bar and Back Button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('aadhaar_back_button')), findsOneWidget);
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

      expect(find.byKey(const Key('aadhaar_trust_badge')), findsOneWidget);
      expect(find.text('UIDAI Trust Gateway // DPDP 2023'), findsOneWidget);
      expect(find.text('Verify Government Identity'), findsOneWidget);
      expect(find.byKey(const Key('aadhaar_input_card')), findsOneWidget);
    });

    testWidgets('TC-6.03 & TC-6.04: Smart auto-spacing formats 12-digit Aadhaar and 16-digit VID live', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final inputField = find.byKey(const Key('aadhaar_input_field'));

      // 1. Enter 12 digits
      await tester.enterText(inputField, '234567890123');
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('2345 6789 0123'), findsOneWidget);
      expect(find.text('🏢 12-Digit Aadhaar'), findsOneWidget);

      // 2. Continue to 16 digits (VID)
      await tester.enterText(inputField, '9876543210987654');
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('9876 5432 1098 7654'), findsOneWidget);
      expect(find.text('🔑 16-Digit VID'), findsOneWidget);
    });

    testWidgets('TC-6.06 & TC-6.07: Invalid Verhoeff Checksum displays red error banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final inputField = find.byKey(const Key('aadhaar_input_field'));

      // Enter corrupted 12-digit Aadhaar
      final invalidAadhaar = '${testPrefix11}${(checkDigit12 + 2) % 10}';
      await tester.enterText(inputField, invalidAadhaar);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('verhoeff_error_banner')), findsOneWidget);
      expect(find.textContaining('Verhoeff Checksum Failed'), findsOneWidget);
      expect(find.byKey(const Key('verhoeff_success_chip')), findsNothing);
    });

    testWidgets('TC-6.08: Valid Aadhaar displays green success chip and enables verify action', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final inputField = find.byKey(const Key('aadhaar_input_field'));
      await tester.enterText(inputField, validAadhaar12);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('verhoeff_success_chip')), findsOneWidget);
      expect(find.text('UIDAI Mathematical Checksum Verified ✓'), findsOneWidget);
      expect(find.byKey(const Key('verhoeff_error_banner')), findsNothing);
    });

    testWidgets('TC-6.09: Tapping Verify without DPDP Consent triggers error snackbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final inputField = find.byKey(const Key('aadhaar_input_field'));
      await tester.enterText(inputField, validAadhaar12);
      await tester.pump(const Duration(milliseconds: 50));

      // Tap DigiLocker button without checking DPDP consent
      final verifyBtn = find.byKey(const Key('verify_digilocker_button'));
      await tester.ensureVisible(verifyBtn);
      await tester.tap(verifyBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('You must accept the DPDP data policy to proceed.'), findsOneWidget);

      // Now toggle DPDP consent checkbox
      final consentCard = find.byKey(const Key('dpdp_consent_card'));
      await tester.ensureVisible(consentCard);
      await tester.tap(consentCard);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Tapping Read DPDP Privacy Shield Policy opens modal bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final policyLink = find.text('Read DPDP Privacy Shield Policy ➔');
      await tester.ensureVisible(policyLink);
      await tester.tap(policyLink);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DPDP Act 2023 Privacy Shield'), findsOneWidget);
      expect(find.text('Zero Plain-Text Storage'), findsOneWidget);
      expect(find.text('Understood & Protected'), findsOneWidget);

      // Close modal by tapping outside modal scrim
      await tester.tapAt(const Offset(50, 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DPDP Act 2023 Privacy Shield'), findsNothing);
    });
  });
}
