import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

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
    _setLoading(true);
    
    try {
      await _authService.initialize();
      print('✅ AuthProvider: Initialized (isAuthenticated=${_authService.isAuthenticated})');
    } catch (e) {
      print('❌ AuthProvider: Initialization failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String username,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.signUp(
        email: email,
        username: username,
        password: password,
        name: name,
      );

      if (success) {
        print('✅ AuthProvider: Sign up successful');
        _setLoading(false);
        return true;
      } else {
        _setError('Registrasi gagal. Silakan coba lagi.');
        _setLoading(false);
        return false;
      }
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
      final success = await _authService.signIn(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(_parseError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      print('🔑 AuthProvider: Starting Native Google Sign In...');
      final success = await _authService.signInWithGoogle();
      
      _setLoading(false);
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
    if (error is DioException) {
      final data = error.response?.data;
      if (data != null && data is Map) {
        // 1. Check for dedicated 'message' field
        if (data['message'] != null) {
          return data['message'];
        }
        
        // 2. Check for multi-field validation errors (ASP.NET Core style)
        if (data['errors'] != null && data['errors'] is Map) {
          final errorsMap = data['errors'] as Map;
          final List<String> errorMessages = [];
          
          errorsMap.forEach((key, value) {
            if (value is List) {
              errorMessages.addAll(value.map((e) => e.toString()));
            } else {
              errorMessages.add(value.toString());
            }
          });
          
          if (errorMessages.isNotEmpty) {
            return errorMessages.join('\n');
          }
        }

        // 3. Fallback to 'title' (often used in RFC 7807 problem details)
        if (data['title'] != null) {
          return data['title'];
        }
      }
      return 'Koneksi ke server bermasalah (Code: ${error.response?.statusCode ?? "Unknown"})';
    }
    return error.toString();
  }
}


