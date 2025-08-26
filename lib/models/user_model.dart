// models/user_model.dart
class User {
  final String id;
  final String email;
  final String name;
  final double latitude;
  final double longitude;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}