class VehicleModel {
  final String id;
  final String userId;
  final String vehicleType; // 'car', 'suv', 'bike', 'scooter', 'auto', 'ev'
  final String vehicleNumber;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? rcPhotoUrl;
  final bool hasSpareHelmet;
  final bool isVerified;
  final bool isActive;
  final DateTime? createdAt;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.vehicleNumber,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.rcPhotoUrl,
    this.hasSpareHelmet = false,
    this.isVerified = false,
    this.isActive = true,
    this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'car',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      vehicleMake: json['vehicle_make']?.toString(),
      vehicleModel: json['vehicle_model']?.toString(),
      vehicleColor: json['vehicle_color']?.toString(),
      rcPhotoUrl: json['rc_photo_url']?.toString(),
      hasSpareHelmet: json['has_spare_helmet'] ?? false,
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_color': vehicleColor,
      'rc_photo_url': rcPhotoUrl,
      'has_spare_helmet': hasSpareHelmet,
      'is_verified': isVerified,
      'is_active': isActive,
    };
  }

  bool get isTwoWheeler => vehicleType == 'bike' || vehicleType == 'scooter';
}
