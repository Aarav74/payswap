// screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
// Error widget import removed

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _isFirstLocation = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    // Start live location tracking
    await locationService.startLiveTracking();
    
    // Also update server with initial location
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.updateUserLocation(
        locationService.latitude,
        locationService.longitude,
      );
    } catch (e) {
      print('Failed to update server location: $e');
    }
  }

  @override
  void dispose() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    locationService.stopLiveTracking();
    super.dispose();
  }

  void _centerMapOnUser() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    _mapController.move(
      LatLng(locationService.latitude, locationService.longitude),
      _mapController.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    
    // Center map on user when location updates
    if (_isFirstLocation && locationService.latitude != 0 && locationService.longitude != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(locationService.latitude, locationService.longitude),
          15.0, // Zoom level
        );
        _isFirstLocation = false;
      });
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(locationService.latitude, locationService.longitude),
            initialZoom: 15.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            onPositionChanged: (position, hasGesture) {
              // Handle map movement
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.cash_exchange_app',
            ),
            _buildUserMarker(locationService),
            _buildCurrentLocationButton(),
          ],
        ),
        _buildLocationInfoOverlay(locationService),
        if (locationService.isLoading) _buildLoadingOverlay(),
        if (locationService.error.isNotEmpty) _buildErrorWidget(locationService),
      ],
    );
  }

  Widget _buildUserMarker(LocationService locationService) {
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(locationService.latitude, locationService.longitude),
          width: 40,
          height: 40,
          child: Icon(
            Icons.location_pin,
            color: Colors.red,
            size: 40,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentLocationButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton(
          onPressed: _centerMapOnUser,
          child: Icon(Icons.my_location),
          backgroundColor: Colors.blue,
          mini: true,
        ),
      ),
    );
  }

  Widget _buildLocationInfoOverlay(LocationService locationService) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: Colors.white.withOpacity(0.9),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Your Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Lat: ${locationService.latitude.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  'Lng: ${locationService.longitude.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12),
                ),
                if (locationService.address.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    locationService.address,
                    style: TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: locationService.isTracking ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 4),
                    Text(
                      locationService.isTracking ? 'Live tracking' : 'Tracking off',
                      style: TextStyle(
                        fontSize: 12,
                        color: locationService.isTracking ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorWidget(LocationService locationService) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text(
              'Location Error',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              locationService.error,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                locationService.getCurrentLocation();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}