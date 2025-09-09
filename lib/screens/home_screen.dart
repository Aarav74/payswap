// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:payswap/services/request_polling_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'map_screen.dart';
import 'request_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [MapScreen(), RequestScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    // Initialize services when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final locationService = Provider.of<LocationService>(
        context,
        listen: false,
      );
      final pollingService = Provider.of<RequestPollingService>( // FIX: Define pollingService variable
        context,
        listen: false,
      );

      // Get current location
      try {
        await locationService.getCurrentLocation();
      } catch (e) {
        debugPrint('Location error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location error: ${e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Start polling
      await _startPolling();

      // Listen for polling state changes
      pollingService.addListener(_handlePollingStateChange); // FIX: Now pollingService is defined
    });
  }

  Future<void> _startPolling() async {
    try {
      final pollingService = Provider.of<RequestPollingService>(
        context,
        listen: false,
      );

      // Check if server is available first
      final isAvailable = await pollingService.isServerAvailable();
      if (!isAvailable) {
        throw Exception(
          'Server is not available. Please check your internet connection.',
        );
      }

      await pollingService.startPolling();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to updates'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Polling error: $e');
      if (mounted) {
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _startPolling,
            ),
          ),
        );
      }
    }
  }

  void _handlePollingStateChange() {
    if (!mounted) return;

    final pollingService = Provider.of<RequestPollingService>(
      context,
      listen: false,
    );
    
    // Show connection status to user
    if (pollingService.isPolling) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to updates'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    final pollingService = Provider.of<RequestPollingService>(
      context,
      listen: false,
    );
    pollingService.removeListener(_handlePollingStateChange);
    pollingService.stopPolling();

    final locationService = Provider.of<LocationService>(
      context,
      listen: false,
    );
    locationService.stopLiveTracking();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final locationService = Provider.of<LocationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('PaySwap'),
        actions: [
          if (_currentIndex == 0) _buildLocationStatusIcon(locationService),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              authService.logout();
            },
          ),
        ],
      ),
      body: _buildBody(authService, locationService),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Requests',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildLocationStatusIcon(LocationService locationService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Icon(
        locationService.isTracking ? Icons.location_on : Icons.location_off,
        color: locationService.isTracking ? Colors.green : Colors.grey,
      ),
    );
  }

  Widget _buildBody(AuthService authService, LocationService locationService) {
    if (authService.error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Authentication Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(authService.error, textAlign: TextAlign.center),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Reset the auth service by signing out and then reinitializing
                final auth = Provider.of<AuthService>(context, listen: false);
                try {
                  await auth.logout();
                  // The auth service will automatically reinitialize itself
                } catch (e) {
                  // Handle any errors during logout
                }
              },
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (locationService.error.isNotEmpty && _currentIndex == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, color: Colors.orange, size: 48),
            SizedBox(height: 16),
            Text(
              'Location Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(locationService.error, textAlign: TextAlign.center),
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
      );
    }

    if (locationService.isLoading && _currentIndex == 0) {
      return Center(child: CircularProgressIndicator());
    }

    return _screens[_currentIndex];
  }
}