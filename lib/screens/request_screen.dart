// screens/request_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/request_model.dart';
import '../services/request_polling_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../widgets/request_card.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  _RequestScreenState createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> with AutomaticKeepAliveClientMixin {
  final _amountController = TextEditingController();
  String _selectedType = 'Need Cash';
  bool _isLoading = false;
  String _error = '';
  bool _serverConnected = false;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    debugPrint('=== Initializing Request Screen ===');
    await _testServerConnection();
    await _startPolling();
  }

  Future<void> _testServerConnection() async {
    final pollingService = Provider.of<RequestPollingService>(context, listen: false);
    
    debugPrint('Testing server connectivity...');
    
    // Test multiple connection methods
    final connectivityResults = await pollingService.testConnectivity();
    
    bool isConnected = connectivityResults.values.any((result) => result == true);
    
    setState(() {
      _serverConnected = isConnected;
    });
    
    if (!isConnected && mounted) {
      _showConnectionError(connectivityResults);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Connected to server'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showConnectionError(Map<String, bool> results) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Connection Issue'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unable to connect to server properly.'),
              SizedBox(height: 16),
              Text('Connection Tests:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...results.entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      entry.value ? Icons.check_circle : Icons.cancel,
                      color: entry.value ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('${entry.key}: ${entry.value ? "OK" : "Failed"}'),
                  ],
                ),
              )),
              SizedBox(height: 16),
              Text(
                'Troubleshooting:\n'
                '• Check if server is running on port 8000\n'
                '• Verify network connection\n'
                '• For emulator use: 10.0.2.2:8000\n'
                '• For device use your computer\'s IP',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _testServerConnection();
              },
              child: Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Continue Anyway'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startPolling() async {
    final pollingService = Provider.of<RequestPollingService>(context, listen: false);
    
    debugPrint('Starting polling service...');
    
    try {
      await pollingService.startPolling(interval: Duration(seconds: 15));
      debugPrint('Polling started successfully');
    } catch (e) {
      debugPrint('Error starting polling: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Auto-refresh may not work properly'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _refreshRequests() async {
    final pollingService = Provider.of<RequestPollingService>(context, listen: false);
    await pollingService.refresh();
  }

  Future<void> _handleRefresh() async {
    await _refreshRequests();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Needed for AutomaticKeepAliveClientMixin
    
    final pollingService = Provider.of<RequestPollingService>(context);
    final locationService = Provider.of<LocationService>(context);
    final authService = Provider.of<AuthService>(context);
    
    final allRequests = pollingService.requests;
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Connection Status Banner
              if (!_serverConnected)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Limited connectivity - some features may not work',
                          style: TextStyle(color: Colors.orange[800], fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _testServerConnection,
                        child: Text('Retry', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              
              // Create Request Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle, color: Theme.of(context).primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Create Request',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor
                            ),
                          ),
                          Spacer(),
                          if (!_serverConnected)
                            Icon(Icons.warning, color: Colors.orange, size: 16),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixText: '\₹ ',
                          prefixIcon: Icon(Icons.attach_money),
                          hintText: 'Enter amount (e.g., 100)',
                        ),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        items: ['Need Cash', 'Need Online Payment']
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(
                                        type == 'Need Cash' 
                                            ? Icons.money 
                                            : Icons.credit_card,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(type),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value ?? 'Need Cash';
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Request Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.category),
                        ),
                      ),
                      SizedBox(height: 16),
                      if (_error.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error,
                                  style: TextStyle(color: Colors.red, fontSize: 14),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 16, color: Colors.red),
                                onPressed: () => setState(() => _error = ''),
                              ),
                            ],
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _createRequest(pollingService, locationService, authService),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading 
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Creating Request...'),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send),
                                  SizedBox(width: 8),
                                  Text('Create Request'),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Requests List Header
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Nearby Requests',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor
                        ),
                      ),
                      if (allRequests.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${allRequests.length}',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      SizedBox(width: 8),
                      if (pollingService.isPolling)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.autorenew, color: Colors.green, size: 12),
                              SizedBox(width: 2),
                              Text(
                                'Auto',
                                style: TextStyle(color: Colors.green, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      if (!_serverConnected)
                        Container(
                          margin: EdgeInsets.only(left: 4),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.signal_wifi_off, color: Colors.orange, size: 12),
                              SizedBox(width: 2),
                              Text(
                                'Offline',
                                style: TextStyle(color: Colors.orange, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      Spacer(),
                      if (pollingService.isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: pollingService.isLoading ? null : () async {
                          await _refreshRequests();
                          await _testServerConnection();
                        },
                        tooltip: 'Refresh requests',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              
              // Requests List
              Expanded(
                child: _buildRequestsList(pollingService, allRequests),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsList(RequestPollingService pollingService, List<Request> requests) {
    if (pollingService.isLoading && !pollingService.hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading nearby requests...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (pollingService.error != null && !pollingService.hasData) {
      return Center(
        child: Card(
          color: Colors.red.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error Loading Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  pollingService.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700]),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _refreshRequests,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _testServerConnection,
                      icon: Icon(Icons.settings_ethernet),
                      label: Text('Test Connection'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (requests.isEmpty) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Requests Nearby',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to create a request in your area!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14, 
                    color: Colors.grey[600]
                  ),
                ),
                SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _refreshRequests,
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: RequestCard(request: requests[index]),
        );
      },
    );
  }

  Future<void> _createRequest(RequestPollingService pollingService, LocationService locationService, AuthService authService) async {
    debugPrint('=== Starting _createRequest ===');
    
    // Clear previous error
    setState(() {
      _error = '';
    });
    
    // Validation checks
    if (authService.currentUser == null) {
      setState(() {
        _error = 'Please login to create a request';
      });
      return;
    }

    if (_amountController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter an amount';
      });
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Please enter a valid amount greater than 0';
      });
      return;
    }

    if (amount > 10000) {
      setState(() {
        _error = 'Amount cannot exceed ₹10,000';
      });
      return;
    }

    // Start loading
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      debugPrint('Getting current location...');
      
      // Show location loading message
      if (mounted) {
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
                Text('Getting your location...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      
      await locationService.getCurrentLocation().timeout(Duration(seconds: 15));
      
      if (locationService.latitude == null || locationService.longitude == null) {
        throw Exception('Could not get your current location. Please check your location settings and try again.');
      }

      debugPrint('Location obtained: ${locationService.latitude}, ${locationService.longitude}');

      // Map display type to API type
      String requestType = _selectedType == 'Need Cash' ? 'cash' : 'online';
      
      debugPrint('Creating request via polling service...');
      debugPrint('Request details: amount=$amount, type=$requestType');
      
      // Show creation loading message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                Text('Creating your request...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      
      final request = await pollingService.createRequest(
        amount: amount,
        type: requestType,
        latitude: locationService.latitude!,
        longitude: locationService.longitude!,
      ).timeout(Duration(seconds: 20));

      if (request != null) {
        // Success - clear form
        _amountController.clear();
        setState(() {
          _selectedType = 'Need Cash';
          _error = '';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request created successfully!',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '\${amount.toStringAsFixed(2)} - ${_selectedType}',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
        
        // Refresh the connection status
        await _testServerConnection();
        
      } else {
        throw Exception('Failed to create request - no response received from server');
      }
      
    } on TimeoutException catch (e) {
      debugPrint('Request creation timed out: $e');
      setState(() {
        _error = 'Request timed out. Please check your internet connection and try again.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
    } catch (e) {
      debugPrint('Error in _createRequest: $e');
      
      String errorMessage = e.toString();
      
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      // Categorize errors for better user experience
      if (errorMessage.toLowerCase().contains('location')) {
        errorMessage = 'Location error. Please enable location services and grant permission to this app.';
      } else if (errorMessage.toLowerCase().contains('authentication') || 
                 errorMessage.toLowerCase().contains('login') ||
                 errorMessage.toLowerCase().contains('not authenticated')) {
        errorMessage = 'Authentication error. Please log out and log back in.';
      } else if (errorMessage.toLowerCase().contains('network') || 
                 errorMessage.toLowerCase().contains('connection') ||
                 errorMessage.toLowerCase().contains('timeout') ||
                 errorMessage.toLowerCase().contains('server') ||
                 errorMessage.toLowerCase().contains('reach')) {
        errorMessage = 'Network error. Please check your internet connection and server status.';
      } else if (errorMessage.toLowerCase().contains('server error')) {
        errorMessage = 'Server error. Please try again in a moment.';
      }
      
      setState(() {
        _error = errorMessage;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to create request: ${errorMessage}',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _createRequest(pollingService, locationService, authService),
            ),
          ),
        );
      }
      
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}