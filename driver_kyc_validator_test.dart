import 'package:flutter_test/flutter_test.dart';
import 'package:corporate_pooling_app/core/services/driver_kyc_validator.dart';

void main() {
  group('DriverKycValidator - Phase 1 Engine Tests', () {
    test('TC-7.03: DL auto-formatting and normalization', () {
      expect(DriverKycValidator.formatDrivingLicense('mh1220100012345'), 'MH12 20100012345');
      expect(DriverKycValidator.formatDrivingLicense('ka01 20210005678'), 'KA01 20210005678');
      expect(DriverKycValidator.isValidDlFormat('MH1220100012345'), true);
      expect(DriverKycValidator.isValidDlFormat('KA01 20210005678'), true);
      expect(DriverKycValidator.isValidDlFormat('XX12345'), false); // Invalid state
      expect(DriverKycValidator.isValidDlFormat('123456789012345'), false); // No state prefix
    });

    test('TC-7.06: RC Number Plate auto-formatting and normalization', () {
      expect(DriverKycValidator.formatVehicleRc('ka01ab1234'), 'KA 01 AB 1234');
      expect(DriverKycValidator.formatVehicleRc('mh12cd5678'), 'MH 12 CD 5678');
      expect(DriverKycValidator.formatVehicleRc('dl03ab9999'), 'DL 03 AB 9999');
      expect(DriverKycValidator.isValidRcFormat('KA01AB1234'), true);
      expect(DriverKycValidator.isValidRcFormat('MH 12 CD 5678'), true);
      expect(DriverKycValidator.isValidRcFormat('INVALID_PLATE'), false);
    });

    test('Sarathi DL Lookup & Name/Expiry Extraction', () {
      final validDl = DriverKycValidator.lookupSarathiDl('MH12 20100012345', compareAadhaarName: 'Rahul Kumar');
      expect(validDl, isNotNull);
      expect(validDl!.holderName, 'Rahul Kumar');
      expect(validDl.isExpired, false);

      final expiredDl = DriverKycValidator.lookupSarathiDl('MH14 20010000001', compareAadhaarName: 'Rahul Kumar');
      expect(expiredDl, isNotNull);
      expect(expiredDl!.isExpired, true);

      final mismatchedDl = DriverKycValidator.lookupSarathiDl('KA05 20150007777', compareAadhaarName: 'Rahul Kumar');
      expect(mismatchedDl, isNotNull);
      expect(mismatchedDl!.holderName, 'Amit Shah');
    });

    test('Vahan RC Lookup & Vehicle Details Extraction', () {
      final validCar = DriverKycValidator.lookupVahanRc('KA 01 AB 1234', compareDriverName: 'Rahul Kumar');
      expect(validCar, isNotNull);
      expect(validCar!.make, 'Hyundai');
      expect(validCar.model, 'Creta SX (O)');
      expect(validCar.fuelType, 'Petrol');
      expect(validCar.seatingCapacity, 5);
      expect(validCar.isInsuranceExpired, false);
      expect(validCar.isPucExpired, false);

      final commercialTaxi = DriverKycValidator.lookupVahanRc('MH 01 TC 0001');
      expect(commercialTaxi, isNotNull);
      expect(commercialTaxi!.isCommercial, true);

      final expiredInsuranceCar = DriverKycValidator.lookupVahanRc('DL 3C AB 9999');
      expect(expiredInsuranceCar, isNotNull);
      expect(expiredInsuranceCar!.isInsuranceExpired, true);

      final expiredPucCar = DriverKycValidator.lookupVahanRc('KA 02 MN 8888');
      expect(expiredPucCar, isNotNull);
      expect(expiredPucCar!.isPucExpired, true);
    });

    test('TC-7.04 & TC-7.05: DL Name Mismatch & Expired DL Safety Guard', () {
      final expiredDl = DriverKycValidator.lookupSarathiDl('MH14 20010000001')!;
      final validCar = DriverKycValidator.lookupVahanRc('KA 01 AB 1234')!;
      final expiredResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: expiredDl,
        rc: validCar,
        driverAadhaarName: 'Rahul Kumar',
      );
      expect(expiredResult.isFullyApproved, false);
      expect(expiredResult.isDlValid, false);
      expect(expiredResult.blockReason, contains('expired'));

      final mismatchedDl = DriverKycValidator.lookupSarathiDl('KA05 20150007777')!;
      final mismatchResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: mismatchedDl,
        rc: validCar,
        driverAadhaarName: 'Rahul Kumar',
      );
      expect(mismatchResult.isFullyApproved, false);
      expect(mismatchResult.isNameMatched, false);
      expect(mismatchResult.blockReason, contains('DL Name'));
    });

    test('TC-7.08, TC-7.09 & TC-7.10: Commercial, Insurance & PUC Blocks', () {
      final validDl = DriverKycValidator.lookupSarathiDl('MH12 20100012345')!;
      
      // Commercial check (TC-7.08)
      final commercialRc = DriverKycValidator.lookupVahanRc('MH 01 TC 0001')!;
      final commercialResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: validDl,
        rc: commercialRc,
        driverAadhaarName: 'Rahul Kumar',
      );
      expect(commercialResult.isFullyApproved, false);
      expect(commercialResult.isCommercialBlocked, true);

      // Expired Insurance check (TC-7.09)
      final expiredInsRc = DriverKycValidator.lookupVahanRc('DL 3C AB 9999')!;
      final insResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: validDl,
        rc: expiredInsRc,
        driverAadhaarName: 'Rahul Kumar',
      );
      expect(insResult.isFullyApproved, false);
      expect(insResult.isInsuranceValid, false);
      expect(insResult.blockReason, contains('Insurance expired'));

      // Expired PUC check (TC-7.10)
      final expiredPucRc = DriverKycValidator.lookupVahanRc('KA 02 MN 8888')!;
      final pucResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: validDl,
        rc: expiredPucRc,
        driverAadhaarName: 'Rahul Kumar',
      );
      expect(pucResult.isFullyApproved, false);
      expect(pucResult.isPucValid, false);
      expect(pucResult.blockReason, contains('PUC certificate expired'));
    });

    test('TC-7.11: DL Class vs RC Type Compatibility (Bike DL with Car RC)', () {
      final bikeOnlyDl = DriverKycValidator.lookupSarathiDl('DL04 20180009999')!; // MCWG only
      final carRc = DriverKycValidator.lookupVahanRc('KA 01 AB 1234')!; // Car
      
      final classMismatchResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: bikeOnlyDl,
        rc: carRc,
        driverAadhaarName: 'Rahul Kumar',
      );
      expect(classMismatchResult.isFullyApproved, false);
      expect(classMismatchResult.isClassCompatible, false);
      expect(classMismatchResult.blockReason, contains('does not permit driving'));
    });

    test('TC-7.12, TC-7.13 & TC-7.14: RC Owner Mismatch & Declaration Physics', () {
      final validDl = DriverKycValidator.lookupSarathiDl('MH12 20100012345')!;
      final parentCarRc = DriverKycValidator.lookupVahanRc('MH 12 AB 1234')!; // Owner: Rajesh Kumar (Parent)

      // Unchecked declaration -> blocked (TC-7.14)
      final blockedResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: validDl,
        rc: parentCarRc,
        driverAadhaarName: 'Rahul Kumar',
        isOwnerAuthorizationDeclared: false,
      );
      expect(blockedResult.isFullyApproved, false);
      expect(blockedResult.isOwnerMismatch, true);

      // Checked declaration -> approved (TC-7.13)
      final approvedResult = DriverKycValidator.validateSafetyAndCompatibility(
        dl: validDl,
        rc: parentCarRc,
        driverAadhaarName: 'Rahul Kumar',
        isOwnerAuthorizationDeclared: true,
      );
      expect(approvedResult.isFullyApproved, true);
      expect(approvedResult.isOwnerMismatch, true);
    });

    test('100% Valid Driver & Self-Owned Vehicle Approval', () {
      final validDl = DriverKycValidator.lookupSarathiDl('MH12 20100012345')!;
      final validCar = DriverKycValidator.lookupVahanRc('KA 01 AB 1234')!;

      final result = DriverKycValidator.validateSafetyAndCompatibility(
        dl: validDl,
        rc: validCar,
        driverAadhaarName: 'Rahul Kumar',
      );
      expect(result.isFullyApproved, true);
      expect(result.isDlValid, true);
      expect(result.isRcValid, true);
      expect(result.isInsuranceValid, true);
      expect(result.isPucValid, true);
      expect(result.isClassCompatible, true);
      expect(result.isNameMatched, true);
      expect(result.isOwnerMismatch, false);
    });
  });
}
