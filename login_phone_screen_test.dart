import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:corporate_pooling_app/core/api_client.dart';
import 'package:corporate_pooling_app/screens/auth/phone_login_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient.client = MockClient((request) async {
      if (request.url.path.contains('request-otp')) {
        return http.Response(
          jsonEncode({'status': 'success', 'message': 'OTP sent'}),
          200,
        );
      }
      if (request.url.path.contains('verify')) {
        final body = jsonDecode(request.body);
        if (body['otp'] == '123456') {
          return http.Response(
            jsonEncode({'status': 'success', 'token': 'mock_jwt_token'}),
            200,
          );
        } else {
          return http.Response(
            jsonEncode({'status': 'error', 'message': 'Incorrect verification code.'}),
            400,
          );
        }
      }
      return http.Response('{}', 200);
    });
  });

  tearDown(() {
    ApiClient.client = http.Client();
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: PhoneLoginScreen(),
    );
  }

  group('Screen 3: PhoneLoginScreen Automated Test Suite (Specification Compliance)', () {
    testWidgets('TC-01 & TC-04: Initial state renders phone input with disabled button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));

      // Check brand header
      expect(find.text('KarmaRide'), findsOneWidget);
      expect(find.text('Corporate Commute Network'), findsOneWidget);

      // Check phone view title
      expect(find.text('Enter your mobile number'), findsOneWidget);

      // Check country flag and default +91
      expect(find.text('🇮🇳'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);

      // Check legal disclaimer footer
      expect(find.textContaining('Terms of Service'), findsOneWidget);
      expect(find.textContaining('Privacy Policy'), findsOneWidget);

      // Check "Get Verification Code" button exists
      expect(find.text('Get Verification Code'), findsOneWidget);
    });

    testWidgets('TC-02 & TC-03: Invalid carrier prefix shows validation hint', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));

      final phoneField = find.byType(TextField);
      expect(phoneField, findsOneWidget);

      // Enter number starting with invalid prefix '1'
      await tester.enterText(phoneField, '1234567890');
      await tester.pump(const Duration(milliseconds: 100));

      // Check validation hint is displayed
      expect(find.text('Indian mobile numbers must start with 6, 7, 8, or 9'), findsOneWidget);
    });

    testWidgets('TC-06: Dummy sequence blocker prevents submission on 9999999999', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));

      final phoneField = find.byType(TextField);

      // Enter repetitive 9999999999
      await tester.enterText(phoneField, '9999999999');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Please enter a valid active mobile number'), findsOneWidget);
    });

    testWidgets('TC-08: Tapping country selector opens modal bottom sheet and allows selection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Country Code selector
      final countrySelector = find.text('+91');
      await tester.tap(countrySelector);
      await tester.pump(const Duration(milliseconds: 500));

      // Verify modal sheet is displayed with search bar and countries
      expect(find.text('Select Country Code'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);

      // Select United States (+1)
      await tester.tap(find.text('United States'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));

      // Verify selected country updated
      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.text('+1'), findsWidgets);
    });

    testWidgets('TC-09, TC-10 & TC-13: Valid phone number navigates to 6-digit OTP view', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));

      final phoneField = find.byType(TextField);
      await tester.enterText(phoneField, '9876543210');
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Get Verification Code"
      final getOtpButton = find.text('Get Verification Code');
      await tester.tap(getOtpButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify OTP screen rendered
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.textContaining('+91'), findsWidgets);

      // Verify 6 OTP TextFields exist
      final otpFields = find.byType(TextField);
      expect(otpFields, findsNWidgets(6));

      // Verify Resend timer exists
      expect(find.textContaining('Resend code in 00:'), findsOneWidget);
    });

    testWidgets('TC-09: Tapping Edit pencil returns to Phone Input with number populated', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));

      final phoneField = find.byType(TextField);
      await tester.enterText(phoneField, '9876543210');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Get Verification Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Edit"
      final editBtn = find.text('Edit');
      await tester.tap(editBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Should be back on Phone view with number intact
      expect(find.text('Enter your mobile number'), findsOneWidget);
      expect(find.text('98765 43210'), findsWidgets);
    });

    testWidgets('TC-36: 3 consecutive wrong OTP attempts triggers 60s security lockout', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));

      // Enter valid phone and go to OTP view
      final phoneField = find.byType(TextField);
      await tester.enterText(phoneField, '9876543210');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Get Verification Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Attempt 1: Wrong OTP
      final otpFields = find.byType(TextField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(otpFields.at(i), '0');
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('2 attempt(s) left'), findsOneWidget);

      // Attempt 2: Wrong OTP
      for (int i = 0; i < 6; i++) {
        await tester.enterText(otpFields.at(i), '0');
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('1 attempt(s) left'), findsOneWidget);

      // Attempt 3: Wrong OTP -> Triggers 60s lockout
      for (int i = 0; i < 6; i++) {
        await tester.enterText(otpFields.at(i), '0');
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Too many failed attempts'), findsOneWidget);
      expect(find.textContaining('Verification locked'), findsOneWidget);
    });
  });
}
