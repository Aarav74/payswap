// screens/request_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../models/request_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../widgets/request_card.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  _RequestScreenState createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _amountController = TextEditingController();
  String _selectedType = 'Need Cash';
  bool _isLoading = false;
  bool _isLoadingRequests = false;
  String _error = '';
  List<Request> _requests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  Future<void> _performCreateRequest(ApiService apiService, LocationService locationService, double amount) async {
    // Get current location with simplified logic
    debugPrint('Getting current location...');
    try {
      await locationService.getCurrentLocation();
      
      // Wait a bit for location to update
      await Future.delayed(Duration(milliseconds: 1000));
      
      debugPrint('Location service state: lat=${locationService.latitude}, lng=${locationService.longitude}');
      
      if (locationService.latitude == 0.0 && locationService.longitude == 0.0) {
        throw Exception('Could not get your current location. Please check your location settings and try again.');
      }
      
      debugPrint('Location obtained successfully: ${locationService.latitude}, ${locationService.longitude}');
      
    } catch (e) {
      debugPrint('Location error: $e');
      throw Exception('Location error: ${e.toString()}');
    }

    // Create request
    debugPrint('Creating request via API...');
    final request = await apiService.createRequest(
      amount: amount,
      type: _selectedType,
      latitude: locationService.latitude,
      longitude: locationService.longitude,
    );

    debugPrint('Request creation result: ${request != null ? 'Success' : 'Failed'}');

    if (request != null) {
      // Clear form and reset state
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
                    'Request created successfully! (\${amount.toStringAsFixed(2)})',
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

      // Reload requests to show the new one
      await _loadRequests();
    } else {
      throw Exception('Failed to create request - no response received from server');
    }
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingRequests = true;
      _error = '';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final requests = await apiService.getNearbyRequests();
      
      if (mounted) {
        setState(() {
          _requests = requests;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        
        setState(() {
          _error = 'Failed to load requests: $errorMessage';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final locationService = Provider.of<LocationService>(context);
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadRequests,
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
                        onPressed: _isLoading ? null : () => _createRequest(apiService, locationService, authService),
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
                      if (_requests.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_requests.length}',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      Spacer(),
                      if (_isLoadingRequests)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: _isLoadingRequests ? null : _loadRequests,
                        tooltip: 'Refresh requests',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              
              // Requests List
              Expanded(
                child: _buildRequestsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_isLoadingRequests) {
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

    if (_error.isNotEmpty && _requests.isEmpty) {
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
                  _error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700]),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadRequests,
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

    if (_requests.isEmpty) {
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
                  onPressed: _loadRequests,
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
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: RequestCard(request: _requests[index]),
        );
      },
    );
  }


  Future<void> _createRequest(ApiService apiService, LocationService locationService, AuthService authService) async {
    debugPrint('=== Starting _createRequest ===');
    
    // Check if user is authenticated
    if (authService.currentUser == null) {
      setState(() {
        _error = 'Please login to create a request';
      });
      return;
    }

    debugPrint('User authenticated: ${authService.currentUser?.email}');

    // Validate amount input
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

    debugPrint('Amount validated: \$${amount.toStringAsFixed(2)}');

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final completer = Completer();
      final timer = Timer(Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Request creation timed out after 30 seconds'));
        }
      });
      
      try {
        await _performCreateRequest(apiService, locationService, amount);
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        } else {
          rethrow;
        }
      } finally {
        timer.cancel();
      }
      
      await completer.future;

    } on TimeoutException {
      debugPrint('Request creation timed out');
      setState(() {
        _error = 'Request timed out. Please check your internet connection and try again.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.timer_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Request timed out. Please try again.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('Error in _createRequest: $e');
      
      String errorMessage = e.toString();
      
      // Clean up error message
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      // Parse HTTP error responses for better user feedback
      if (errorMessage.contains('Failed to create request (')) {
        try {
          final match = RegExp(r'\((\d+)\): (.+)').firstMatch(errorMessage);
          if (match != null) {
            final statusCode = match.group(1);
            final responseBody = match.group(2);
            
            // Try to parse JSON error response
            try {
              final errorData = jsonDecode(responseBody ?? '{}');
              if (errorData['detail'] != null) {
                errorMessage = errorData['detail'];
              } else {
                errorMessage = 'Server error ($statusCode). Please try again later.';
              }
            } catch (_) {
              errorMessage = 'Server error ($statusCode). Please try again later.';
            }
          }
        } catch (_) {
          // Keep original error message
        }
      }
      
      // Handle specific error types
      if (errorMessage.toLowerCase().contains('location')) {
        errorMessage += '\n\nTip: Make sure location services are enabled for this app.';
      } else if (errorMessage.toLowerCase().contains('authentication') || 
                 errorMessage.toLowerCase().contains('login')) {
        errorMessage = 'Please log out and log back in to continue.';
      } else if (errorMessage.toLowerCase().contains('network') || 
                 errorMessage.toLowerCase().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      setState(() {
        _error = errorMessage;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to create request: $errorMessage',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _createRequest(apiService, locationService, authService),
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}