// services/api_service.dart
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/request_model.dart';
import '../models/user_model.dart' as local_models;
import '../models/transaction_model.dart';
import 'auth_service.dart';

class ApiService with ChangeNotifier {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  final AuthService authService;
  final Function()? onLocationRequired;

  ApiService({required this.authService, this.onLocationRequired});

  Future<String?> _getAuthToken() async {
    try {
      final token = await authService.getToken();
      if (token == null) {
        debugPrint('No authentication token available');
        return null;
      }
      return token;
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }

  Future<local_models.User?> getCurrentUser() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated - no token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return local_models.User.fromJson(responseData);
      } else {
        throw Exception('Failed to load user data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getCurrentUser: $e');
      rethrow;
    }
  }

  Future<bool> updateUserLocation(double latitude, double longitude) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('Cannot update location: No auth token');
        return false;
      }

      debugPrint('Updating user location to: $latitude, $longitude');

      final response = await http.post(
        Uri.parse('$baseUrl/user/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(Duration(seconds: 15));

      debugPrint('Location update response: ${response.statusCode}');
      debugPrint('Location update body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Failed to update location: ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      debugPrint('Location update timeout');
      return false;
    } catch (e) {
      debugPrint('Error in updateUserLocation: $e');
      return false;
    }
  }

  // Create a new request using FastAPI backend
  Future<Request?> createRequest({
    required double amount,
    required String type,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validate inputs first
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      if (type.isEmpty) {
        throw Exception('Request type is required');
      }
      if (latitude == 0.0 || longitude == 0.0) {
        throw Exception('Invalid location coordinates');
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Please login to create a request');
      }

      debugPrint('Creating request with: amount=$amount, type=$type');
      debugPrint('Using location: $latitude, $longitude');

      // First update the user's location with timeout
      debugPrint('Updating user location before creating request...');
      try {
        final locationUpdated = await updateUserLocation(latitude, longitude)
            .timeout(Duration(seconds: 10));
        
        if (!locationUpdated) {
          throw Exception('Failed to update location in the server');
        }
        
        // Small delay to ensure location is updated in database
        await Future.delayed(Duration(milliseconds: 500));
      } on TimeoutException {
        debugPrint('Location update timed out');
        throw Exception('Location update timed out. Please try again.');
      } catch (e) {
        debugPrint('Location update error: $e');
        throw Exception('Failed to update your location. Please try again.');
      }

      // Now create the request with timeout
      debugPrint('Sending create request to server...');
      final completer = Completer<http.Response>();
      final timer = Timer(Duration(seconds: 20), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Create request timed out after 20 seconds'));
        }
      });
      
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/requests'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'amount': amount,
            'type': type,
            'latitude': latitude,
            'longitude': longitude,
          }),
        );
        timer.cancel();
        completer.complete(response);
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
      
      final response = await completer.future;

      debugPrint('Create request response status: ${response.statusCode}');
      debugPrint('Create request response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final createdRequest = Request.fromJson(responseData);
        notifyListeners();
        return createdRequest;
      } else {
        // Parse error response
        String errorMessage = 'Failed to create request';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? errorData['message'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
          errorMessage = 'Server error (${response.statusCode}). Please try again.';
        }
        throw Exception('$errorMessage (Status: ${response.statusCode})');
      }
    } on TimeoutException {
      debugPrint('Create request timed out');
      throw Exception('Request timed out. Please check your connection and try again.');
    } on http.ClientException catch (e) {
      debugPrint('Network error in createRequest: $e');
      throw Exception('Network error. Please check your internet connection.');
    } catch (e) {
      debugPrint('Error in createRequest: $e');
      rethrow;
    }
  }

  // Get nearby requests using FastAPI backend
  Future<List<Request>> getNearbyRequests({double radius = 5.0}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Please login to view requests');
      }

      final completer = Completer<http.Response>();
      final timer = Timer(Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Get nearby requests timed out after 15 seconds'));
        }
      });
      
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/requests/nearby?radius=$radius'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        timer.cancel();
        completer.complete(response);
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
      
      final response = await completer.future;

      debugPrint('Get nearby requests response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Request.fromJson(json)).toList();
      } else if (response.statusCode == 400) {
        // Handle location not set error
        try {
          final errorData = json.decode(response.body);
          if (errorData['detail'] != null && errorData['detail'].contains('location not set')) {
            // Call onLocationRequired callback if provided
            if (onLocationRequired != null) {
              onLocationRequired!();
            }
            throw Exception('Please enable location services and update your location');
          }
        } catch (e) {
          if (e.toString().contains('Please enable location')) rethrow;
        }
        throw Exception('Failed to load requests: ${response.statusCode}');
      } else {
        throw Exception('Failed to load requests: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('Get nearby requests timed out');
      throw Exception('Request timed out. Please check your connection.');
    } on http.ClientException catch (e) {
      debugPrint('Network error in getNearbyRequests: $e');
      throw Exception('Network error. Please check your internet connection.');
    } catch (e) {
      debugPrint('Error in getNearbyRequests: $e');
      if (e.toString().contains('Please enable location') || 
          e.toString().contains('Please login')) {
        rethrow;
      }
      return [];
    }
  }

  // Accept a request
  Future<bool> acceptRequest(String requestId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('Cannot accept request: No auth token');
        return false;
      }

      final completer = Completer<http.Response>();
      final timer = Timer(Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Accept request timed out after 10 seconds'));
        }
      });
      
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/requests/$requestId/accept'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        timer.cancel();
        completer.complete(response);
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
      
      final response = await completer.future;

      debugPrint('Accept request response: ${response.statusCode}');

      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else {
        debugPrint('Failed to accept request: ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      debugPrint('Accept request timed out');
      return false;
    } catch (e) {
      debugPrint('Error in acceptRequest: $e');
      return false;
    }
  }

  // Mark a request as completed
  Future<bool> completeRequest(String requestId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('Cannot complete request: No auth token');
        return false;
      }

      final completer = Completer<http.Response>();
      final timer = Timer(Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Complete request timed out after 10 seconds'));
        }
      });
      
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/requests/$requestId/complete'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        timer.cancel();
        completer.complete(response);
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
      
      final response = await completer.future;

      debugPrint('Complete request response: ${response.statusCode}');

      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else {
        debugPrint('Failed to complete request: ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      debugPrint('Complete request timed out');
      return false;
    } catch (e) {
      debugPrint('Error in completeRequest: $e');
      return false;
    }
  }

  // Get transaction history
  Future<List<Transaction>> getTransactionHistory() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Please login to view transaction history');
      }

      final completer = Completer<http.Response>();
      final timer = Timer(Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Get transaction history timed out after 15 seconds'));
        }
      });
      
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/transactions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        timer.cancel();
        completer.complete(response);
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
      
      final response = await completer.future;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Transaction.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load transaction history: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('Get transaction history timed out');
      throw Exception('Request timed out. Please check your connection.');
    } catch (e) {
      debugPrint('Error in getTransactionHistory: $e');
      return [];
    }
  }

  // Get route information
  Future<Map<String, dynamic>?> getRoute(double startLat, double startLng, double endLat, double endLng) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('Cannot get route: No auth token');
        return null;
      }

      final completer = Completer<http.Response>();
      final timer = Timer(Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Get route timed out after 15 seconds'));
        }
      });
      
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/route?start_lat=$startLat&start_lng=$startLng&end_lat=$endLat&end_lng=$endLng'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        timer.cancel();
        completer.complete(response);
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
      
      final response = await completer.future;

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to get route: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      debugPrint('Get route timed out');
      return null;
    } catch (e) {
      debugPrint('Error in getRoute: $e');
      return null;
    }
  }

  // Helper method to calculate distance between two coordinates
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - 
        cos((lat2 - lat1) * p) / 2 + 
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
}