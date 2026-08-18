class UserModel {
  final String id;
  final String phoneNumber;
  final String fullName;
  final String gender; // 'male', 'female', 'other', 'prefer_not_to_say'
  final String role; // 'corporate_employee', 'public_user', 'family_member', 'company_manager', 'super_admin'
  final String? workEmail;
  final bool workEmailVerified;
  final String? officeIdPhotoUrl;
  final bool officeIdVerified;
  final String? companyId;
  final String? buildingId;
  final String? primaryAccountId;
  final bool aadhaarVerified;
  final String? aadhaarMaskedNumber;
  final bool dlVerified;
  final String? profilePhotoUrl;
  final bool autoAcceptColleagues;
  final int autoAcceptMaxDetourM;
  final int trustScore; // 0 to 100
  final List<dynamic> emergencyContacts;
  final String? fcmToken;
  final String? fcmTokenPlatform;
  final DateTime? fcmTokenUpdatedAt;
  final bool isBanned;
  final String? banReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.gender = 'prefer_not_to_say',
    this.role = 'corporate_employee',
    this.workEmail,
    this.workEmailVerified = false,
    this.officeIdPhotoUrl,
    this.officeIdVerified = false,
    this.companyId,
    this.buildingId,
    this.primaryAccountId,
    this.aadhaarVerified = false,
    this.aadhaarMaskedNumber,
    this.dlVerified = false,
    this.profilePhotoUrl,
    this.autoAcceptColleagues = false,
    this.autoAcceptMaxDetourM = 100,
    this.trustScore = 50,
    this.emergencyContacts = const [],
    this.fcmToken,
    this.fcmTokenPlatform,
    this.fcmTokenUpdatedAt,
    this.isBanned = false,
    this.banReason,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? json['phone']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'prefer_not_to_say',
      role: json['role']?.toString() ?? json['user_type']?.toString() ?? 'corporate_employee',
      workEmail: json['work_email']?.toString() ?? json['email']?.toString(),
      workEmailVerified: json['work_email_verified'] ?? json['is_email_verified'] ?? false,
      officeIdPhotoUrl: json['office_id_photo_url']?.toString(),
      officeIdVerified: json['office_id_verified'] ?? json['is_document_verified'] ?? false,
      companyId: json['company_id']?.toString(),
      buildingId: json['building_id']?.toString(),
      primaryAccountId: json['primary_account_id']?.toString(),
      aadhaarVerified: json['aadhaar_verified'] ?? false,
      aadhaarMaskedNumber: json['aadhaar_masked_number']?.toString(),
      dlVerified: json['dl_verified'] ?? json['is_driver_verified'] ?? false,
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      autoAcceptColleagues: json['auto_accept_colleagues'] ?? false,
      autoAcceptMaxDetourM: (json['auto_accept_max_detour_m'] as num?)?.toInt() ?? 100,
      trustScore: (json['trust_score'] as num?)?.toInt() ?? 50,
      emergencyContacts: json['emergency_contacts'] is List ? json['emergency_contacts'] : [],
      fcmToken: json['fcm_token']?.toString(),
      fcmTokenPlatform: json['fcm_token_platform']?.toString(),
      fcmTokenUpdatedAt: json['fcm_token_updated_at'] != null ? DateTime.tryParse(json['fcm_token_updated_at'].toString()) : null,
      isBanned: json['is_banned'] ?? false,
      banReason: json['ban_reason']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'gender': gender,
      'role': role,
      'work_email': workEmail,
      'work_email_verified': workEmailVerified,
      'office_id_photo_url': officeIdPhotoUrl,
      'office_id_verified': officeIdVerified,
      'company_id': companyId,
      'building_id': buildingId,
      'primary_account_id': primaryAccountId,
      'aadhaar_verified': aadhaarVerified,
      'aadhaar_masked_number': aadhaarMaskedNumber,
      'dl_verified': dlVerified,
      'profile_photo_url': profilePhotoUrl,
      'auto_accept_colleagues': autoAcceptColleagues,
      'auto_accept_max_detour_m': autoAcceptMaxDetourM,
      'trust_score': trustScore,
      'emergency_contacts': emergencyContacts,
      'fcm_token': fcmToken,
      'fcm_token_platform': fcmTokenPlatform,
      'fcm_token_updated_at': fcmTokenUpdatedAt?.toIso8601String(),
      'is_banned': isBanned,
      'ban_reason': banReason,
    };
  }
}
