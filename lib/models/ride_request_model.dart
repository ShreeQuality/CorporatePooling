class RideRequestModel {
  final String id;
  final String rideId;
  final String riderId;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropAddress;
  final double dropLat;
  final double dropLng;
  final int seatsRequested;
  final double coinsLocked;
  final String? usedFamilyWalletId;
  final String status; // 'pending', 'accepted', 'rejected', 'cancelled', 'expired', 'in_ride', 'completed'
  final DateTime expiresAt;
  final bool driverArrived;
  final DateTime? driverArrivedAt;
  final DateTime? boardingVerifiedAt;
  final String? verificationMethodUsed; // 'ble', 'qr', 'pin'
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RideRequestModel({
    required this.id,
    required this.rideId,
    required this.riderId,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropAddress,
    required this.dropLat,
    required this.dropLng,
    this.seatsRequested = 1,
    required this.coinsLocked,
    this.usedFamilyWalletId,
    this.status = 'pending',
    required this.expiresAt,
    this.driverArrived = false,
    this.driverArrivedAt,
    this.boardingVerifiedAt,
    this.verificationMethodUsed,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory RideRequestModel.fromJson(Map<String, dynamic> json) {
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

    return RideRequestModel(
      id: json['id']?.toString() ?? '',
      rideId: json['ride_id']?.toString() ?? '',
      riderId: json['rider_id']?.toString() ?? '',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      pickupLat: parseLat(json['pickup_lat'], json['pickup_location']),
      pickupLng: parseLng(json['pickup_lng'], json['pickup_location']),
      dropAddress: json['drop_address']?.toString() ?? '',
      dropLat: parseLat(json['drop_lat'], json['drop_location']),
      dropLng: parseLng(json['drop_lng'], json['drop_location']),
      seatsRequested: (json['seats_requested'] as num?)?.toInt() ?? 1,
      coinsLocked: (json['coins_locked'] as num?)?.toDouble() ?? 0.0,
      usedFamilyWalletId: json['used_family_wallet_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'].toString()) : DateTime.now().add(const Duration(minutes: 5)),
      driverArrived: json['driver_arrived'] ?? false,
      driverArrivedAt: json['driver_arrived_at'] != null ? DateTime.tryParse(json['driver_arrived_at'].toString()) : null,
      boardingVerifiedAt: json['boarding_verified_at'] != null ? DateTime.tryParse(json['boarding_verified_at'].toString()) : null,
      verificationMethodUsed: json['verification_method_used']?.toString(),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'rider_id': riderId,
      'pickup_address': pickupAddress,
      'drop_address': dropAddress,
      'seats_requested': seatsRequested,
      'coins_locked': coinsLocked,
      'used_family_wallet_id': usedFamilyWalletId,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
