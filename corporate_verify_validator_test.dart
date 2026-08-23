import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/core/services/corporate_verify_validator.dart';

void main() {
  group('CorporateVerifyValidator - Phase 1 Validation & Logic Tests', () {
    test('TC-5.05: Invalid email format returns isValid: false', () {
      final res1 = CorporateVerifyValidator.validateEmail('amit@infosys');
      expect(res1.isValid, isFalse);

      final res2 = CorporateVerifyValidator.validateEmail('amit');
      expect(res2.isValid, isFalse);

      final res3 = CorporateVerifyValidator.validateEmail('');
      expect(res3.isValid, isFalse);
    });

    test('TC-5.06: Public domain @gmail.com is blacklisted', () {
      final res = CorporateVerifyValidator.validateEmail('john.doe@gmail.com');
      expect(res.isValid, isFalse);
      expect(res.isPublicDomain, isTrue);
      expect(res.errorMessage, 'Public domains not allowed. Please enter your work email.');
    });

    test('TC-5.07: Public domain @yahoo.com and others are blacklisted', () {
      final domains = ['yahoo.com', 'outlook.com', 'hotmail.com', 'icloud.com', 'rediffmail.com', 'zoho.com'];
      for (final domain in domains) {
        final res = CorporateVerifyValidator.validateEmail('employee@$domain');
        expect(res.isValid, isFalse);
        expect(res.isPublicDomain, isTrue);
        expect(res.errorMessage, 'Public domains not allowed. Please enter your work email.');
      }
    });

    test('TC-5.08: Valid corporate domain returns isValid: true', () {
      final res = CorporateVerifyValidator.validateEmail('amit@infosys.com');
      expect(res.isValid, isTrue);
      expect(res.isPublicDomain, isFalse);
      expect(res.domain, 'infosys.com');
      expect(res.companyName, 'Infosys Technologies');
      expect(res.isAutoWhitelisted, isTrue);
    });

    test('TC-5.09: Domain auto-resolution maps known companies and stems', () {
      expect(CorporateVerifyValidator.resolveCompanyName('tcs.com'), 'Tata Consultancy Services');
      expect(CorporateVerifyValidator.resolveCompanyName('wipro.com'), 'Wipro Limited');
      expect(CorporateVerifyValidator.resolveCompanyName('google.com'), 'Google');
      expect(CorporateVerifyValidator.resolveCompanyName('nvidia.com'), 'Nvidia');
    });

    test('TC-5.18 & TC-5.20: Clipboard OTP extraction', () {
      // Direct 6 digits
      expect(CorporateVerifyValidator.extractOtpFromClipboard('123456'), '123456');

      // 8 digits (extracts first 6)
      expect(CorporateVerifyValidator.extractOtpFromClipboard('12345678'), '123456');

      // Conversational SMS string
      expect(CorporateVerifyValidator.extractOtpFromClipboard('Your KarmaRide verification OTP is 556677'), '556677');

      // Invalid text without 6 digits
      expect(CorporateVerifyValidator.extractOtpFromClipboard('Hello world 123'), isNull);
    });

    test('TC-5.29 to TC-5.32: Invite code validation', () {
      expect(CorporateVerifyValidator.isValidInviteCode('INFY26'), isTrue);
      expect(CorporateVerifyValidator.isValidInviteCode('TCS001'), isTrue);
      expect(CorporateVerifyValidator.isValidInviteCode('WIPRO'), isFalse); // only 5 chars
      expect(CorporateVerifyValidator.isValidInviteCode('INFY2026'), isFalse); // 8 chars
      expect(CorporateVerifyValidator.isValidInviteCode('!@#456'), isFalse); // special characters
    });
  });
}
