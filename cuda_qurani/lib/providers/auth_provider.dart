import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authStateSubscription;

  bool _isLoading = true;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authService.isAuthenticated;
  UserModel? get currentUser => _authService.currentUser;
  String? get userId => _authService.userId;
  String? get accessToken => _authService.accessToken;

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    print('🔧 AuthProvider: Initializing...');
    
    await _authService.initialize();
    
    if (_authService.isAuthenticated) {
      print('🔄 AuthProvider: Validating session token...');
      try {
        await Supabase.instance.client.auth.refreshSession();
        print('✅ AuthProvider: Session token valid');
      } catch (e) {
        print('⚠️ AuthProvider: Session expired/invalid, signing out...');
        try {
          await _authService.signOut();
        } catch (_) {}
      }
    }
    
    _authStateSubscription = _authService.authStateChanges.listen((AuthState state) {
      print('🔔 AuthProvider: Auth state changed');
      print('   - Event: ${state.event}');
      print('   - User: ${state.session?.user.email ?? "null"}');
      notifyListeners();
    });
    
    print('✅ AuthProvider: Initialized (isAuthenticated=${_authService.isAuthenticated})');
    
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (response.user != null && response.session == null) {
        _setError('Silakan cek email untuk verifikasi akun');
        _setLoading(false);
        return false;
      }
      
      _setLoading(false);
      return response.user != null;
    } catch (e) {
      _setError(_parseError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      
      _setLoading(false);
      return response.user != null;
    } catch (e) {
      _setError(_parseError(e));
      _setLoading(false);
      return false;
    }
  }

  /// ✅ Native Google Sign In
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      print('🔑 AuthProvider: Starting Native Google Sign In...');
      
      final response = await _authService.signInWithGoogle();
      
      _setLoading(false);
      
      final success = response.user != null;
      print('🔑 AuthProvider: Google Sign In ${success ? "SUCCESS" : "FAILED"}');
      
      return success;
    } catch (e) {
      print('❌ AuthProvider: Google Sign In error: $e');
      _setError(_parseError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _parseError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Email atau password salah';
        case 'Email not confirmed':
          return 'Cek email untuk verifikasi';
        case 'User already registered':
          return 'Email sudah terdaftar';
        default:
          return error.message;
      }
    }
    return error.toString();
  }
}


