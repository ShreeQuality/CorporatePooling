class WalletModel {
  final String id;
  final String userId;
  final double availableBalance;
  final double lockedBalance;
  final double corporateGrantBalance;
  final double lifetimeEarned;
  final double lifetimeSpent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WalletModel({
    required this.id,
    required this.userId,
    this.availableBalance = 0.0,
    this.lockedBalance = 0.0,
    this.corporateGrantBalance = 0.0,
    this.lifetimeEarned = 0.0,
    this.lifetimeSpent = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0.0,
      lockedBalance: (json['locked_balance'] as num?)?.toDouble() ?? 0.0,
      corporateGrantBalance: (json['corporate_grant_balance'] as num?)?.toDouble() ?? 0.0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.toDouble() ?? 0.0,
      lifetimeSpent: (json['lifetime_spent'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  double get totalSpendableBalance => availableBalance + corporateGrantBalance;
}

class CoinTransactionModel {
  final String id;
  final String? senderId;
  final String? receiverId;
  final double amount;
  final String transactionType; // 'ride_earning', 'ride_fare', 'escrow_lock', 'escrow_refund', 'corporate_grant', 'late_cancel_fee', etc.
  final String? rideId;
  final String? requestId;
  final String? idempotencyKey;
  final String status;
  final DateTime createdAt;

  CoinTransactionModel({
    required this.id,
    this.senderId,
    this.receiverId,
    required this.amount,
    required this.transactionType,
    this.rideId,
    this.requestId,
    this.idempotencyKey,
    this.status = 'completed',
    required this.createdAt,
  });

  factory CoinTransactionModel.fromJson(Map<String, dynamic> json) {
    return CoinTransactionModel(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString(),
      receiverId: json['receiver_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      transactionType: json['transaction_type']?.toString() ?? 'ride_fare',
      rideId: json['ride_id']?.toString(),
      requestId: json['request_id']?.toString(),
      idempotencyKey: json['idempotency_key']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }
}
