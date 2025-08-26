// models/transaction_model.dart
class Transaction {
  final String id;
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String status;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      requestId: json['request_id'],
      fromUserId: json['from_user'],
      toUserId: json['to_user'],
      amount: json['amount'].toDouble(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'from_user': fromUserId,
      'to_user': toUserId,
      'amount': amount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}