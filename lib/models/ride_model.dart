class RideModel {
  final String id;
  final String driverId;
  final String? vehicleId;
  final String fromAddress;
  final double fromLat;
  final double fromLng;
  final String toAddress;
  final double toLat;
  final double toLng;
  final String? buildingId;
  final List<Map<String, dynamic>> routePoints;
  final double distanceKm;
  final int estimatedDurationMins;
  final String departTime; // 'HH:MM:SS'
  final String approxReachTime;
  final DateTime? departDate;
  final int seatsOffered;
  final int seatsAvailable;
  final double fareCoins;
  final String timeType; // 'now', 'scheduled', 'recurring'
  final List<int> recurringDays; // 0=Sun, 1=Mon, ..., 6=Sat
  final DateTime? validUntil;
  final List<DateTime> completionDates;
  final List<DateTime> skipDates;
  final String rideStatus; // 'posted', 'started', 'driver_en_route', 'arrived_at_pickup', 'in_progress', 'completed', 'cancelled_by_driver', 'cancelled_by_user'
  final bool womenOnlyFlag;
  final String boardingDailyWord;
  final String? boardingBleUuid;
  final bool isOpenToPublic;
  final double? currentLat;
  final double? currentLng;
  final int currentRouteIndex;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? matchScore;

  RideModel({
    required this.id,
    required this.driverId,
    this.vehicleId,
    required this.fromAddress,
    required this.fromLat,
    required this.fromLng,
    required this.toAddress,
    required this.toLat,
    required this.toLng,
    this.buildingId,
    this.routePoints = const [],
    this.distanceKm = 0.0,
    this.estimatedDurationMins = 0,
    required this.departTime,
    this.approxReachTime = '00:00:00',
    this.departDate,
    required this.seatsOffered,
    required this.seatsAvailable,
    required this.fareCoins,
    required this.timeType,
    this.recurringDays = const [],
    this.validUntil,
    this.completionDates = const [],
    this.skipDates = const [],
    this.rideStatus = 'posted',
    this.womenOnlyFlag = false,
    this.boardingDailyWord = 'KARMA',
    this.boardingBleUuid,
    this.isOpenToPublic = true,
    this.currentLat,
    this.currentLng,
    this.currentRouteIndex = 0,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.matchScore,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    // Parse GeoJSON or LatLng points
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

    return RideModel(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString(),
      fromAddress: json['from_address']?.toString() ?? '',
      fromLat: parseLat(json['from_lat'], json['from_location']),
      fromLng: parseLng(json['from_lng'], json['from_location']),
      toAddress: json['to_address']?.toString() ?? '',
      toLat: parseLat(json['to_lat'], json['to_location']),
      toLng: parseLng(json['to_lng'], json['to_location']),
      buildingId: json['building_id']?.toString(),
      routePoints: json['route_points'] is List ? List<Map<String, dynamic>>.from(json['route_points']) : [],
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMins: (json['estimated_duration_mins'] as num?)?.toInt() ?? 0,
      departTime: json['depart_time']?.toString() ?? '08:00:00',
      approxReachTime: json['approx_reach_time']?.toString() ?? '09:00:00',
      departDate: json['depart_date'] != null ? DateTime.tryParse(json['depart_date'].toString()) : null,
      seatsOffered: (json['seats_offered'] as num?)?.toInt() ?? (json['total_seats'] as num?)?.toInt() ?? 3,
      seatsAvailable: (json['seats_available'] as num?)?.toInt() ?? (json['available_seats'] as num?)?.toInt() ?? 3,
      fareCoins: (json['fare_coins'] as num?)?.toDouble() ?? (json['coin_per_seat'] as num?)?.toDouble() ?? 10.0,
      timeType: json['time_type']?.toString() ?? 'now',
      recurringDays: json['recurring_days'] is List ? List<int>.from(json['recurring_days']) : [],
      validUntil: json['valid_until'] != null ? DateTime.tryParse(json['valid_until'].toString()) : null,
      rideStatus: json['ride_status']?.toString() ?? 'posted',
      womenOnlyFlag: json['women_only_flag'] ?? false,
      boardingDailyWord: json['boarding_daily_word']?.toString() ?? 'KARMA',
      boardingBleUuid: json['boarding_ble_uuid']?.toString(),
      isOpenToPublic: json['is_open_to_public'] ?? true,
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      currentRouteIndex: (json['current_route_index'] as num?)?.toInt() ?? 0,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      matchScore: json['_match_score'] != null ? (json['_match_score'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'from_address': fromAddress,
      'to_address': toAddress,
      'building_id': buildingId,
      'route_points': routePoints,
      'distance_km': distanceKm,
      'estimated_duration_mins': estimatedDurationMins,
      'depart_time': departTime,
      'approx_reach_time': approxReachTime,
      'depart_date': departDate?.toIso8601String().split('T').first,
      'seats_offered': seatsOffered,
      'seats_available': seatsAvailable,
      'fare_coins': fareCoins,
      'time_type': timeType,
      'recurring_days': recurringDays,
      'valid_until': validUntil?.toIso8601String().split('T').first,
      'ride_status': rideStatus,
      'women_only_flag': womenOnlyFlag,
      'boarding_daily_word': boardingDailyWord,
      'boarding_ble_uuid': boardingBleUuid,
      'is_open_to_public': isOpenToPublic,
    };
  }
}
