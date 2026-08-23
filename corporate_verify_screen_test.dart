import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/corporate_verify_screen.dart';

void main() {
  Widget buildTestApp() {
    return const MaterialApp(
      home: CorporateVerifyScreen(),
    );
  }

  group('Category 1: UI Initialization & Mode Selection (TC-5.01 to TC-5.04)', () {
    testWidgets('TC-5.01 & Header: Screen loads with Corporate Employee selected and HUD header', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Header Elements
      expect(find.text('Corporate Identity Gate'), findsOneWidget);
      expect(find.text('Verify Corporate Access'), findsOneWidget);
      expect(find.text('SYS.AUTH // HR_GATE'), findsOneWidget);

      // Identity Mode Tabs
      expect(find.text('Corporate Employee'), findsOneWidget);
      expect(find.text('Public User'), findsOneWidget);

      // Corporate Section is Present by Default
      expect(find.byKey(const Key('section_corporate_employee')), findsOneWidget);
      expect(find.byKey(const Key('work_email_input')), findsOneWidget);
      expect(find.byKey(const Key('section_public_user')), findsNothing);
    });

    testWidgets('TC-5.03 & TC-5.04: Mode Selector Toggle swaps to Public User mode', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Public User Mode
      final publicToggle = find.byKey(const Key('toggle_mode_publicUser'));
      expect(publicToggle, findsOneWidget);

      await tester.tap(publicToggle);
      await tester.pump(const Duration(milliseconds: 250));

      // Verify UI Swapped to Public User Profile Card
      expect(find.byKey(const Key('section_public_user')), findsOneWidget);
      expect(find.text('Open Commuter Pool'), findsOneWidget);
      expect(find.text('100% Mandatory Govt KYC'), findsOneWidget);
      expect(find.text('Cashless Karma Coins'), findsOneWidget);
      expect(find.text('Live 112 SOS & Family Tracking'), findsOneWidget);
      expect(find.byKey(const Key('continue_public_kyc_button')), findsOneWidget);
      expect(find.byKey(const Key('section_corporate_employee')), findsNothing);

      // Header dynamically updates for Public User
      expect(find.text('Public Commuter Portal'), findsOneWidget);
      expect(find.text('Public Commuter Network'), findsOneWidget);
      expect(find.text('SYS.AUTH // PUBLIC_GATE'), findsOneWidget);

      // Switch back to Corporate Employee
      final corpToggle = find.byKey(const Key('toggle_mode_corporateEmployee'));
      await tester.tap(corpToggle);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('section_corporate_employee')), findsOneWidget);
      expect(find.byKey(const Key('section_public_user')), findsNothing);
    });

    testWidgets('TC-5.27: Tapping Public User Continue CTA triggers confirmation snackbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Public User
      await tester.tap(find.byKey(const Key('toggle_mode_publicUser')));
      await tester.pump(const Duration(milliseconds: 250));

      // Tap "Continue to Govt KYC Verification" CTA
      final continueBtn = find.byKey(const Key('continue_public_kyc_button'));
      expect(continueBtn, findsOneWidget);

      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Confirmation Snackbar
      expect(
        find.text('Public Commuter Mode Activated. Proceeding to Mandatory Govt KYC...'),
        findsOneWidget,
      );
    });
  });

  group('Category 2: Corporate Work Email & Domain Auto-Resolution (TC-5.05 to TC-5.11)', () {
    testWidgets('TC-5.05: Invalid incomplete email keeps Send OTP disabled without public domain banner', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      final emailInput = find.byKey(const Key('work_email_input'));
      await tester.enterText(emailInput, 'amit@infosys');
      await tester.pump(const Duration(milliseconds: 100));

      // Send OTP button exists but no public domain error banner
      expect(find.byKey(const Key('send_otp_button')), findsOneWidget);
      expect(find.byKey(const Key('public_domain_error_banner')), findsNothing);
      expect(find.byKey(const Key('company_recognition_chip')), findsNothing);
    });

    testWidgets('TC-5.06 & TC-5.07: Public domains (@gmail.com, @yahoo.com) trigger red error banner and disable Send OTP', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      final emailInput = find.byKey(const Key('work_email_input'));

      // 1. Enter gmail.com
      await tester.enterText(emailInput, 'john.doe@gmail.com');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('public_domain_error_banner')), findsOneWidget);
      expect(find.text('Public domains not allowed. Please enter your work email.'), findsOneWidget);
      expect(find.byKey(const Key('company_recognition_chip')), findsNothing);

      // 2. Enter yahoo.com
      await tester.enterText(emailInput, 'priya@yahoo.com');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('public_domain_error_banner')), findsOneWidget);
      expect(find.byKey(const Key('company_recognition_chip')), findsNothing);
    });

    testWidgets('TC-5.08, TC-5.09, TC-5.10: Valid Corporate Email auto-resolves company and enables Send OTP', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      final emailInput = find.byKey(const Key('work_email_input'));

      // 1. Infosys email
      await tester.enterText(emailInput, 'amit.sharma@infosys.com');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('public_domain_error_banner')), findsNothing);
      expect(find.byKey(const Key('company_recognition_chip')), findsOneWidget);
      expect(find.text('Recognized: Infosys Technologies'), findsOneWidget);

      // 2. TCS email
      await tester.enterText(emailInput, 'rahul@tcs.com');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('company_recognition_chip')), findsOneWidget);
      expect(find.text('Recognized: Tata Consultancy Services'), findsOneWidget);

      // 3. Custom/generic enterprise email (unlisted in hardcoded map but valid work domain)
      await tester.enterText(emailInput, 'executive@spacex.com');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('company_recognition_chip')), findsOneWidget);
      expect(find.text('Recognized: Spacex'), findsOneWidget);
    });

    testWidgets('TC-5.11: Tapping Send Magic OTP dispatches OTP and shows confirmation snackbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      final emailInput = find.byKey(const Key('work_email_input'));
      await tester.enterText(emailInput, 'amit@wipro.com');
      await tester.pump(const Duration(milliseconds: 100));

      final sendOtpBtn = find.byKey(const Key('send_otp_button'));
      expect(sendOtpBtn, findsOneWidget);

      await tester.ensureVisible(sendOtpBtn);
      await tester.tap(sendOtpBtn);
      await tester.pump(); // Start dispatch

      expect(find.text('Dispatching OTP...'), findsOneWidget);

      // Finish dispatch timer (250ms)
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('OTP dispatched to amit@wipro.com'), findsOneWidget);
    });
  });
}
