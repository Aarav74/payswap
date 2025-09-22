import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/request_polling_service.dart';
import '../models/request_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isFirstLocation = true;
  late AnimationController _pulseController;
  late AnimationController _requestPulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _requestPulseAnimation;
  
  // Route data
  List<LatLng> _routePoints = [];
  bool _showRoute = false;
  String? _connectedRequestId;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _requestPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _requestPulseAnimation = Tween<double>(begin: 0.9, end: 1.3).animate(
      CurvedAnimation(parent: _requestPulseController, curve: Curves.easeInOut),
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
    _requestPulseController.dispose();
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

  Future<void> _showRouteToRequest(Request request) async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    if (locationService.latitude == 0 || locationService.longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to get your current location'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Calculating route...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      final routeData = await locationService.getRoute(
        locationService.latitude, 
        locationService.longitude,
        request.latitude, 
        request.longitude,
      );

      if (routeData['paths'] != null && routeData['paths'].isNotEmpty) {
        final path = routeData['paths'][0];
        final points = path['points'];
        
        // Decode the route points (assuming they're encoded polyline)
        List<LatLng> routePoints = _decodePolyline(points);
        
        setState(() {
          _routePoints = routePoints;
          _showRoute = true;
          _connectedRequestId = request.id;
        });

        // Fit map bounds to show both user and request location
        _fitMapToBounds([
          LatLng(locationService.latitude, locationService.longitude),
          LatLng(request.latitude, request.longitude),
        ]);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.directions, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Route displayed to ${request.userName}')),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showRoute = false;
                      _routePoints.clear();
                      _connectedRequestId = null;
                    });
                  },
                  child: Text('Clear', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to calculate route: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _fitMapToBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    // Add padding
    double latPadding = (maxLat - minLat) * 0.1;
    double lngPadding = (maxLng - minLng) * 0.1;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - latPadding, minLng - lngPadding),
          LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        padding: EdgeInsets.all(50),
      ),
    );
  }

  // Simple polyline decoder - you might need a more robust implementation
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    final pollingService = Provider.of<RequestPollingService>(context);
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
            // Show route polyline if available
            if (_showRoute && _routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                    pattern: StrokePattern.dashed(segments: [10.0, 5.0]),
                  ),
                ],
              ),
            // Request markers
            _buildRequestMarkers(pollingService),
            // User marker (on top)
            _buildUserMarker(locationService),
          ],
        ),
        _buildLocationInfoOverlay(locationService, theme),
        _buildMapControls(),
        _buildRequestsOverlay(pollingService),
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
                    Icons.my_location,
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

  Widget _buildRequestMarkers(RequestPollingService pollingService) {
    final requests = pollingService.requests;
    
    return MarkerLayer(
      markers: requests.map((request) {
        final isConnected = _connectedRequestId == request.id;
        final markerColor = request.type == 'cash' ? Colors.green : Colors.orange;
        
        return Marker(
          point: LatLng(request.latitude, request.longitude),
          width: 60,
          height: 80,
          child: GestureDetector(
            onTap: () => _showRequestDetails(request),
            child: AnimatedBuilder(
              animation: isConnected ? _requestPulseAnimation : _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnected ? _requestPulseAnimation.value : 1.0,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: markerColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '\$${request.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          request.type == 'cash' ? Icons.money : Icons.credit_card,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showRequestDetails(Request request) {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final distance = LocationService.calculateDistance(
      locationService.latitude,
      locationService.longitude,
      request.latitude,
      request.longitude,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: request.type == 'cash' ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      request.type == 'cash' ? Icons.money : Icons.credit_card,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.userName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Needs ${request.type == 'cash' ? 'Cash' : 'Online Payment'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${request.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: request.type == 'cash' ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                    SizedBox(width: 8),
                    Text(
                      '${distance.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Spacer(),
                    Text(
                      _formatDateTime(request.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRouteToRequest(request);
                      },
                      icon: Icon(Icons.directions),
                      label: Text('Show Route'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement connect/chat functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connect feature coming soon!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                      icon: Icon(Icons.message),
                      label: Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
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

  Widget _buildRequestsOverlay(RequestPollingService pollingService) {
    final requests = pollingService.requests;
    
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withOpacity(0.95),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      '${requests.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Nearby\nRequests',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
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
            if (_showRoute)
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _showRoute = false;
                    _routePoints.clear();
                    _connectedRequestId = null;
                  });
                },
                backgroundColor: Colors.red,
                mini: true,
                child: Icon(Icons.close, color: Colors.white),
              ),
            if (_showRoute) SizedBox(height: 8),
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