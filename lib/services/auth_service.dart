// services/auth_service.dart
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
        if (event == AuthChangeEvent.signedIn) {
          _currentUser = data.session?.user;
          _error = '';
          notifyListeners();
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          _error = '';
          notifyListeners();
        } else if (event == AuthChangeEvent.userUpdated) {
          _currentUser = data.session?.user;
          notifyListeners();
        }
      });
    } catch (e) {
      _error = 'Failed to initialize authentication: $e';
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      
      if (response.user != null) {
        // Store additional user data in a separate table
        await _supabase
            .from('profiles')
            .insert({
              'id': response.user!.id,
              'email': email,
              'name': name,
              'created_at': DateTime.now().toIso8601String(),
            });
        
        _currentUser = response.user;
      }
    } catch (e) {
      _error = 'Sign up failed: ${e.toString()}';
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
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _currentUser = response.user;
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      _error = '';
      notifyListeners();
    } catch (e) {
      _error = 'Logout failed: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<String?> getToken() async {
    try {
      final Session? session = _supabase.auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      _error = 'Failed to get token: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }
}