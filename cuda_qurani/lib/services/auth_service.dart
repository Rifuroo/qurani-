import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import './websocket_service.dart';
import '../core/network/app_http_client.dart';
import 'package:dio/dio.dart';

/// Service responsible for managing user authentication and session state.
class AuthService {
  /// Singleton instance of [AuthService].
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Dio _dio = AppHttpClient().dio;
  final _storage = const FlutterSecureStorage();
  UserModel? _currentUser;
  String? _accessToken;

  /// Google OAuth 2.0 Client ID for server-side verification.
  static const String _webClientId =
      '590267340989-afs4u84qlt053lpifpmchh8ts1b3elcm.apps.googleusercontent.com';



  GoogleSignIn? _googleSignIn;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  String? get userId => _currentUser?.id;
  String? get accessToken => _accessToken;

  /// Initializes the service by checking local storage for existing session tokens.
  ///
  /// If a token is found, it attempts to fetch the user profile.
  /// Also pre-initializes the Google Sign-In instance.
  Future<void> initialize() async {
    print('🔐 Initializing AuthService...');
    
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      print('🔑 Token found, fetching profile...');
      _accessToken = token;
      await getMe();
    } else {
      print('⚠️ No access token found');
    }

    warmUpGoogleSignIn();
    print('✅ AuthService initialized');
  }

  /// Silently initializes the Google Sign-In client to reduce latency on first user interaction.
  Future<void> warmUpGoogleSignIn() async {
    try {
      _googleSignIn ??= GoogleSignIn(
        serverClientId: _webClientId,
        scopes: ['email', 'profile', 'openid'],
      );
      await _googleSignIn!.signInSilently(suppressErrors: true);
      print('🧊 Google Sign In warmed up (silent)');
    } catch (e) {
      print('⚠️ Warm up Google Sign In failed: $e');
    }
  }

  /// Registers a new user account.
  ///
  /// Returns `true` if registration is successful.
  Future<bool> signUp({
    required String email,
    required String username,
    required String password,
    required String name,
  }) async {
    try {
      print('📝 Signing up: $email ($username)');

      final response = await _dio.post('/api/v1/Auth/register', data: {
        'email': email,
        'username': username,
        'password': password,
        'name': name,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Sign up successful');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Sign up failed: $e');
      rethrow;
    }
  }

  /// Authenticates a user using email/username and password.
  ///
  /// On success, stores the access and refresh tokens securely.
  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      print('🔑 Signing in: $email');

      final response = await _dio.post('/api/v1/Auth/login', data: {
        'emailOrUsername': email,
        'password': password,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        
        _accessToken = data['accessToken'];
        await _storage.write(key: 'access_token', value: _accessToken);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        
        // Map userId to id for UserModel
        final userMap = Map<String, dynamic>.from(data);
        userMap['id'] = data['userId'];
        _currentUser = UserModel.fromMap(userMap);
        
        print('✅ Sign in successful for ${_currentUser?.email}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Sign in failed: $e');
      rethrow;
    }
  }

  /// Initiates the Google Sign-In flow.
  ///
  /// Uses the `serverAuthCode` grant type. The code is sent to the backend
  /// to be exchanged for an access token.
  ///
  /// Throws an [Exception] if the Google Credential (authCode) is missing.
  Future<bool> signInWithGoogle() async {
    try {
      print('🔑 Starting Google Sign In...');
      _googleSignIn ??= GoogleSignIn(
        serverClientId: _webClientId,
        scopes: ['email', 'profile', 'openid'],
        forceCodeForRefreshToken: true,
      );

      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        print('⚠️ User cancelled sign in');

        return false;
      }

      final authCode = googleUser.serverAuthCode;
      
      print('📦 Google Auth: authCode: $authCode');

      if (authCode == null) {
        throw Exception('Kredensial Google (serverAuthCode) tidak ditemukan.');
      }

      print('☁️ Sending Google authCode to API...');
      // Note: We use authCode which is the standard for server-side exchange (v2)
      final response = await _dio.post('/api/v1/OAuth/google/callback', data: {
        'code': authCode,
        'redirectUri': 'postmessage', // Required for serverAuthCode exchange
        'state': null,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        
        _accessToken = data['accessToken'];
        await _storage.write(key: 'access_token', value: _accessToken);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        
        // Map userId to id for UserModel
        final userMap = Map<String, dynamic>.from(data);
        userMap['id'] = data['userId'];
        _currentUser = UserModel.fromMap(userMap);
        
        print('✅ Google sign in successful for ${_currentUser?.email}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Google Sign In failed: $e');
      rethrow;
    }
  }

  /// Logs out the current user.
  ///
  /// Clears local tokens, disconnects WebSocket, and signs out from Google.
  Future<void> signOut() async {
    try {
      print('👋 Signing out...');
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }

      // Disconnect WebSocket
      try {
        final ws = WebSocketService();
        if (ws.isConnected) ws.disconnect();
        WebSocketService.resetInstance();
      } catch (_) {}

      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      _currentUser = null;
      _accessToken = null;

      print('✅ Signed out completely');
    } catch (e) {
      print('❌ Sign out failed: $e');
      rethrow;
    }
  }

  /// Fetches the current user's profile from the server.
  ///
  /// Returns [UserModel] if successful, or `null` if the request fails (e.g. invalid token).
  Future<UserModel?> getMe() async {
    try {
      final response = await _dio.get('/api/v1/Users/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        _currentUser = UserModel.fromMap(response.data['data']);
        return _currentUser;
      }
    } catch (e) {
      print('❌ Fetch profile failed: $e');
      if (e is DioException && e.response?.statusCode == 401) {
        // Token might be invalid, sign out
        await signOut();
      }
    }
    return null;
  }

  /// Permanently deletes the current user's account.
  Future<bool> deleteAccount() async {
    try {
      print('🗑️ Deleting account...');
      final response = await _dio.delete('/api/v1/Users/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        await signOut();
        return true;
      }
    } catch (e) {
      print('❌ Delete account failed: $e');
    }
    return false;
  }
}
