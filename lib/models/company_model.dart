class CompanyModel {
  final String id;
  final String name;
  final String domain;
  final String? gstin;
  final String? managerId;
  final double totalCoinsPool;
  final double defaultMonthlyGrantPerEmployee;
  final String subscriptionPlan; // 'starter', 'growth', 'enterprise', 'free_trial'
  final bool autoApproveDomainOtp;
  final bool fuelVoucherEnabled;
  final bool isActive;
  final DateTime? createdAt;

  CompanyModel({
    required this.id,
    required this.name,
    required this.domain,
    this.gstin,
    this.managerId,
    this.totalCoinsPool = 0.0,
    this.defaultMonthlyGrantPerEmployee = 400.0,
    this.subscriptionPlan = 'starter',
    this.autoApproveDomainOtp = false,
    this.fuelVoucherEnabled = false,
    this.isActive = true,
    this.createdAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      gstin: json['gstin']?.toString(),
      managerId: json['manager_id']?.toString(),
      totalCoinsPool: (json['total_coins_pool'] as num?)?.toDouble() ?? 0.0,
      defaultMonthlyGrantPerEmployee: (json['default_monthly_grant_per_employee'] as num?)?.toDouble() ?? 400.0,
      subscriptionPlan: json['subscription_plan']?.toString() ?? 'starter',
      autoApproveDomainOtp: json['auto_approve_domain_otp'] ?? false,
      fuelVoucherEnabled: json['fuel_voucher_enabled'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class BuildingModel {
  final String id;
  final String name;
  final String? companyId;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final int radiusM;
  final String attendanceWindowStart;
  final String attendanceWindowEnd;
  final bool isActive;

  BuildingModel({
    required this.id,
    required this.name,
    this.companyId,
    required this.address,
    this.city = 'Bengaluru',
    required this.lat,
    required this.lng,
    this.radiusM = 500,
    this.attendanceWindowStart = '06:00:00',
    this.attendanceWindowEnd = '11:00:00',
    this.isActive = true,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    double parseLat(dynamic val, dynamic geom) {
      if (val != null) return (val as num).toDouble();
      if (geom != null && geom['coordinates'] is List) {
        return (geom['coordinates'][1] as num).toDouble();
      }
      return 0.0;
    }

    double parseLng(dynamic val, dynamic geom) {
      if (val != null) return (val as num).toDouble();
      if (geom != null && geom['coordinates'] is List) {
        return (geom['coordinates'][0] as num).toDouble();
      }
      return 0.0;
    }

    return BuildingModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      companyId: json['company_id']?.toString(),
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? 'Bengaluru',
      lat: parseLat(json['lat'], json['geofence_center']),
      lng: parseLng(json['lng'], json['geofence_center']),
      radiusM: (json['geofence_radius_m'] as num?)?.toInt() ?? 500,
      attendanceWindowStart: json['attendance_window_start']?.toString() ?? '06:00:00',
      attendanceWindowEnd: json['attendance_window_end']?.toString() ?? '11:00:00',
      isActive: json['is_active'] ?? true,
    );
  }
}
