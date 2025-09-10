// screens/home_screen.dart (Updated with new logo)
import 'package:flutter/material.dart';
import 'package:payswap/services/request_polling_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../widgets/animated_logo.dart'; // Import the new logo widget
import 'map_screen.dart';
import 'request_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _statusAnimationController;
  late AnimationController _logoSpinController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _logoSpinAnimation;
  
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _logoSpinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _statusAnimationController, curve: Curves.easeInOut),
    );
    
    _logoSpinAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoSpinController, curve: Curves.elasticOut),
    );
    
    // Initialize screens
    _screens = [
      MapScreen(),
      RequestScreen(),
      ProfileScreen(),
    ];
    
    // Initialize services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }
  
  void _initializeScreens() {
    if (mounted) {
      setState(() {
        _screens = [
          MapScreen(),
          RequestScreen(),
          ProfileScreen(),
        ];
      });
    }
  }

  Future<void> _initializeServices() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final pollingService = Provider.of<RequestPollingService>(context, listen: false);

    // Show loading indicator
    _showStatusSnackBar(
      'Initializing services...',
      Colors.blue,
      isLoading: true,
    );

    try {
      // Get current location first
      await locationService.getCurrentLocation();
      
      // Start polling
      await _startPolling();

      // Listen for polling state changes
      pollingService.addListener(_handlePollingStateChange);
      
      _showStatusSnackBar('Connected successfully!', Colors.green);
      
    } catch (e) {
      debugPrint('Initialization error: $e');
      _showStatusSnackBar(
        'Initialization failed: ${e.toString()}',
        Colors.orange,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _initializeServices,
        ),
      );
    }
  }

  Future<void> _startPolling() async {
    try {
      final pollingService = Provider.of<RequestPollingService>(context, listen: false);

      // Check if server is available first
      final isAvailable = await pollingService.isServerAvailable();
      if (!isAvailable) {
        throw Exception('Server is not available. Please check your internet connection.');
      }

      await pollingService.startPolling();
      
    } catch (e) {
      debugPrint('Polling error: $e');
      rethrow;
    }
  }

  void _handlePollingStateChange() {
    if (!mounted) return;

    final pollingService = Provider.of<RequestPollingService>(context, listen: false);
    
    if (pollingService.isPolling) {
      _showStatusSnackBar('Connected to live updates', Colors.green);
    } else if (pollingService.error != null) {
      _showStatusSnackBar(
        'Connection lost: ${pollingService.error}',
        Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _startPolling(),
        ),
      );
    }
  }

  void _showStatusSnackBar(String message, Color color, {SnackBarAction? action, bool isLoading = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                color == Colors.green ? Icons.check_circle : 
                color == Colors.red ? Icons.error : Icons.info,
                color: Colors.white,
                size: 20,
              ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: action != null ? 5 : 3),
        action: action,
      ),
    );
  }

  void _onLogoTap() {
    // Trigger logo animation
    _logoSpinController.forward().then((_) {
      _logoSpinController.reset();
    });
    
    // Show fun message
    _showStatusSnackBar(
      'PaySwap - Making money exchange easier!',
      Colors.blue.shade600,
    );
  }

  @override
  void dispose() {
    _statusAnimationController.dispose();
    _logoSpinController.dispose();
    final pollingService = Provider.of<RequestPollingService>(context, listen: false);
    pollingService.removeListener(_handlePollingStateChange);
    pollingService.stopPolling();

    final locationService = Provider.of<LocationService>(context, listen: false);
    locationService.stopLiveTracking();

    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final locationService = Provider.of<LocationService>(context);
    final pollingService = Provider.of<RequestPollingService>(context);

    // Show error screens if needed
    if (authService.error.isNotEmpty) {
      return _buildErrorScreen(
        icon: Icons.error_outline,
        title: 'Authentication Error',
        message: authService.error,
        buttonText: 'Retry Login',
        onPressed: () {
          final auth = Provider.of<AuthService>(context, listen: false);
          auth.logout();
        },
      );
    }

    if (locationService.error.isNotEmpty && _currentIndex == 0) {
      return _buildErrorScreen(
        icon: Icons.location_off,
        title: 'Location Error',
        message: locationService.error,
        buttonText: 'Enable Location',
        onPressed: () {
          final location = Provider.of<LocationService>(context, listen: false);
          location.getCurrentLocation();
        },
      );
    }

    if (locationService.isLoading && _currentIndex == 0) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedPaySwapLogo(
                size: 100,
                primaryColor: Theme.of(context).primaryColor,
                enableTapAnimation: false,
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Getting your location...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(authService, locationService, pollingService),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthService authService, LocationService locationService, RequestPollingService pollingService) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          // Use the new animated logo
          AnimatedBuilder(
            animation: _logoSpinAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _logoSpinAnimation.value * 2 * 3.14159,
                child: AnimatedPaySwapLogo(
                  size: 32,
                  primaryColor: Colors.white,
                  secondaryColor: Theme.of(context).primaryColor,
                  onTap: _onLogoTap,
                ),
              );
            },
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PaySwap',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Money Exchange',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_currentIndex == 0) _buildLocationStatusIcon(locationService),
        _buildConnectionStatusIcon(pollingService),
        _buildProfileButton(authService),
      ],
    );
  }

  Widget _buildLocationStatusIcon(LocationService locationService) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            children: [
              Icon(
                locationService.isTracking ? Icons.location_on : Icons.location_off,
                color: locationService.isTracking ? Colors.white : Colors.white54,
                size: 24,
              ),
              if (locationService.isTracking)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatusIcon(RequestPollingService pollingService) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            children: [
              Icon(
                Icons.wifi,
                color: pollingService.isPolling ? Colors.white : Colors.white54,
                size: 24,
              ),
              if (pollingService.isPolling)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileButton(AuthService authService) {
    return Padding(
      padding: EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildQuickActionsSheet(authService),
          );
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSheet(AuthService authService) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Add logo to the sheet header
                AnimatedPaySwapLogo(
                  size: 60,
                  primaryColor: Theme.of(context).primaryColor,
                  onTap: _onLogoTap,
                ),
                SizedBox(height: 16),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.person, color: Theme.of(context).primaryColor),
                  title: Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(2);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.map, color: Theme.of(context).primaryColor),
                  title: Text('Map View'),
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(0);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.request_page, color: Theme.of(context).primaryColor),
                  title: Text('Requests'),
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(1);
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(authService);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            AnimatedPaySwapLogo(
              size: 32,
              primaryColor: Theme.of(context).primaryColor,
            ),
            SizedBox(width: 12),
            Text('Confirm Logout'),
          ],
        ),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authService.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.map_outlined, Icons.map, 'Map'),
              _buildNavItem(1, Icons.request_page_outlined, Icons.request_page, 'Requests'),
              _buildNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                size: 24,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildErrorScreen({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(Icons.refresh),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
