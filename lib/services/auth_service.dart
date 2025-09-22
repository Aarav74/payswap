import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService with ChangeNotifier {
  late SupabaseClient _supabase;
  User? _currentUser;
  bool _isLoading = false;
  String _error = '';

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get error => _error;

  AuthService() {
    _initialize();
  }

  void _initialize() {
    try {
      _supabase = Supabase.instance.client;
      _currentUser = _supabase.auth.currentUser;
      
      // Listen for auth state changes
      _supabase.auth.onAuthStateChange.listen((AuthState data) {
        final AuthChangeEvent event = data.event;
        debugPrint('Auth state changed: $event');
        
        if (event == AuthChangeEvent.signedIn) {
          _currentUser = data.session?.user;
          _error = '';
          debugPrint('User signed in: ${_currentUser?.email}');
          notifyListeners();
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          _error = '';
          debugPrint('User signed out');
          notifyListeners();
        } else if (event == AuthChangeEvent.userUpdated) {
          _currentUser = data.session?.user;
          debugPrint('User updated: ${_currentUser?.email}');
          notifyListeners();
        } else if (event == AuthChangeEvent.tokenRefreshed) {
          _currentUser = data.session?.user;
          debugPrint('Token refreshed for user: ${_currentUser?.email}');
          notifyListeners();
        }
      });
    } catch (e) {
      _error = 'Failed to initialize authentication: $e';
      debugPrint('Auth initialization error: $e');
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      debugPrint('Attempting to sign up user: $email');
      
      // Validate inputs
      if (email.trim().isEmpty || password.trim().isEmpty || name.trim().isEmpty) {
        throw Exception('All fields are required');
      }
      
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$').hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }

      final AuthResponse response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      
      if (response.user != null) {
        debugPrint('User created successfully: ${response.user!.email}');
        
        try {
          // Store additional user data in profiles table with default location
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'email': email.trim(),
            'name': name.trim(),
            'latitude': 0.0, // Default latitude
            'longitude': 0.0, // Default longitude
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          
          debugPrint('User profile created successfully');
        } catch (profileError) {
          debugPrint('Error creating profile: $profileError');
          // Don't throw here as the user account was created successfully
          // The profile will be created on first location update
        }
        
        _currentUser = response.user;
        _error = '';
      } else {
        throw Exception('Failed to create account. Please try again.');
      }
    } on AuthException catch (e) {
      debugPrint('Auth exception during signup: ${e.message}');
      _error = e.message;
    } catch (e) {
      debugPrint('General error during signup: $e');
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      debugPrint('Attempting to login user: $email');
      
      // Validate inputs
      if (email.trim().isEmpty || password.trim().isEmpty) {
        throw Exception('Email and password are required');
      }

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      
      if (response.user != null) {
        _currentUser = response.user;
        _error = '';
        debugPrint('User logged in successfully: ${_currentUser!.email}');
        
        // Check if profile exists, create if it doesn't
        await _ensureProfileExists();
      } else {
        throw Exception('Login failed. Please check your credentials.');
      }
    } on AuthException catch (e) {
      debugPrint('Auth exception during login: ${e.message}');
      _error = e.message;
    } catch (e) {
      debugPrint('General error during login: $e');
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      debugPrint('Attempting to logout user: ${_currentUser?.email}');
      await _supabase.auth.signOut();
      _currentUser = null;
      _error = '';
      debugPrint('User logged out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Error during logout: $e');
      _error = 'Logout failed: ${e.toString()}';
      notifyListeners();
    }
  }

  // Add the missing _ensureProfileExists method
  Future<void> _ensureProfileExists() async {
    if (_currentUser == null) return;
    
    try {
      // Check if profile exists
      
      debugPrint('Profile exists for user: ${_currentUser!.email}');
    } catch (e) {
      debugPrint('Profile not found, creating new profile for: ${_currentUser!.email}');
      
      try {
        // Create profile if it doesn't exist
        await _supabase.from('profiles').insert({
          'id': _currentUser!.id,
          'email': _currentUser!.email ?? '',
          'name': _currentUser!.userMetadata?['name'] ?? 'User',
          'latitude': 0.0, // Default latitude
          'longitude': 0.0, // Default longitude
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        debugPrint('Profile created successfully');
      } catch (createError) {
        debugPrint('Error creating profile: $createError');
        // Don't throw as this is not critical for login
      }
    }
  }

  Future<String?> getToken() async {
    try {
      final Session? session = _supabase.auth.currentSession;
      final token = session?.accessToken;
      
      if (token == null) {
        debugPrint('No access token available');
        return null;
      }
      
      // Check if token is expired
      if (session!.expiresAt != null) {
        final expirationTime = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        if (DateTime.now().isAfter(expirationTime)) {
          debugPrint('Token expired, attempting refresh...');
          try {
            await _supabase.auth.refreshSession();
            final newSession = _supabase.auth.currentSession;
            return newSession?.accessToken;
          } catch (e) {
            debugPrint('Token refresh failed: $e');
            return null;
          }
        }
      }
      
      return token;
    } catch (e) {
      debugPrint('Error getting token: $e');
      _error = 'Failed to get authentication token: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }
}