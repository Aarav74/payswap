import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WebSocketService with ChangeNotifier {
  // Using your local network IP for both WebSocket and HTTP
  static const String _baseUrl = 'ws://192.168.86.147:8000/ws';
  static const String _httpBaseUrl = 'http://192.168.86.147:8000';
  
  // Add a method to check server availability
  Future<bool> isServerAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_httpBaseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Server check failed: $e');
      return false;
    }
  }
  final AuthService _authService;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  StreamController<dynamic> _messageController = StreamController<dynamic>.broadcast();

  WebSocketService({required AuthService authService}) : _authService = authService;

  bool get isConnected => _isConnected;
  Stream<dynamic> get messageStream => _messageController.stream;

  Future<void> connect() async {
    try {
      // First check if server is available
      final isAvailable = await isServerAvailable();
      if (!isAvailable) {
        throw Exception('Server is not available. Please check your connection.');
      }

      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Close existing connection if any
      await disconnect();

      // Create new connection with headers
      _channel = WebSocketChannel.connect(
        Uri.parse(_baseUrl),
        protocols: ['protocolOne', 'protocolTwo'],
      );

      // Set up a connection timeout
      final connectionTimeout = Future.delayed(
        const Duration(seconds: 10),
        () {
          if (!_isConnected) {
            _channel?.sink.close(
              status.goingAway,
              'Connection timeout',
            );
            throw TimeoutException('Connection timeout');
          }
        },
      );

      // Send authentication message
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'token': token,
      }));

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
            
            // Handle authentication response
            if (data['type'] == 'auth_success') {
              _isConnected = true;
              notifyListeners();
              debugPrint('WebSocket authenticated and connected');
            }
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          notifyListeners();
          _reconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;
          notifyListeners();
          _reconnect();
        },
        cancelOnError: true,
      );

      // Wait for connection to be established
      await connectionTimeout;
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      _isConnected = false;
      notifyListeners();
      _reconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _channel?.sink.close(status.normalClosure);
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  void subscribeToRequest(String requestId) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'type': 'subscribe',
        'request_id': requestId,
      }));
    }
  }

  void unsubscribeFromRequest(String requestId) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'type': 'unsubscribe',
        'request_id': requestId,
      }));
    }
  }

  // Add a method to handle reconnection
  void _reconnect() {
    if (_isDisposed) return;
    
    // Only try to reconnect if we're not already connected
    if (!_isConnected) {
      Future.delayed(Duration(seconds: 5), () {
        if (!_isDisposed) {
          debugPrint('Attempting to reconnect WebSocket...');
          connect().catchError((e) {
            debugPrint('Reconnection failed: $e');
          });
        }
      });
    }
  }

  bool _isDisposed = false;
  
  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
