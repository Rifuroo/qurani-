// lib/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import './websocket_service.dart';

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  UserModel? _currentUser;

  // ✅ Google Sign In configuration
  // PENTING: serverClientId HARUS dari project yang SAMA dengan Android Client ID
  //
  // Android Client ID: 963510462224-r22lhlh7135ae54rihbdradjiedfssgd (project: 963510462224)
  // Web Client ID harus dari project yang SAMA: 963510462224-7nda8gb5kp9mljc55fotckce6s98fogn
  //
  // Web Client ID 902515920112-... adalah dari project berbeda, tidak bisa digunakan sebagai serverClientId
  //
  // PASTIKAN Web Client ID ini dikonfigurasi di Supabase Dashboard:
  // Authentication → Providers → Google → Client IDs
  // Tambahkan: 963510462224-7nda8gb5kp9mljc55fotckce6s98fogn.apps.googleusercontent.com
  static const String _webClientId =
      '963510462224-7nda8gb5kp9mljc55fotckce6s98fogn.apps.googleusercontent.com';

  GoogleSignIn? _googleSignIn;

  // Getters
  User? get supabaseUser => _supabase.auth.currentUser;
  UserModel? get currentUser => _currentUser;
  String? get userId => supabaseUser?.id;
  String? get accessToken => _supabase.auth.currentSession?.accessToken;
  bool get isAuthenticated => supabaseUser != null;

  // Auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Initialize
  Future<void> initialize() async {
    print('🔐 Initializing AuthService...');
    
    print('   - Current User: ${supabaseUser?.email ?? "null"}');
    print('   - Current Session: ${_supabase.auth.currentSession != null}');
    print('   - Session Access Token: ${_supabase.auth.currentSession?.accessToken != null ? "exists" : "null"}');

    if (supabaseUser != null) {
      _currentUser = UserModel.fromSupabaseUser(supabaseUser!);
      print('✅ User already signed in: ${_currentUser!.email}');
    } else {
      print('⚠️ No user session found');
    }

    // Listen to auth changes
    authStateChanges.listen((AuthState data) {
      print('🔔 AuthService: Auth state event: ${data.event}');

      if (data.session?.user != null) {
        _currentUser = UserModel.fromSupabaseUser(data.session!.user);
        print('✅ User logged in: ${_currentUser!.email}');
      } else {
        _currentUser = null;
        print('⚠️ User logged out');
      }
    });

    // ✅ Warm up Google Sign In in background (non-blocking)
    warmUpGoogleSignIn();

    print('✅ AuthService initialized');
  }

  /// Warm up Google Sign In (signInSilently) to reduce delay when chooser opens
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

  /// Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      print('📝 Signing up: $email');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (response.user != null) {
        _currentUser = UserModel.fromSupabaseUser(response.user!);
        print('✅ Sign up successful');
      }

      return response;
    } catch (e) {
      print('❌ Sign up failed: $e');
      rethrow;
    }
  }

  /// Sign In
  Future<AuthResponse> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      print('🔑 Signing in: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _currentUser = UserModel.fromSupabaseUser(response.user!);

        // ✅ Save remember me preference and user info
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('remember_me', rememberMe);
          if (rememberMe) {
            await prefs.setString('last_user_email', email);
          }
          print('✅ Remember me preference saved: $rememberMe');
        } catch (e) {
          print('⚠️ Failed to save remember me preference: $e');
        }

        print('✅ Sign in successful');
      }

      return response;
    } catch (e) {
      print('❌ Sign in failed: $e');
      rethrow;
    }
  }

  /// ✅ Google Sign In dengan serverClientId (web)
  ///
  /// Menggunakan google_sign_in v6.x yang lebih stabil
  /// Untuk v6.x, cukup menggunakan serverClientId saja
  /// Android client ID akan otomatis diambil dari google-services.json
  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('🔑 Starting Google Sign In...');
      print('   - Web Client ID (serverClientId): $_webClientId');

      // Buat GoogleSignIn instance dengan serverClientId saja
      // Android client ID akan otomatis diambil dari google-services.json
      _googleSignIn ??= GoogleSignIn(
        serverClientId: _webClientId,
        scopes: ['email', 'profile', 'openid'],
      );

      // Sign in user (ini yang menampilkan dialog pilih akun)
      print('📱 Calling signIn()...');
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        print('⚠️ User cancelled sign in');
        throw Exception('Login dibatalkan');
      }

      print('✅ Google user signed in: ${googleUser.email}');
      print('   - Display Name: ${googleUser.displayName}');
      print('   - ID: ${googleUser.id}');

      // Get authentication tokens
      print('🔐 Getting authentication tokens...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception(
          'ID Token tidak ditemukan. Pastikan konfigurasi Google Cloud Console sudah benar.',
        );
      }

      print(
        '✅ ID Token obtained: ${googleAuth.idToken!.substring(0, 20)}... (${googleAuth.idToken!.length} chars)',
      );
      print(
        '✅ Access Token: ${googleAuth.accessToken != null ? "${googleAuth.accessToken!.substring(0, 20)}... (${googleAuth.accessToken!.length} chars)" : "⚠️ Not obtained"}',
      );

      // Sign in to Supabase with Google tokens
      print('☁️ Signing in to Supabase with Google tokens...');
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      print('📦 Supabase response received');
      print('   - User: ${response.user?.email ?? "null"}');
      print('   - Session: ${response.session != null}');

      if (response.user != null && response.session != null) {
        _currentUser = UserModel.fromSupabaseUser(response.user!);
        
        // ✅ Save remember me for Google Sign In
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('remember_me', true);
          await prefs.setString('last_user_email', response.user!.email ?? '');
          print('✅ Google Sign In remember me saved');
        } catch (e) {
          print('⚠️ Failed to save Google Sign In remember me: $e');
        }
        
        print('✅ Supabase sign in successful');
        print('   - User: ${_currentUser!.email}');
        print('   - User ID: ${_currentUser!.id}');
        print('   - Session exists: true');
      } else {
        print('❌ Supabase response incomplete');
        print('   - User null: ${response.user == null}');
        print('   - Session null: ${response.session == null}');
        throw Exception(
          'Supabase authentication failed: User or session is null',
        );
      }

      return response;
    } catch (e, stackTrace) {
      print('❌ Google Sign In failed: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Stack trace: $stackTrace');

      // Handle specific error codes
      if (e.toString().contains('ApiException: 10')) {
        print('⚠️ DEVELOPER_ERROR (10): Kemungkinan masalah:');
        print(
          '   1. SHA-1 fingerprint tidak cocok dengan Google Cloud Console',
        );
        print('   2. Client ID tidak sesuai dengan package name');
        print('   3. Konfigurasi di Google Cloud Console belum benar');
        throw Exception(
          'Konfigurasi Google Sign In belum benar. Pastikan SHA-1 fingerprint sudah ditambahkan di Google Cloud Console.',
        );
      }

      rethrow;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      print('👋 Signing out...');

      // ✅ Sign out from Google
      try {
        if (_googleSignIn != null) {
          await _googleSignIn!.signOut();
          print('✅ Google Sign Out successful');
        }
      } catch (e) {
        print('⚠️ Google Sign Out failed: $e');
      }

      // ✅ Disconnect WebSocket
      try {
        print('🔌 Disconnecting WebSocket before logout...');
        final ws = WebSocketService();
        if (ws.isConnected) {
          ws.disconnect();
        }
        WebSocketService.resetInstance();
        print('✅ WebSocket disconnected and reset');
      } catch (e) {
        print('⚠️ Failed to disconnect WebSocket: $e');
      }

      // ✅ Sign out from Supabase
      await _supabase.auth.signOut();
      _currentUser = null;

      // ✅ Clear all auth-related preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me');
      await prefs.remove('last_user_email');
      print('✅ Auth preferences cleared');

      print('✅ Signed out completely');
    } catch (e) {
      print('❌ Sign out failed: $e');
      rethrow;
    }
  }

  /// Reset Password
  Future<void> resetPassword(String email) async {
    try {
      print('📧 Sending reset email to: $email');

      await _supabase.auth.resetPasswordForEmail(email);

      print('✅ Reset email sent');
    } catch (e) {
      print('❌ Reset failed: $e');
      rethrow;
    }
  }

  /// ✅ DELETE ACCOUNT - Removes all user data and signs out
  ///
  /// This deletes:
  /// - live_sessions
  /// - user_progress
  /// - user_achievements
  /// - user_goals
  /// - daily_goal_progress
  /// - notifications
  /// - user_profiles
  ///
  /// Then signs out the user completely.
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final userId = supabaseUser?.id;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      print('🗑️ Starting account deletion for user: $userId');

      // Delete data from each table
      int sessionsDeleted = 0;
      int progressDeleted = 0;
      int achievementsDeleted = 0;
      int goalsDeleted = 0;
      int goalProgressDeleted = 0;
      int notificationsDeleted = 0;
      int profileDeleted = 0;

      // 1. Delete live_sessions
      try {
        final result = await _supabase
            .from('live_sessions')
            .delete()
            .eq('user_uuid', userId)
            .select();
        sessionsDeleted = (result as List).length;
        print('   ✓ Deleted $sessionsDeleted sessions');
      } catch (e) {
        print('   ⚠️ Error deleting sessions: $e');
      }

      // 2. Delete user_progress
      try {
        final result = await _supabase
            .from('user_progress')
            .delete()
            .eq('user_id', userId)
            .select();
        progressDeleted = (result as List).length;
        print('   ✓ Deleted $progressDeleted progress records');
      } catch (e) {
        print('   ⚠️ Error deleting progress: $e');
      }

      // 3. Delete user_achievements
      try {
        final result = await _supabase
            .from('user_achievements')
            .delete()
            .eq('user_id', userId)
            .select();
        achievementsDeleted = (result as List).length;
        print('   ✓ Deleted $achievementsDeleted achievements');
      } catch (e) {
        print('   ⚠️ Error deleting achievements: $e');
      }

      // 4. Delete user_goals
      try {
        final result = await _supabase
            .from('user_goals')
            .delete()
            .eq('user_id', userId)
            .select();
        goalsDeleted = (result as List).length;
        print('   ✓ Deleted $goalsDeleted goals');
      } catch (e) {
        print('   ⚠️ Error deleting goals: $e');
      }

      // 5. Delete daily_goal_progress
      try {
        final result = await _supabase
            .from('daily_goal_progress')
            .delete()
            .eq('user_id', userId)
            .select();
        goalProgressDeleted = (result as List).length;
        print('   ✓ Deleted $goalProgressDeleted goal progress records');
      } catch (e) {
        print('   ⚠️ Error deleting goal progress: $e');
      }

      // 6. Delete notifications
      try {
        final result = await _supabase
            .from('notifications')
            .delete()
            .eq('user_id', userId)
            .select();
        notificationsDeleted = (result as List).length;
        print('   ✓ Deleted $notificationsDeleted notifications');
      } catch (e) {
        print('   ⚠️ Error deleting notifications: $e');
      }

      // 7. Delete user_profiles (last)
      try {
        final result = await _supabase
            .from('user_profiles')
            .delete()
            .eq('id', userId)
            .select();
        profileDeleted = (result as List).length;
        print('   ✓ Deleted $profileDeleted profile');
      } catch (e) {
        print('   ⚠️ Error deleting profile: $e');
      }

      // 8. Delete auth user via Edge Function (MUST be done before signOut)
      try {
        final accessToken = _supabase.auth.currentSession?.accessToken;
        if (accessToken != null) {
          final response = await _supabase.functions.invoke(
            'delete-user',
            headers: {'Authorization': 'Bearer $accessToken'},
          );

          if (response.status == 200) {
            print('   ✓ Auth user deleted via Edge Function');
          } else {
            print('   ⚠️ Edge Function error: ${response.data}');
          }
        }
      } catch (e) {
        print('   ⚠️ Error calling delete-user function: $e');
        // Continue anyway - data is already deleted
      }

      // Sign out completely (will fail gracefully if auth user was deleted)
      try {
        await signOut();
      } catch (e) {
        print('   ⚠️ Sign out after delete: $e');
        _currentUser = null;
      }

      final summary = {
        'success': true,
        'sessions': sessionsDeleted,
        'progress': progressDeleted,
        'achievements': achievementsDeleted,
        'goals': goalsDeleted,
        'goal_progress': goalProgressDeleted,
        'notifications': notificationsDeleted,
        'profile': profileDeleted,
        'auth_deleted': true,
      };

      print('✅ Account deleted successfully: $summary');
      return summary;
    } catch (e) {
      print('❌ Delete account failed: $e');
      rethrow;
    }
  }
}
