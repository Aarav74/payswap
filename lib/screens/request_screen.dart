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
  
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPolling();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _startPolling() async {
    final pollingService = Provider.of<RequestPollingService>(context, listen: false);
    
    final isAvailable = await pollingService.isServerAvailable();
    if (!isAvailable && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to connect to server. Please check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    await pollingService.startPolling(interval: Duration(seconds: 15));
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
    
    // Show loading state if needed
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
                          prefixText: '\$ ',
                          prefixIcon: Icon(Icons.attach_money),
                          hintText: 'Enter amount (e.g., 100.00)',
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
                      Spacer(),
                      if (pollingService.isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: pollingService.isLoading ? null : _refreshRequests,
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
                ElevatedButton.icon(
                  onPressed: _refreshRequests,
                  icon: Icon(Icons.refresh),
                  label: Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
        _error = 'Amount cannot exceed \$10,000';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      debugPrint('Getting current location...');
      await locationService.getCurrentLocation().timeout(Duration(seconds: 10));
      
      if (locationService.latitude == null || locationService.longitude == null) {
        throw Exception('Could not get your current location. Please check your location settings.');
      }

      debugPrint('Location obtained: ${locationService.latitude}, ${locationService.longitude}');

      // Map display type to API type - FIXED: Use the exact values the backend expects
      String requestType = _selectedType == 'Need Cash' ? 'cash' : 'online';
      
      debugPrint('Creating request via polling service...');
      final request = await pollingService.createRequest(
        amount: amount,
        type: requestType, // Send the correct type that backend expects
        latitude: locationService.latitude!,
        longitude: locationService.longitude!,
      ).timeout(Duration(seconds: 15));

      if (request != null) {
        _amountController.clear();
        setState(() {
          _selectedType = 'Need Cash';
          _error = '';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Request created successfully! (\$${amount.toStringAsFixed(2)})',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        throw Exception('Failed to create request - no response received from server');
      }
      
    } on TimeoutException catch (e) {
      debugPrint('Request creation timed out: $e');
      setState(() {
        _error = 'Request timed out. Please check your internet connection and try again.';
      });
      
    } catch (e) {
      debugPrint('Error in _createRequest: $e');
      
      String errorMessage = e.toString();
      
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      if (errorMessage.toLowerCase().contains('location')) {
        errorMessage = 'Location error. Please enable location services for this app.';
      } else if (errorMessage.toLowerCase().contains('authentication') || 
                 errorMessage.toLowerCase().contains('login')) {
        errorMessage = 'Authentication error. Please log out and log back in.';
      } else if (errorMessage.toLowerCase().contains('network') || 
                 errorMessage.toLowerCase().contains('connection') ||
                 errorMessage.toLowerCase().contains('timeout')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      }
      
      setState(() {
        _error = errorMessage;
      });
      
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}