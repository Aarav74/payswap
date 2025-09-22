import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config/env.dart';

class LocationService with ChangeNotifier {
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isLoading = false;
  String _error = '';
  String _address = '';
  Stream<Position>? _positionStream;
  bool _isTracking = false;

  double get latitude => _latitude;
  double get longitude => _longitude;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get address => _address;
  bool get isTracking => _isTracking;

  // Calculate distance between two points using Haversine formula
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth radius in kilometers
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat/2) * sin(dLat/2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon/2) * sin(dLon/2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check and request permissions
      await _checkLocationPermissions();
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _latitude = position.latitude;
      _longitude = position.longitude;
      
      // Update address
      await _getAddressFromCoordinates(_latitude, _longitude);
      
      _isLoading = false;
      notifyListeners();
      
      return position;
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<void> startLiveTracking() async {
    try {
      // Check and request permissions
      await _checkLocationPermissions();

      _isTracking = true;
      notifyListeners();

      // Start listening to location updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      );

      _positionStream?.listen((Position position) {
        _updatePosition(position);
        
        // Optionally update server with new location
        _updateServerLocation(position);
      });

    } catch (e) {
      _error = 'Failed to start live tracking: $e';
      _isTracking = false;
      notifyListeners();
    }
  }

  void stopLiveTracking() {
    _isTracking = false;
    _positionStream = null;
    notifyListeners();
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
    }
  }

  void _updatePosition(Position position) {
    _latitude = position.latitude;
    _longitude = position.longitude;
    _error = '';
    
    // Get address for the new location
    _getAddressFromCoordinates(_latitude, _longitude);
    
    notifyListeners();
  }

  Future<void> _updateServerLocation(Position position) async {
    // This would typically call your API to update the user's location on the server
    // For now, we'll just print it
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse('https://graphhopper.com/api/1/geocode?'
            'point=$lat,$lng&'
            'reverse=true&'
            'key=${Env.graphhopperApiKey}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hits'] != null && data['hits'].isNotEmpty) {
          final hit = data['hits'][0];
          _address = hit['name'] ?? 'Unknown location';
          if (hit['city'] != null) {
            _address += ', ${hit['city']}';
          }
          if (hit['country'] != null) {
            _address += ', ${hit['country']}';
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting address: $e');
      }
      _address = 'Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> getRoute(double startLat, double startLng, 
                                      double endLat, double endLng) async {
    try {
      final response = await http.get(
        Uri.parse('https://graphhopper.com/api/1/route?'
            'point=$startLat,$startLng&'
            'point=$endLat,$endLng&'
            'vehicle=foot&'
            'key=${Env.graphhopperApiKey}'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting route: $e');
    }
  }
}