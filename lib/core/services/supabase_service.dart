import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';
import '../../models/user_model.dart';
import '../../models/ride_model.dart';
import '../../models/ride_request_model.dart';
import '../../models/vehicle_model.dart';
import '../../models/wallet_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    _isInitialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;

  // ─── USER & AUTH ────────────────────────────────────────────────────────────
  Future<UserModel?> getUserProfile(String userId) async {
    final res = await client.from('users').select().eq('id', userId).maybeSingle();
    if (res == null) return null;
    return UserModel.fromJson(res);
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await client.from('users').update(updates).eq('id', userId);
  }

  // ─── VEHICLES ───────────────────────────────────────────────────────────────
  Future<List<VehicleModel>> getUserVehicles(String userId) async {
    final res = await client.from('vehicles').select().eq('user_id', userId).eq('is_active', true);
    return (res as List).map((e) => VehicleModel.fromJson(e)).toList();
  }

  Future<VehicleModel> registerVehicle(VehicleModel vehicle) async {
    final res = await client.from('vehicles').insert(vehicle.toJson()).select().single();
    return VehicleModel.fromJson(res);
  }

  // ─── WALLET & COINS ─────────────────────────────────────────────────────────
  Future<WalletModel?> getUserWallet(String userId) async {
    final res = await client.from('wallets').select().eq('user_id', userId).maybeSingle();
    if (res == null) return null;
    return WalletModel.fromJson(res);
  }

  Future<List<CoinTransactionModel>> getTransactionHistory(String userId) async {
    final res = await client
        .from('coin_transactions')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).map((e) => CoinTransactionModel.fromJson(e)).toList();
  }

  // ─── RIDES ──────────────────────────────────────────────────────────────────
  Future<List<RideModel>> searchAvailableRides({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    String timeType = 'now',
  }) async {
    // PostGIS Spatial query on posted rides
    final res = await client
        .from('rides')
        .select()
        .eq('ride_status', 'posted')
        .gt('seats_available', 0)
        .order('created_at', ascending: false)
        .limit(30);

    return (res as List).map((e) => RideModel.fromJson(e)).toList();
  }

  Future<RideModel> postRide(RideModel ride) async {
    final payload = ride.toJson();
    // PostGIS geometry formatting for Points
    payload['from_location'] = 'POINT(${ride.fromLng} ${ride.fromLat})';
    payload['to_location'] = 'POINT(${ride.toLng} ${ride.toLat})';
    payload['route_geometry'] = 'LINESTRING(${ride.fromLng} ${ride.fromLat}, ${ride.toLng} ${ride.toLat})';

    final res = await client.from('rides').insert(payload).select().single();
    return RideModel.fromJson(res);
  }

  // ─── RIDE REQUESTS ──────────────────────────────────────────────────────────
  Future<RideRequestModel> sendRideRequest(RideRequestModel request) async {
    final payload = request.toJson();
    payload['pickup_location'] = 'POINT(${request.pickupLng} ${request.pickupLat})';
    payload['drop_location'] = 'POINT(${request.dropLng} ${request.dropLat})';

    final res = await client.from('ride_requests').insert(payload).select().single();
    return RideRequestModel.fromJson(res);
  }

  Future<void> acceptRideRequest(String requestId) async {
    await client.from('ride_requests').update({
      'status': 'accepted',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  // ─── REALTIME CHANNELS ──────────────────────────────────────────────────────
  RealtimeChannel subscribeToDriverLocation(String rideId, Function(Map<String, dynamic>) onLocationUpdate) {
    final channelName = 'driver_location_$rideId';
    return client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onLocationUpdate(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToRideRequests(String rideId, Function(Map<String, dynamic>) onRequest) {
    final channelName = 'ride_requests_$rideId';
    return client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onRequest(payload.newRecord);
            }
          },
        )
        .subscribe();
  }
}
