import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/core/services/aadhaar_kyc_validator.dart';

void main() {
  group('AadhaarKycValidator - Phase 1 Engine Tests', () {
    // Generate valid 12-digit Aadhaar test vector using Verhoeff
    final testPrefix11 = '23456789012';
    final checkDigit12 = AadhaarKycValidator.generateVerhoeffCheckDigit(testPrefix11);
    final validAadhaar12 = '$testPrefix11$checkDigit12';

    // Generate valid 16-digit VID test vector using Verhoeff
    final testPrefix15 = '987654321098765';
    final checkDigit16 = AadhaarKycValidator.generateVerhoeffCheckDigit(testPrefix15);
    final validVid16 = '$testPrefix15$checkDigit16';

    test('TC-6.01-VAL: Verhoeff Checksum mathematical validation and check digit generator', () {
      expect(AadhaarKycValidator.validateVerhoeff(validAadhaar12), isTrue);
      expect(AadhaarKycValidator.validateVerhoeff(validVid16), isTrue);

      // Mutating single digit should immediately fail Verhoeff
      final corruptedDigit = (checkDigit12 + 1) % 10;
      final invalidAadhaar = '$testPrefix11$corruptedDigit';
      expect(AadhaarKycValidator.validateVerhoeff(invalidAadhaar), isFalse);
    });

    test('TC-6.03-VAL: Spacing auto-formatter formats 12-digit and 16-digit IDs into 4-digit chunks', () {
      expect(AadhaarKycValidator.formatAadhaarInput('123456789012'), '1234 5678 9012');
      expect(AadhaarKycValidator.formatAadhaarInput('1234567890123456'), '1234 5678 9012 3456');
      expect(AadhaarKycValidator.formatAadhaarInput('1234 5678 9012'), '1234 5678 9012');
    });

    test('TC-6.21-VAL: DPDP Data Masking masks all but last 4 digits', () {
      expect(AadhaarKycValidator.maskAadhaar('123456789012'), '•••• •••• 9012');
      expect(AadhaarKycValidator.maskAadhaar('1234567890123456'), '•••• •••• •••• 3456');
    });

    test('TC-6.06-VAL: 12-digit Aadhaar with invalid Verhoeff checksum returns error', () {
      final invalidCheckAadhaar = '${testPrefix11}${(checkDigit12 + 3) % 10}';
      final result = AadhaarKycValidator.validateAadhaarOrVid(invalidCheckAadhaar);

      expect(result.isValid, isFalse);
      expect(result.type, AadhaarIdType.aadhaar);
      expect(result.errorMessage, contains('Verhoeff Checksum Failed'));
    });

    test('TC-6.06-VAL-B: 12-digit Aadhaar starting with 0 or 1 is rejected', () {
      final result0 = AadhaarKycValidator.validateAadhaarOrVid('023456789012');
      final result1 = AadhaarKycValidator.validateAadhaarOrVid('123456789012');

      expect(result0.isValid, isFalse);
      expect(result0.errorMessage, contains('cannot start with 0 or 1'));
      expect(result1.isValid, isFalse);
      expect(result1.errorMessage, contains('cannot start with 0 or 1'));
    });

    test('TC-6.08-VAL: Valid 12-digit Aadhaar passes validation and returns clean payload', () {
      final result = AadhaarKycValidator.validateAadhaarOrVid(validAadhaar12);

      expect(result.isValid, isTrue);
      expect(result.type, AadhaarIdType.aadhaar);
      expect(result.rawDigits, validAadhaar12);
      expect(result.formatted, AadhaarKycValidator.formatAadhaarInput(validAadhaar12));
      expect(result.masked, AadhaarKycValidator.maskAadhaar(validAadhaar12));
      expect(result.errorMessage, isNull);
    });

    test('TC-6.07-VAL: 16-digit VID with invalid Verhoeff checksum returns error', () {
      final invalidVid = '${testPrefix15}${(checkDigit16 + 2) % 10}';
      final result = AadhaarKycValidator.validateAadhaarOrVid(invalidVid);

      expect(result.isValid, isFalse);
      expect(result.type, AadhaarIdType.vid);
      expect(result.errorMessage, contains('Verhoeff Checksum Failed'));
    });

    test('TC-6.08-VAL-B: Valid 16-digit VID passes validation', () {
      final result = AadhaarKycValidator.validateAadhaarOrVid(validVid16);

      expect(result.isValid, isTrue);
      expect(result.type, AadhaarIdType.vid);
      expect(result.errorMessage, isNull);
    });

    test('TC-6.19-VAL: QR Code parser extracts XML & JSON profiles accurately', () {
      const simulatedQr = 'UIDAI_SECURE_QR_V2_DATA_SIGNATURE_XML';
      final profile = AadhaarKycValidator.parseAadhaarQrPayload(simulatedQr);

      expect(profile, isNotNull);
      expect(profile!.fullName, 'Ananya Sharma');
      expect(profile.gender, 'Female');
      expect(profile.state, 'Maharashtra');
      expect(profile.isKycVerified, isTrue);
    });
  });
}
