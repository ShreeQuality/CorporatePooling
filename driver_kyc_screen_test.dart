import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/driver_kyc_screen.dart';
import 'package:corporate_pooling_app/screens/auth/aadhaar_kyc_screen.dart';
import 'package:corporate_pooling_app/core/services/aadhaar_kyc_validator.dart';

void main() {
  const mockAadhaarProfile = AadhaarProfilePayload(
    fullName: 'Rahul Kumar',
    maskedAadhaar: '•••• •••• 9012',
    dob: '15/08/1992',
    gender: 'Male',
    district: 'Bengaluru Urban',
    state: 'Karnataka',
    pincode: '560100',
    photoUrl: 'https://uidai.gov.in/photos/mock_rahul.jpg',
    isKycVerified: true,
  );

  final testPrefix11 = '98765432109';
  final checkDigit12 = AadhaarKycValidator.generateVerhoeffCheckDigit(testPrefix11);
  final validAadhaar12 = '$testPrefix11$checkDigit12';

  Widget createDriverKycScreen({AadhaarProfilePayload? profile}) {
    return MaterialApp(
      home: DriverKycScreen(
        verifiedAadhaarProfile: profile ?? mockAadhaarProfile,
        previousPayload: const {
          'user_type': 'corporate_employee',
          'company_name': 'Infosys Technologies',
        },
      ),
    );
  }

  group('DriverKycScreen - Phase 2 Specification & Scaffold Tests', () {
    testWidgets('TC-7.01: Screen 7 initializes with Golden Base Design System, J.A.R.V.I.S. HUD and Stepper', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify J.A.R.V.I.S. HUD Header
      expect(find.byKey(const Key('driver_kyc_holo_hud')), findsOneWidget);
      expect(find.text('SYS.AUTH // DRIVER_KYC'), findsOneWidget);
      expect(find.text('Driver & Vehicle Verification'), findsOneWidget);

      // 2. Verify Verified Citizen Banner
      expect(find.textContaining('Rahul Kumar'), findsOneWidget);

      // 3. Verify Step Indicator renders all 3 steps
      expect(find.text('License'), findsOneWidget);
      expect(find.text('Vehicle RC'), findsOneWidget);
      expect(find.text('Activation'), findsOneWidget);

      // 4. Verify Top Nav & Trust Pill
      expect(find.byKey(const Key('driver_kyc_back_button')), findsOneWidget);
      expect(find.text('SARATHI & VAHAN VERIFIED'), findsOneWidget);
    });

    testWidgets('TC-7.02: Back button taps open Cancel Confirmation Dialog and handles dismissal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Back button
      await tester.tap(find.byKey(const Key('driver_kyc_back_button')));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Dialog opens with warning
      expect(find.text('Cancel Driver KYC?'), findsOneWidget);
      expect(find.textContaining('without Driver License & Vehicle verification'), findsOneWidget);
      expect(find.text('Continue KYC'), findsOneWidget);
      expect(find.text('Exit for Now'), findsOneWidget);

      // Tap Continue KYC to dismiss dialog and stay on screen
      await tester.tap(find.text('Continue KYC'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cancel Driver KYC?'), findsNothing);
      expect(find.text('Driver & Vehicle Verification'), findsOneWidget);
    });

    testWidgets('TC-6.34 to TC-7.01: Screen 6 to Screen 7 Navigation Bridge Hand-off', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AadhaarKycScreen(
            previousPayload: const {
              'user_type': 'corporate_employee',
              'company_name': 'Infosys Technologies',
            },
          ),
        ),
      );
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

      // 3. Verify Verified Profile Card renders on Screen 6
      expect(find.byKey(const Key('verified_profile_card')), findsOneWidget);
      final continueBtn = find.byKey(const Key('continue_to_next_screen_button'));
      expect(continueBtn, findsOneWidget);

      // 4. Tap Continue to proceed to Screen 7 (Driver KYC)
      await tester.tap(continueBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // 5. Verify Screen 7 Driver KYC slides in
      expect(find.byKey(const Key('driver_kyc_holo_hud')), findsOneWidget);
      expect(find.text('Driver & Vehicle Verification'), findsOneWidget);
    });
  });
}
