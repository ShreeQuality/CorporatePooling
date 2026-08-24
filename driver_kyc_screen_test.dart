import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/driver_kyc_screen.dart';
import 'package:corporate_pooling_app/screens/auth/aadhaar_kyc_screen.dart';
import 'package:corporate_pooling_app/core/services/aadhaar_kyc_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockAadhaar = AadhaarProfilePayload(
    maskedAadhaar: '•••• •••• 9012',
    fullName: 'Rahul Kumar',
    dob: '15/08/1995',
    gender: 'MALE',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    pincode: '560038',
    photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    isKycVerified: true,
  );

  Widget createDriverKycScreen({
    AadhaarProfilePayload? aadhaarProfile,
    Function(Map<String, dynamic>)? onSuccess,
  }) {
    return MaterialApp(
      home: DriverKycScreen(
        verifiedAadhaarProfile: aadhaarProfile ?? mockAadhaar,
        onDriverKycSuccess: onSuccess,
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

      // Verify Screen Title & HUD
      expect(find.text('Driver & Vehicle Verification'), findsOneWidget);
      expect(find.text('SYS.AUTH // DRIVER_KYC'), findsOneWidget);
      expect(find.byKey(const Key('driver_kyc_holo_hud')), findsOneWidget);

      // Verify Verified Citizen Banner
      expect(find.textContaining('Verified Citizen: Rahul Kumar'), findsOneWidget);
      expect(find.textContaining('UID: •••• •••• 9012'), findsOneWidget);

      // Verify 3-Step Stepper
      expect(find.text('License'), findsOneWidget);
      expect(find.text('Vehicle RC'), findsOneWidget);
      expect(find.text('Activation'), findsOneWidget);

      // Verify Step 1 DL is active initially
      expect(find.text('Step 1: Driving License (DL)'), findsOneWidget);
      expect(find.byKey(const Key('dl_input_field')), findsOneWidget);
    });

    testWidgets('TC-7.02: Back button taps open Cancel Confirmation Dialog and handles dismissal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap top back button
      await tester.tap(find.byKey(const Key('driver_kyc_back_button')));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Dialog renders
      expect(find.text('Cancel Driver KYC?'), findsOneWidget);
      expect(find.text('Continue KYC'), findsOneWidget);
      expect(find.text('Exit for Now'), findsOneWidget);

      // Tap Continue KYC -> Dialog dismissed
      await tester.tap(find.text('Continue KYC'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Cancel Driver KYC?'), findsNothing);
      expect(find.text('Driver & Vehicle Verification'), findsOneWidget);
    });

    testWidgets('TC-6.34 to TC-7.01: Screen 6 to Screen 7 Navigation Bridge Hand-off', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testPrefix11 = '23456789012';
      final checkDigit12 = AadhaarKycValidator.generateVerhoeffCheckDigit(testPrefix11);
      final validAadhaar12 = '$testPrefix11$checkDigit12';

      await tester.pumpWidget(
        MaterialApp(
          home: AadhaarKycScreen(
            previousPayload: {
              'phone': '9876543210',
              'workEmail': 'rahul.kumar@infosys.com',
              'companyName': 'Infosys Limited',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // In Screen 6: 1. Complete DigiLocker e-KYC
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

      // 3. Tap Continue to Driver KYC
      final proceedBtn = find.byKey(const Key('continue_to_next_screen_button'));
      expect(proceedBtn, findsOneWidget);
      await tester.ensureVisible(proceedBtn);
      await tester.tap(proceedBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify Screen 7 is displayed
      expect(find.text('Driver & Vehicle Verification'), findsOneWidget);
      expect(find.text('SYS.AUTH // DRIVER_KYC'), findsOneWidget);
      expect(find.text('SARATHI & VAHAN VERIFIED'), findsOneWidget);
    });
  });

  group('DriverKycScreen - Phase 3 (Step 1: Driving License / Sarathi) Tests', () {
    testWidgets('TC-7.03: Auto-capitalizes and spaces DL input in real-time', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      final dlField = find.byKey(const Key('dl_input_field'));
      expect(dlField, findsOneWidget);

      // Enter lowercase unspaced DL
      await tester.enterText(dlField, 'mh1220100012345');
      await tester.pump(const Duration(milliseconds: 50));

      // Verify auto-formatting in controller
      expect(tester.widget<TextField>(dlField).controller?.text, 'MH12 20100012345');
      expect(find.text('Valid Indian DL Format (Sarathi Ready)'), findsOneWidget);
    });

    testWidgets('TC-7.04: DL Name Mismatch against Aadhaar triggers error banner & shake', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Enter DL belonging to Amit Shah (Aadhaar is Rahul Kumar)
      await tester.enterText(find.byKey(const Key('dl_input_field')), 'ka0520150007777');
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Verify via Sarathi Portal
      await tester.tap(find.byKey(const Key('verify_sarathi_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify Name Mismatch Error Banner
      expect(find.byKey(const Key('dl_error_banner')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('dl_error_banner')), matching: find.textContaining('Name Mismatch')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('dl_error_banner')), matching: find.textContaining('Amit Shah')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('dl_error_banner')), matching: find.textContaining('Rahul Kumar')), findsOneWidget);
    });

    testWidgets('TC-7.05: Expired DL triggers error banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Enter Expired DL (2001 vector)
      await tester.enterText(find.byKey(const Key('dl_input_field')), 'mh1420010000001');
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Verify
      await tester.tap(find.byKey(const Key('verify_sarathi_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify Expired Error Banner
      expect(find.byKey(const Key('dl_error_banner')), findsOneWidget);
      expect(find.textContaining('Driving License expired'), findsOneWidget);
    });

    testWidgets('TC-7.03-Success: Valid DL verifies, renders Verified DL Card, and advances to Step 2', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Enter Valid DL for Rahul Kumar
      await tester.enterText(find.byKey(const Key('dl_input_field')), 'mh1220100012345');
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Verify via Sarathi Portal
      await tester.tap(find.byKey(const Key('verify_sarathi_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify Verified DL Card
      expect(find.byKey(const Key('verified_dl_card')), findsOneWidget);
      expect(find.text('Driving License Authenticated'), findsOneWidget);
      expect(find.text('MH12 20100012345'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.byKey(const Key('proceed_to_step_2_button')), findsOneWidget);

      // Tap Proceed to Step 2
      await tester.tap(find.byKey(const Key('proceed_to_step_2_button')));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Step 2 renders
      expect(find.text('Step 2: Vehicle RC Verification'), findsOneWidget);
    });
  });

  group('DriverKycScreen - Phase 4 (Step 2: Vehicle RC / Vahan Gateway) Tests', () {
    testWidgets('TC-7.06: Auto-capitalizes and formats Vehicle RC plate input in real-time', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Verify DL first
      await tester.enterText(find.byKey(const Key('dl_input_field')), 'mh1220100012345');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('verify_sarathi_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Proceed to Step 2
      await tester.tap(find.byKey(const Key('proceed_to_step_2_button')));
      await tester.pump(const Duration(milliseconds: 300));

      final rcField = find.byKey(const Key('rc_input_field'));
      expect(rcField, findsOneWidget);

      // Enter lowercase unspaced plate
      await tester.enterText(rcField, 'ka01ab1234');
      await tester.pump(const Duration(milliseconds: 50));

      // Verify auto-formatting in controller
      expect(tester.widget<TextField>(rcField).controller?.text, 'KA 01 AB 1234');
      expect(find.text('Valid Indian Plate (Vahan Gateway Ready)'), findsOneWidget);
    });

    testWidgets('TC-7.08: Commercial yellow-board taxi vehicle triggers error banner & blocks progression', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Verify DL
      await tester.enterText(find.byKey(const Key('dl_input_field')), 'mh1220100012345');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('verify_sarathi_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Proceed to Step 2
      await tester.tap(find.byKey(const Key('proceed_to_step_2_button')));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter Commercial Yellow Board Taxi RC
      await tester.enterText(find.byKey(const Key('rc_input_field')), 'mh01tc0001');
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Fetch Vehicle
      await tester.tap(find.byKey(const Key('verify_vahan_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify Commercial Prohibition Error Banner
      expect(find.byKey(const Key('rc_error_banner')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('rc_error_banner')), matching: find.textContaining('Commercial Taxi Prohibited')), findsOneWidget);
    });

    testWidgets('TC-7.07: Valid RC fetches from Vahan, renders Verified RC Card, displays specs, and advances to Step 3', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDriverKycScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Verify DL
      await tester.enterText(find.byKey(const Key('dl_input_field')), 'mh1220100012345');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('verify_sarathi_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Proceed to Step 2
      await tester.tap(find.byKey(const Key('proceed_to_step_2_button')));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter Valid RC (Hyundai Creta)
      await tester.enterText(find.byKey(const Key('rc_input_field')), 'ka01ab1234');
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Fetch Vehicle from Vahan
      await tester.tap(find.byKey(const Key('verify_vahan_button')));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify 3D Verified RC Card
      expect(find.byKey(const Key('verified_rc_card')), findsOneWidget);
      expect(find.text('Vehicle Authenticated (Vahan 4.0)'), findsOneWidget);
      expect(find.text('Hyundai Creta SX (O) • Polar White'), findsOneWidget);
      expect(find.text('KA 01 AB 1234'), findsOneWidget);
      expect(find.text('⛽ Petrol'), findsOneWidget);
      expect(find.text('👥 5 Seater (4 Pool Seats)'), findsOneWidget);
      expect(find.text('Registered Owner: Rahul Kumar'), findsOneWidget);

      // Verify Step 3 Action Button
      final step3Btn = find.byKey(const Key('proceed_to_step_3_button'));
      expect(step3Btn, findsOneWidget);

      // Tap Proceed to Step 3
      await tester.tap(step3Btn);
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Step 3 placeholder rendered
      expect(find.text('Step 3: Vehicle Photo & Captain Activation'), findsOneWidget);
    });
  });
}
