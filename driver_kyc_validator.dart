/// Vehicle & License Types for Driver Onboarding Gate
enum DlVehicleClass {
  lmv, // Light Motor Vehicle (Car / 4-Wheeler)
  mcwg, // Motorcycle with Gear (Bike / 2-Wheeler)
  both, // Both LMV and MCWG
  commercial, // Commercial / Transport
  unknown,
}

enum VehicleType {
  car, // 4-Wheeler Passenger Car / SUV / Sedan / Hatchback
  bike, // 2-Wheeler Motorcycle / Scooter
  commercial, // Yellow-board Commercial Taxi (prohibited for peer carpooling)
  unknown,
}

/// Driving License record extracted from Government Sarathi API
class DlProfileRecord {
  final String dlNumber;
  final String holderName;
  final DlVehicleClass vehicleClass;
  final String expiryDate;
  final bool isExpired;
  final String issueDate;

  const DlProfileRecord({
    required this.dlNumber,
    required this.holderName,
    required this.vehicleClass,
    required this.expiryDate,
    required this.isExpired,
    required this.issueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'dl_number': dlNumber,
      'holder_name': holderName,
      'vehicle_class': vehicleClass.name,
      'expiry_date': expiryDate,
      'is_expired': isExpired,
      'issue_date': issueDate,
    };
  }
}

/// Vehicle Registration Certificate (RC) record extracted from Government Vahan API
class RcVehicleRecord {
  final String rcNumber;
  final String ownerName;
  final VehicleType vehicleType;
  final String make;
  final String model;
  final String color;
  final String fuelType;
  final int seatingCapacity;
  final String insuranceExpiryDate;
  final bool isInsuranceExpired;
  final String pucExpiryDate;
  final bool isPucExpired;
  final bool isCommercial;

  const RcVehicleRecord({
    required this.rcNumber,
    required this.ownerName,
    required this.vehicleType,
    required this.make,
    required this.model,
    required this.color,
    required this.fuelType,
    required this.seatingCapacity,
    required this.insuranceExpiryDate,
    required this.isInsuranceExpired,
    required this.pucExpiryDate,
    required this.isPucExpired,
    this.isCommercial = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'rc_number': rcNumber,
      'owner_name': ownerName,
      'vehicle_type': vehicleType.name,
      'make': make,
      'model': model,
      'color': color,
      'fuel_type': fuelType,
      'seating_capacity': seatingCapacity,
      'insurance_expiry_date': insuranceExpiryDate,
      'is_insurance_expired': isInsuranceExpired,
      'puc_expiry_date': pucExpiryDate,
      'is_puc_expired': isPucExpired,
      'is_commercial': isCommercial,
    };
  }
}

/// Comprehensive Safety & Cross-Validation Result for Screen 7
class DriverSafetyValidationResult {
  final bool isFullyApproved;
  final bool isDlValid;
  final bool isRcValid;
  final bool isInsuranceValid;
  final bool isPucValid;
  final bool isClassCompatible;
  final bool isNameMatched;
  final bool isOwnerMismatch;
  final bool isCommercialBlocked;
  final String? blockReason;
  final String? warningReason;

  const DriverSafetyValidationResult({
    required this.isFullyApproved,
    required this.isDlValid,
    required this.isRcValid,
    required this.isInsuranceValid,
    required this.isPucValid,
    required this.isClassCompatible,
    required this.isNameMatched,
    required this.isOwnerMismatch,
    this.isCommercialBlocked = false,
    this.blockReason,
    this.warningReason,
  });
}

/// Driver License & Vehicle RC Validation Engine
/// 100% compliant with Screen 7 Specification and Indian Motor Vehicles Act
class DriverKycValidator {
  // Indian State & UT 2-letter codes
  static const Set<String> validIndianStateCodes = {
    'AN', 'AP', 'AR', 'AS', 'BR', 'CH', 'CG', 'DD', 'DL', 'DN',
    'GA', 'GJ', 'HR', 'HP', 'JH', 'JK', 'KA', 'KL', 'LA', 'LD',
    'MH', 'ML', 'MN', 'MP', 'MZ', 'NL', 'OD', 'OR', 'PB', 'PY',
    'RJ', 'SK', 'TN', 'TR', 'TS', 'UK', 'UP', 'UT', 'WB',
  };

