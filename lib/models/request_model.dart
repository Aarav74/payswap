// models/request_model.dart
class Request {
  final String id;
  final String userId;
  final String userName;
  final double amount;
  final String type; // 'Need Cash' or 'Need Online Payment'
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'completed'

  Request({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.status,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    // Handle nested user object from Supabase
    final userData = json['user'] is Map ? json['user'] : {};
    
    return Request(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? userData['id']?.toString() ?? '',
      userName: (json['user_name'] ?? userData['full_name'] ?? 'Unknown User') as String,
      amount: (json['amount'] is num ? json['amount'].toDouble() : 0.0) as double,
      type: (json['type'] ?? 'Need Cash') as String,
      latitude: (json['latitude'] is num ? json['latitude'].toDouble() : 0.0) as double,
      longitude: (json['longitude'] is num ? json['longitude'].toDouble() : 0.0) as double,
      createdAt: json['created_at'] is String 
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now() 
          : DateTime.now(),
      status: (json['status'] ?? 'pending') as String,
    );
  }

  Null get distance => null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'amount': amount,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}