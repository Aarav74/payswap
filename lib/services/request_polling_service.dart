import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/request_model.dart';

class RequestPollingService with ChangeNotifier {
  // Use 10.0.2.2 for Android emulator, your local IP for physical device
  static const String _httpBaseUrl = 'http://192.168.1.33:8000';
  
  final AuthService _authService;
  Timer? _pollingTimer;
  List<Request> _requests = [];
  bool _isPolling = false;
  bool _isLoading = false;
  String? _lastRequestId;
  String? _error;
  DateTime? _lastFetch;
  
  RequestPollingService({required AuthService authService}) : _authService = authService;
  
  // Getters
  List<Request> get requests => _requests;
  bool get isPolling => _isPolling;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _requests.isNotEmpty;
  
  // Check if server is available - improved version
  Future<bool> isServerAvailable() async {
    try {
      debugPrint('Checking server availability at: $_httpBaseUrl/health');
      final response = await http.get(
        Uri.parse('$_httpBaseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      debugPrint('Server health check response: ${response.statusCode}');
      
      // Accept more status codes as "available"
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      debugPrint('Server health check failed: $e');
      return false;
    }
  }
  
  // Basic connectivity test as fallback
  Future<bool> isServerReachable() async {
    try {
      debugPrint('Testing server connectivity to: $_httpBaseUrl');
      
      // Try multiple endpoints for better reliability
      final endpoints = ['/', '/health', '/api/health'];
      
      for (var endpoint in endpoints) {
        try {
          final uri = Uri.parse('$_httpBaseUrl$endpoint');
          debugPrint('Trying endpoint: $uri');
          
          final response = await http.get(
            uri,
            headers: {'Content-Type': 'application/json'},
          ).timeout(Duration(seconds: 5));
          
          if (response.statusCode >= 200 && response.statusCode < 400) {
            debugPrint('Successfully connected to $endpoint (${response.statusCode})');
            return true;
          }
          debugPrint('Endpoint $endpoint returned status: ${response.statusCode}');
        } catch (e) {
          debugPrint('Error trying $endpoint: $e');
          // Continue to next endpoint
        }
      }
      
      debugPrint('All connectivity tests failed');
      return false;
    } catch (e) {
      debugPrint('Connectivity test failed with error: $e');
      return false;
    }
  }
  
  // Test multiple connection methods
  Future<Map<String, bool>> testConnectivity() async {
    final results = <String, bool>{};
    
    // Test health endpoint
    results['health'] = await isServerAvailable();
    
    // Test root endpoint
    results['root'] = await isServerReachable();
    
    // Test requests endpoint
    try {
      final token = await _authService.getToken();
      if (token != null) {
        final response = await http.get(
          Uri.parse('$_httpBaseUrl/requests/nearby'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(Duration(seconds: 8));
        results['requests'] = response.statusCode < 500;
      }
    } catch (e) {
      results['requests'] = false;
    }
    
    debugPrint('Connectivity test results: $results');
    return results;
  }
  
  // Start polling for requests
  Future<void> startPolling({Duration interval = const Duration(seconds: 15)}) async {
    if (_isPolling) return;
    
    debugPrint('Starting request polling with ${interval.inSeconds}s interval');
    _isPolling = true;
    _error = null;
    notifyListeners();
    
    // Initial fetch
    await _fetchRequests(isInitial: true);
    
    // Set up periodic polling
    _pollingTimer = Timer.periodic(interval, (timer) {
      _fetchRequests();
    });
  }
  
  // Stop polling
  void stopPolling() {
    debugPrint('Stopping request polling');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    notifyListeners();
  }
  
  // Manual refresh
  Future<void> refresh() async {
    debugPrint('Manual refresh triggered');
    await _fetchRequests(forceRefresh: true);
  }
  
  // Clear all data
  void clear() {
    _requests.clear();
    _error = null;
    _lastRequestId = null;
    _lastFetch = null;
    notifyListeners();
  }

  // Create a new request
  Future<Request?> createRequest({
    required double amount,
    required String type,
    required double latitude,
    required double longitude,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated - please log in again');
      }

      debugPrint('Creating request: amount=$amount, type=$type, lat=$latitude, lng=$longitude');

      final response = await http.post(
        Uri.parse('$_httpBaseUrl/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'type': type,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(Duration(seconds: 15));

      debugPrint('Create request response: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final request = Request.fromJson(data);
        _requests.insert(0, request);
        _lastRequestId = request.id;
        notifyListeners();
        return request;
      } else {
        String errorMessage = 'Failed to create request';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (e) {
          // If JSON decode fails, use status code
          errorMessage = 'Server error (${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating request: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Fetch requests from API
  Future<void> _fetchRequests({
    bool isInitial = false, 
    bool forceRefresh = false
  }) async {
    try {
      // Don't fetch too frequently unless forced
      if (!forceRefresh && 
          _lastFetch != null && 
          DateTime.now().difference(_lastFetch!).inSeconds < 5) {
        return;
      }
      
      final token = await _authService.getToken();
      if (token == null) {
        _error = 'Authentication required';
        if (isInitial) notifyListeners();
        return;
      }
      
      // Show loading for initial fetch or manual refresh
      if (isInitial || forceRefresh) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }
      
      final response = await http.get(
        Uri.parse('$_httpBaseUrl/requests/nearby'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Request> newRequests = data
            .map((json) => Request.fromJson(json))
            .toList();
        
        // Update requests if there are changes
        bool hasChanges = _requests.length != newRequests.length;
        if (!hasChanges && newRequests.isNotEmpty) {
          // Check if first request ID changed (simple change detection)
          hasChanges = newRequests.first.id != _lastRequestId;
        }
        
        if (hasChanges || _requests.isEmpty) {
          _requests = newRequests;
          if (newRequests.isNotEmpty) {
            _lastRequestId = newRequests.first.id;
          }
          _error = null;
          _lastFetch = DateTime.now();
          
          debugPrint('Requests updated: ${_requests.length} found');
          notifyListeners();
        } else {
          _lastFetch = DateTime.now();
          // Don't notify if no changes to prevent unnecessary rebuilds
        }
        
      } else if (response.statusCode == 401) {
        _error = 'Authentication expired - please log in again';
        debugPrint('Authentication error: ${response.statusCode}');
        if (isInitial || forceRefresh) notifyListeners();
      } else {
        _error = 'Server error (${response.statusCode})';
        debugPrint('API error: ${response.statusCode} - ${response.body}');
        if (isInitial || forceRefresh) notifyListeners();
      }
      
    } catch (e) {
      String errorMsg = 'Network error';
      
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMsg = 'Connection timeout - check your internet connection';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        errorMsg = 'Cannot reach server - check server is running';
      } else {
        errorMsg = 'Network error: ${e.toString()}';
      }
      
      _error = errorMsg;
      debugPrint('Polling error: $e');
      
      // Only notify on errors for initial fetch or manual refresh
      if (isInitial || forceRefresh) {
        notifyListeners();
      }
    } finally {
      if (isInitial || forceRefresh) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
  
  // Add a new request to the local list (when user creates one)
  void addRequest(Request request) {
    _requests.insert(0, request); // Add to beginning
    _lastRequestId = request.id;
    notifyListeners();
    debugPrint('Request added locally: ${request.id}');
  }
  
  // Remove a request from the local list
  void removeRequest(String requestId) {
    _requests.removeWhere((req) => req.id == requestId);
    notifyListeners();
    debugPrint('Request removed locally: $requestId');
  }
  
  // Update a specific request
  void updateRequest(Request updatedRequest) {
    final index = _requests.indexWhere((req) => req.id == updatedRequest.id);
    if (index != -1) {
      _requests[index] = updatedRequest;
      notifyListeners();
      debugPrint('Request updated locally: ${updatedRequest.id}');
    }
  }
  
  // Get request by ID
  Request? getRequestById(String requestId) {
    try {
      return _requests.firstWhere((req) => req.id == requestId);
    } catch (e) {
      return null;
    }
  }
  
  // Filter requests by type
  List<Request> getRequestsByType(String type) {
    // Map display type to API type
    String apiType = type;
    if (type == 'Need Cash') {
      apiType = 'cash';
    } else if (type == 'Need Online Payment') {
      apiType = 'online';
    }
    return _requests.where((req) => req.type == apiType).toList();
  }
  
  // Get requests within distance (if you have distance calculation)
  List<Request> getNearbyRequests({double? maxDistance}) {
    // If you implement distance calculation, filter here
    // For now, return all requests
    return _requests;
  }
  
  @override
  void dispose() {
    debugPrint('RequestPollingService disposing');
    stopPolling();
    super.dispose();
  }
}