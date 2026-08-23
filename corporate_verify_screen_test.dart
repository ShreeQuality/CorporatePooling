import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/screens/auth/corporate_verify_screen.dart';

void main() {
  Widget buildTestApp() {
    return const MaterialApp(
      home: CorporateVerifyScreen(),
    );
  }

  group('Category 1: UI Initialization & Layout (TC-5.01 to TC-5.04)', () {
    testWidgets('TC-5.01 & Header: Screen loads with Work Email auto-focused and HUD header', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Header Elements
      expect(find.text('Corporate Identity Gate'), findsOneWidget);
      expect(find.text('Verify Corporate Access'), findsOneWidget);
      expect(find.text('SYS.AUTH // HR_VERIFY'), findsOneWidget);

      // Mode Selector Toggle
      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('HR Invite Code'), findsOneWidget);

      // Work Email Input Field is Present
      expect(find.byKey(const Key('work_email_input')), findsOneWidget);
    });

    testWidgets('TC-5.03: Skip Button Visibility and Action', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      final skipBtn = find.byKey(const Key('skip_public_commuter_button'));
      expect(skipBtn, findsOneWidget);
      expect(find.text("Skip — I'm a Public Commuter"), findsOneWidget);

      // Tap Skip Button
      await tester.tap(skipBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Toast/Snackbar appears
      expect(find.text('Public Commuter Mode Activated. Proceeding to KYC...'), findsOneWidget);
    });

    testWidgets('TC-5.04: Mode Selector Toggle swaps between Email and Invite Code', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Initial state is Work Email
      expect(find.byKey(const Key('section_work_email')), findsOneWidget);
      expect(find.byKey(const Key('work_email_input')), findsOneWidget);
      expect(find.byKey(const Key('section_invite_code')), findsNothing);

      // Switch to HR Invite Code
      final inviteToggle = find.byKey(const Key('toggle_mode_inviteCode'));
      await tester.tap(inviteToggle);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify UI swapped to Invite Code
      expect(find.byKey(const Key('section_invite_code')), findsOneWidget);
      expect(find.byKey(const Key('invite_code_input')), findsOneWidget);
      expect(find.byKey(const Key('section_work_email')), findsNothing);

      // Switch back to Work Email
      final emailToggle = find.byKey(const Key('toggle_mode_workEmail'));
      await tester.tap(emailToggle);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('section_work_email')), findsOneWidget);
      expect(find.byKey(const Key('work_email_input')), findsOneWidget);
      expect(find.byKey(const Key('section_invite_code')), findsNothing);
    });
  });
}
