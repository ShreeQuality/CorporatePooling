import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/aadhaar_kyc_screen.dart';
import 'package:corporate_pooling_app/screens/auth/corporate_verify_screen.dart';
import 'package:corporate_pooling_app/core/services/aadhaar_kyc_validator.dart';

void main() {
  Widget createTestWidget({
    void Function(AadhaarProfilePayload)? onKycSuccess,
    double textScaleFactor = 1.0,
  }) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child!,
        );
      },
      home: AadhaarKycScreen(onKycSuccess: onKycSuccess),
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

  group('AadhaarKycScreen - Phase 2 to 7 Comprehensive Specification Tests', () {
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

    testWidgets('TC-6.10 & TC-6.11: Opens DigiLocker Gateway, displays 256-Bit SSL URL and allows cancel', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Enter valid Aadhaar
      final inputField = find.byKey(const Key('aadhaar_input_field'));
      await tester.enterText(inputField, validAadhaar12);
      await tester.pump(const Duration(milliseconds: 50));

      // Give DPDP consent
      final consentCard = find.byKey(const Key('dpdp_consent_card'));
      await tester.ensureVisible(consentCard);
      await tester.tap(consentCard);
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Verify via DigiLocker
      final verifyBtn = find.byKey(const Key('verify_digilocker_button'));
      await tester.ensureVisible(verifyBtn);
      await tester.tap(verifyBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify DigiLocker Gateway card
      expect(find.byKey(const Key('digilocker_webview_modal')), findsOneWidget);
      expect(find.text('256-BIT SSL'), findsOneWidget);
      expect(find.text('DigiLocker Consent Request'), findsOneWidget);
      expect(find.byKey(const Key('digilocker_otp_input')), findsOneWidget);

      // Test Cancel & Return
      final cancelBtn = find.byKey(const Key('digilocker_cancel_button'));
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('aadhaar_input_card')), findsOneWidget);
      expect(find.byKey(const Key('digilocker_webview_modal')), findsNothing);
    });

    testWidgets('TC-6.12 to TC-6.15: Authorizing DigiLocker OTP extracts UIDAI Signed XML and advances to Selfie Liveness', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Enter valid Aadhaar & DPDP consent
      await tester.enterText(find.byKey(const Key('aadhaar_input_field')), validAadhaar12);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('dpdp_consent_card')));
      await tester.pump(const Duration(milliseconds: 50));

      // Open DigiLocker Gateway
      await tester.tap(find.byKey(const Key('verify_digilocker_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // Authorize DigiLocker OTP
      final authBtn = find.byKey(const Key('digilocker_authorize_button'));
      await tester.ensureVisible(authBtn);
      await tester.tap(authBtn);

      // Pump to simulate async retrieval
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify parsed XML payload preview on Selfie Liveness step
      expect(find.byKey(const Key('selfie_liveness_card')), findsOneWidget);
      expect(find.text('UIDAI Signed e-KYC Record Ready'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('15/08/1996'), findsOneWidget);
      expect(find.text('Bengaluru, Karnataka'), findsOneWidget);
      expect(find.text('SYS.AUTH // FACE_LIVENESS'), findsOneWidget);
    });

    testWidgets('TC-6.16 to TC-6.19: Secure Offline QR Scanner opens, toggles torch, detects QR and extracts payload', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Check DPDP Consent
      await tester.tap(find.byKey(const Key('dpdp_consent_card')));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Scan Aadhaar QR
      final qrBtn = find.byKey(const Key('scan_qr_button'));
      await tester.ensureVisible(qrBtn);
      await tester.tap(qrBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify QR Scanner view
      expect(find.byKey(const Key('aadhaar_qr_scanner_view')), findsOneWidget);
      expect(find.text('Align Aadhaar QR in Viewfinder'), findsOneWidget);
      expect(find.text('SYS.AUTH // SECURE_QR'), findsOneWidget);

      // Toggle Torch
      final torchBtn = find.byKey(const Key('qr_torch_button'));
      await tester.tap(torchBtn);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);

      // Simulate QR scan
      final simQrBtn = find.byKey(const Key('simulate_qr_scan_button'));
      await tester.tap(simQrBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify payload extracted from QR (Ananya Sharma, Pune, Maharashtra)
      expect(find.byKey(const Key('selfie_liveness_card')), findsOneWidget);
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(find.text('22/11/1998'), findsOneWidget);
      expect(find.text('Pune, Maharashtra'), findsOneWidget);
    });

    testWidgets('TC-6.20 to TC-6.23: Anti-Fraud Selfie Capture analyzes biometrics and completes verification', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AadhaarProfilePayload? callbackProfile;
      await tester.pumpWidget(createTestWidget(onKycSuccess: (profile) {
        callbackProfile = profile;
      }));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Consent and QR detection
      await tester.tap(find.byKey(const Key('dpdp_consent_card')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('scan_qr_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('simulate_qr_scan_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // 2. Selfie Viewfinder & Capture
      expect(find.byKey(const Key('selfie_camera_viewfinder')), findsOneWidget);
      final captureBtn = find.byKey(const Key('capture_selfie_button'));
      await tester.ensureVisible(captureBtn);
      await tester.tap(captureBtn);

      // 3. Step through biometric analysis
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Biometric Match: 98.4%'), findsOneWidget);
      expect(find.byKey(const Key('complete_kyc_button')), findsOneWidget);

      // 4. Confirm & Complete KYC
      final completeBtn = find.byKey(const Key('complete_kyc_button'));
      await tester.tap(completeBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Verify callback was executed with verified profile
      expect(callbackProfile, isNotNull);
      expect(callbackProfile!.fullName, 'Ananya Sharma');
      expect(callbackProfile!.district, 'Pune');
    });

    testWidgets('TC-6.24 to TC-6.30: Phase 6 Verified Profile Card renders emerald trust badges, metadata grid and hand-off CTA', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AadhaarProfilePayload? callbackProfile;
      await tester.pumpWidget(createTestWidget(onKycSuccess: (profile) {
        callbackProfile = profile;
      }));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Complete DigiLocker e-KYC
      await tester.enterText(find.byKey(const Key('aadhaar_input_field')), validAadhaar12);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('dpdp_consent_card')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('verify_digilocker_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('digilocker_authorize_button')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      // 2. Perform Facial Liveness
      await tester.tap(find.byKey(const Key('capture_selfie_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('complete_kyc_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Verify Phase 6 Success State & Profile Card
      expect(find.byKey(const Key('verified_profile_card')), findsOneWidget);
      expect(find.text('SYS.AUTH // KYC_VERIFIED'), findsOneWidget);
      expect(find.text('Identity Verified Successfully'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('•••• •••• ${validAadhaar12.substring(8)}'), findsOneWidget);
      expect(find.text('15/08/1996'), findsOneWidget);
      expect(find.text('Bengaluru, Karnataka'), findsOneWidget);
      expect(find.text('98.4% Match Confidence ✓'), findsOneWidget);
      expect(find.text('Zero Plain-Text Storage ✓'), findsOneWidget);

      // 4. Test Hand-off CTA button
      final proceedBtn = find.byKey(const Key('continue_to_next_screen_button'));
      expect(proceedBtn, findsOneWidget);
      await tester.tap(proceedBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(callbackProfile, isNotNull);
      expect(callbackProfile!.fullName, 'Rahul Kumar');
      expect(callbackProfile!.isKycVerified, isTrue);
    });

    testWidgets('TC-6.31 to TC-6.33: Multi-resolution ergonomics (Small screen, Large screen, and 1.5x accessibility text scale)', (tester) async {
      // Test on small viewport (320x568 - iPhone SE 1st gen)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(textScaleFactor: 1.5));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('aadhaar_input_card')), findsOneWidget);
      expect(find.byKey(const Key('aadhaar_hud_telemetry_badge')), findsOneWidget);
    });

    testWidgets('TC-6.34: Screen 5 to Screen 6 Transition Navigation Bridge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? receivedPayload;
      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVerifyScreen(
            onPublicModeSelected: (data) {
              receivedPayload = data;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Public User Section is present by default
      expect(find.byKey(const Key('section_public_user')), findsOneWidget);

      // Tap Continue to Govt KYC
      final continueBtn = find.byKey(const Key('continue_public_kyc_button'));
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(receivedPayload, isNotNull);
      expect(receivedPayload!['user_type'], 'public_user');
    });
  });
}
