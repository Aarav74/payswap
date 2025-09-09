// screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isFirstLocation = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
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
      // Silent error handling for location updates
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    final theme = Theme.of(context);
    
    // Center map on user when location updates
    if (_isFirstLocation && locationService.latitude != 0 && locationService.longitude != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(locationService.latitude, locationService.longitude),
          15.0,
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
            onPositionChanged: (position, hasGesture) {},
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.cash_exchange_app',
            ),
            _buildUserMarker(locationService),
          ],
        ),
        _buildLocationInfoOverlay(locationService, theme),
        _buildMapControls(),
        if (locationService.isLoading) _buildLoadingOverlay(),
        if (locationService.error.isNotEmpty) _buildErrorWidget(locationService, theme),
      ],
    );
  }

  Widget _buildUserMarker(LocationService locationService) {
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(locationService.latitude, locationService.longitude),
          width: 50,
          height: 50,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_pin,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfoOverlay(LocationService locationService, ThemeData theme) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withOpacity(0.95),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 20, color: theme.primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Your Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildInfoRow('Latitude', locationService.latitude.toStringAsFixed(6)),
                _buildInfoRow('Longitude', locationService.longitude.toStringAsFixed(6)),
                if (locationService.address.isNotEmpty) ...[
                  SizedBox(height: 8),
                  _buildInfoRow('Address', locationService.address, maxLines: 2),
                ],
                SizedBox(height: 12),
                _buildStatusIndicator(locationService),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(LocationService locationService) {
    return Row(
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: locationService.isTracking ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(
          locationService.isTracking ? 'Live tracking active' : 'Tracking paused',
          style: TextStyle(
            fontSize: 12,
            color: locationService.isTracking ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              onPressed: _zoomIn,
              backgroundColor: Colors.white,
              mini: true,
              child: Icon(Icons.add, color: Colors.blue),
            ),
            SizedBox(height: 8),
            FloatingActionButton(
              onPressed: _zoomOut,
              backgroundColor: Colors.white,
              mini: true,
              child: Icon(Icons.remove, color: Colors.blue),
            ),
            SizedBox(height: 16),
            FloatingActionButton(
              onPressed: _centerMapOnUser,
              backgroundColor: Colors.blue,
              child: Icon(Icons.my_location, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
            SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(LocationService locationService, ThemeData theme) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'Location Service',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  locationService.error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Dismiss'),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        locationService.getCurrentLocation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                      ),
                      child: Text('Retry'),
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
}