  /// Auto-formats Driving License numbers: e.g. "mh1220100012345" -> "MH12 20100012345"
  static String formatDrivingLicense(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length <= 4) {
      return clean;
    }
    final prefix = clean.substring(0, 4);
    final rest = clean.substring(4);
    if (rest.length > 11) {
      return '$prefix ${rest.substring(0, 11)}';
    }
    return '$prefix $rest';
  }

  /// Validates format of Driving License
  static bool isValidDlFormat(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length != 15 && clean.length != 16) {
      return false;
    }
    final stateCode = clean.substring(0, 2);
    if (!validIndianStateCodes.contains(stateCode)) {
      return false;
    }
    final rtoCode = clean.substring(2, 4);
    if (int.tryParse(rtoCode) == null) {
      return false;
    }
    return true;
  }

  /// Auto-formats Indian Number Plates: e.g. "ka01ab1234" -> "KA 01 AB 1234"
  static String formatVehicleRc(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length <= 2) return clean;

    final state = clean.substring(0, 2);
    final rest = clean.substring(2);

    final match = RegExp(r'^(\d{1,2})([A-Z]{1,3})?(\d{1,4})?$').firstMatch(rest);
    if (match != null) {
      final parts = <String>[state];
      for (int i = 1; i <= match.groupCount; i++) {
        final g = match.group(i);
        if (g != null && g.isNotEmpty) parts.add(g);
      }
      return parts.join(' ');
    }
    return '$state $rest';
  }

  /// Validates format of Vehicle Number Plate
  static bool isValidRcFormat(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length < 8 || clean.length > 11) {
      return false;
    }
    final stateCode = clean.substring(0, 2);
    if (!validIndianStateCodes.contains(stateCode)) {
      return false;
    }
    // Check regex pattern: 2 letters, 1-2 digits (with optional letter), 0-3 letters, 4 digits
    final rcRegex = RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]?[A-Z]{0,3}\d{4}$');
    return rcRegex.hasMatch(clean);
  }

  /// Mock Government Sarathi DL Lookup Database Engine
  static DlProfileRecord? lookupSarathiDl(String rawDl, {String? compareAadhaarName}) {
    final clean = rawDl.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (!isValidDlFormat(clean)) return null;

    final targetName = compareAadhaarName ?? 'Rahul Kumar';

    // 1. Expired DL Vector
    if (clean.contains('2001') || clean.endsWith('99990')) {
      return DlProfileRecord(
        dlNumber: formatDrivingLicense(clean),
        holderName: targetName,
        vehicleClass: DlVehicleClass.lmv,
        expiryDate: '15/03/2021',
        isExpired: true,
        issueDate: '16/03/2001',
      );
    }

    // 2. Name Mismatch Vector (Amit Shah vs Rahul Kumar)
    if (clean.contains('7777') || clean.endsWith('8888')) {
      return DlProfileRecord(
        dlNumber: formatDrivingLicense(clean),
        holderName: 'Amit Shah',
        vehicleClass: DlVehicleClass.lmv,
        expiryDate: '28/09/2038',
        isExpired: false,
        issueDate: '29/09/2018',
      );
    }

    // 3. Bike-Only DL Vector (MCWG)
    if (clean.contains('9999') || clean.endsWith('5555')) {
      return DlProfileRecord(
        dlNumber: formatDrivingLicense(clean),
        holderName: targetName,
        vehicleClass: DlVehicleClass.mcwg,
        expiryDate: '12/11/2036',
        isExpired: false,
        issueDate: '13/11/2016',
      );
    }

    // 4. Default: Valid LMV & MCWG Dual License
    return DlProfileRecord(
      dlNumber: formatDrivingLicense(clean),
      holderName: targetName,
      vehicleClass: DlVehicleClass.both,
      expiryDate: '24/08/2037',
      isExpired: false,
      issueDate: '25/08/2017',
    );
  }

  /// Mock Government Vahan RC Lookup Database Engine
  static RcVehicleRecord? lookupVahanRc(String rawRc, {String? compareDriverName}) {
    final clean = rawRc.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (!isValidRcFormat(clean)) return null;

    final targetName = compareDriverName ?? 'Rahul Kumar';

    // 1. Commercial Yellow Board Taxi (Rejected for peer carpooling)
    if (clean.contains('TC') || clean.contains('TX') || clean.endsWith('0001')) {
      return RcVehicleRecord(
        rcNumber: formatVehicleRc(clean),
        ownerName: 'City Cabs Logistics Ltd',
        vehicleType: VehicleType.commercial,
        make: 'Maruti Suzuki',
        model: 'Dzire Tour (Commercial)',
        color: 'Yellow & Black',
        fuelType: 'CNG',
        seatingCapacity: 4,
        insuranceExpiryDate: '10/05/2027',
        isInsuranceExpired: false,
        pucExpiryDate: '12/04/2026',
        isPucExpired: false,
        isCommercial: true,
      );
    }

    // 2. Expired Insurance Vector
    if (clean.contains('9999') || clean.endsWith('1111')) {
      return RcVehicleRecord(
        rcNumber: formatVehicleRc(clean),
        ownerName: targetName,
        vehicleType: VehicleType.car,
        make: 'Honda',
        model: 'City ZX i-VTEC',
        color: 'Radiant Red',
        fuelType: 'Petrol',
        seatingCapacity: 5,
        insuranceExpiryDate: '01/01/2022',
        isInsuranceExpired: true,
        pucExpiryDate: '15/09/2026',
        isPucExpired: false,
      );
    }

    // 3. Expired PUC Vector
    if (clean.contains('8888') || clean.endsWith('2222')) {
      return RcVehicleRecord(
        rcNumber: formatVehicleRc(clean),
        ownerName: targetName,
        vehicleType: VehicleType.car,
        make: 'Tata',
        model: 'Harrier XZ+',
        color: 'Calypso Red',
        fuelType: 'Diesel',
        seatingCapacity: 5,
        insuranceExpiryDate: '18/10/2027',
        isInsuranceExpired: false,
        pucExpiryDate: '05/02/2023',
        isPucExpired: true,
      );
    }

    // 4. Owner Mismatch Vector (Parent/Family car)
    if (clean.startsWith('MH12') || clean.contains('PARENT')) {
      return RcVehicleRecord(
        rcNumber: formatVehicleRc(clean),
        ownerName: 'Rajesh Kumar (Parent)',
        vehicleType: VehicleType.car,
        make: 'Tata',
        model: 'Nexon EV Empowered',
        color: 'Pristine White',
        fuelType: 'EV',
        seatingCapacity: 5,
        insuranceExpiryDate: '24/11/2028',
        isInsuranceExpired: false,
        pucExpiryDate: '30/12/2026',
        isPucExpired: false,
      );
    }

    // 5. Bike Vector
    if (clean.contains('XY') || clean.contains('BK')) {
      return RcVehicleRecord(
        rcNumber: formatVehicleRc(clean),
        ownerName: targetName,
        vehicleType: VehicleType.bike,
        make: 'Royal Enfield',
        model: 'Classic 350 Stealth',
        color: 'Matte Black',
        fuelType: 'Petrol',
        seatingCapacity: 2,
        insuranceExpiryDate: '15/06/2027',
        isInsuranceExpired: false,
        pucExpiryDate: '20/08/2026',
        isPucExpired: false,
      );
    }

    // 6. Default: Valid Self-Owned 4-Wheeler Car
    return RcVehicleRecord(
      rcNumber: formatVehicleRc(clean),
      ownerName: targetName,
      vehicleType: VehicleType.car,
      make: 'Hyundai',
      model: 'Creta SX (O)',
      color: 'Polar White',
      fuelType: 'Petrol',
      seatingCapacity: 5,
      insuranceExpiryDate: '15/09/2027',
      isInsuranceExpired: false,
      pucExpiryDate: '20/11/2026',
      isPucExpired: false,
    );
  }

  /// Calculates fuzzy or exact name match between DL Name and Aadhaar Name
  static bool isNameMatched(String dlName, String aadhaarName) {
    final clean1 = dlName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ' ').trim();
    final clean2 = aadhaarName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ' ').trim();

    if (clean1 == clean2) return true;

    final tokens1 = clean1.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    final tokens2 = clean2.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

    // Check intersection
    final intersection = tokens1.intersection(tokens2);
    return intersection.length >= 2 || (tokens1.length == 1 && intersection.isNotEmpty);
  }

  /// Advanced Cross-Validation Engine across DL, RC, Safety Dates & Aadhaar Identity
  static DriverSafetyValidationResult validateSafetyAndCompatibility({
    required DlProfileRecord dl,
    required RcVehicleRecord rc,
    required String driverAadhaarName,
    bool isOwnerAuthorizationDeclared = false,
  }) {
    // 1. DL Expiry Check (Hard Block)
    if (dl.isExpired) {
      return DriverSafetyValidationResult(
        isFullyApproved: false,
        isDlValid: false,
        isRcValid: true,
        isInsuranceValid: !rc.isInsuranceExpired,
        isPucValid: !rc.isPucExpired,
        isClassCompatible: true,
        isNameMatched: true,
        isOwnerMismatch: false,
        blockReason: 'Driving License expired on ${dl.expiryDate}. Cannot register.',
      );
    }

    // 2. DL Name vs Aadhaar Name Match (Hard Block)
    final nameMatches = isNameMatched(dl.holderName, driverAadhaarName);
    if (!nameMatches) {
      return DriverSafetyValidationResult(
        isFullyApproved: false,
        isDlValid: false,
        isRcValid: true,
        isInsuranceValid: !rc.isInsuranceExpired,
        isPucValid: !rc.isPucExpired,
        isClassCompatible: true,
        isNameMatched: false,
        isOwnerMismatch: false,
        blockReason: 'DL Name (${dl.holderName}) does not match your verified Aadhaar Name ($driverAadhaarName).',
      );
    }

    // 3. Commercial Board Check (Hard Block)
    if (rc.isCommercial) {
      return const DriverSafetyValidationResult(
        isFullyApproved: false,
        isDlValid: true,
        isRcValid: false,
        isInsuranceValid: true,
        isPucValid: true,
        isClassCompatible: true,
        isNameMatched: true,
        isOwnerMismatch: false,
        isCommercialBlocked: true,
        blockReason: 'Commercial / Yellow-board taxi vehicles are prohibited on peer carpooling.',
      );
    }

    // 4. DL Class vs RC Vehicle Type Compatibility (Hard Block)
    bool classMatches = true;
    if (rc.vehicleType == VehicleType.car) {
      if (dl.vehicleClass != DlVehicleClass.lmv && dl.vehicleClass != DlVehicleClass.both) {
        classMatches = false;
      }
    } else if (rc.vehicleType == VehicleType.bike) {
      if (dl.vehicleClass != DlVehicleClass.mcwg && dl.vehicleClass != DlVehicleClass.both) {
        classMatches = false;
      }
    }

    if (!classMatches) {
      return DriverSafetyValidationResult(
        isFullyApproved: false,
        isDlValid: true,
        isRcValid: true,
        isInsuranceValid: !rc.isInsuranceExpired,
        isPucValid: !rc.isPucExpired,
        isClassCompatible: false,
        isNameMatched: true,
        isOwnerMismatch: false,
        blockReason: 'Your DL (${dl.vehicleClass.name.toUpperCase()}) does not permit driving a ${rc.vehicleType.name.toUpperCase()}.',
      );
    }

    // 5. RC Owner Name vs Driver Name (Informational - Non-Blocking)
    final isOwnerSame = isNameMatched(rc.ownerName, driverAadhaarName);
    final bool isOwnerMismatch = !isOwnerSame;

    // 6. Insurance & PUC Expiry (Informational Warnings - Non-Blocking)
    final isInsuranceValid = !rc.isInsuranceExpired;
    final isPucValid = !rc.isPucExpired;

    final warningList = <String>[];
    if (!isInsuranceValid) {
      warningList.add('Insurance expired on ${rc.insuranceExpiryDate}');
    }
    if (!isPucValid) {
      warningList.add('PUC expired on ${rc.pucExpiryDate}');
    }
    if (isOwnerMismatch) {
      warningList.add('Vehicle registered under ${rc.ownerName}');
    }

    final String? warningReason = warningList.isNotEmpty ? warningList.join('. ') : null;

    // Fully Approved (Non-blocking for Insurance, PUC, and Owner Mismatch)
    return DriverSafetyValidationResult(
      isFullyApproved: true,
      isDlValid: true,
      isRcValid: true,
      isInsuranceValid: isInsuranceValid,
      isPucValid: isPucValid,
      isClassCompatible: true,
      isNameMatched: true,
      isOwnerMismatch: isOwnerMismatch,
      warningReason: warningReason,
    );
  }
}
