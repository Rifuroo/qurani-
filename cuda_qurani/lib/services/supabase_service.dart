import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  final String supabaseUrl;
  final String anonKey;

  SupabaseService()
    : supabaseUrl = AppConfig.supabaseUrl,
      anonKey = AppConfig.supabaseAnonKey;

  Map<String, String> get _headers {
    // ✅ FIX: Use user's access token for RLS to work
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken ?? anonKey;

    return {
      'apikey': anonKey,
      'Authorization': 'Bearer $accessToken', // ✅ Use JWT token, not anon key
      'Content-Type': 'application/json',
    };
  }

  Future<void> saveSession({
    required String sessionId,
    required int surah,
    required double matched,
    required double errors,
    required double skipped,
    int? ayah,
    int? position,
    String? userId,
    String? userUuid,
    String? status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // ✅ FIX: Gunakan table 'live_sessions' sesuai backend
      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/live_sessions'),
        headers: _headers,
        body: jsonEncode({
          'session_id': sessionId,
          'user_id': userId ?? 'anonymous',
          'surah_id': surah,
          'ayah': ayah ?? 1,
          'position': position ?? 0,
          'mode': 'surah',
          'data': {
            'matched': matched,
            'errors': errors,
            'skipped': skipped,
            ...?additionalData, // Additional data like word_status_map, tartib_status
          },
          'status': status ?? 'completed',
          if (userUuid != null) 'user_uuid': userUuid,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to save session: ${response.body}');
      }
    } catch (e) {
      print('Error saving session: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSessions({String? userUuid}) async {
    try {
      // ✅ FIX: Gunakan table 'live_sessions' sesuai backend
      String url = '$supabaseUrl/rest/v1/live_sessions?order=created_at.desc';

      // Filter by user if provided
      if (userUuid != null) {
        url += '&user_uuid=eq.$userUuid';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch sessions: ${response.body}');
      }
    } catch (e) {
      print('Error fetching sessions: $e');
      return [];
    }
  }

  /// Get last paused session for resume functionality
  Future<Map<String, dynamic>?> getLastPausedSession(String userUuid) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/live_sessions?user_uuid=eq.$userUuid&status=eq.paused&order=updated_at.desc&limit=1',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final sessions = jsonDecode(response.body) as List;
        if (sessions.isNotEmpty) {
          return sessions[0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching last paused session: $e');
      return null;
    }
  }

  /// ✅ NEW: Get latest session (any status) for continue functionality
  Future<Map<String, dynamic>?> getLatestSession(
    String userUuid, {
    List<String>? statuses, // Filter by specific statuses (optional)
  }) async {
    try {
      // Build query - filter by user_uuid AND surah_id not null
      String query = 'user_uuid=eq.$userUuid&surah_id=not.is.null';

      // Filter by statuses if provided
      if (statuses != null && statuses.isNotEmpty) {
        // Use OR operator for multiple statuses
        // Example: status=in.(paused,active)
        query += '&status=in.(${statuses.join(',')})';
      }

      // Use view with surah name joined
      print(
        '🔍 Query: $supabaseUrl/rest/v1/live_sessions_with_surah?$query&order=updated_at.desc&limit=1',
      );

      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/live_sessions_with_surah?$query&order=updated_at.desc&limit=1',
        ),
        headers: _headers,
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final sessions = jsonDecode(response.body) as List;
        print('📦 Sessions count: ${sessions.length}');

        if (sessions.isNotEmpty) {
          final session = sessions[0] as Map<String, dynamic>;
          print('📥 Latest session found:');
          print('   Session ID: ${session['session_id']}');
          print('   Status: ${session['status']}');
          print(
            '   Surah: ${session['surah_id']}, Ayah: ${session['ayah']}, Position: ${session['position']}',
          );
          print('   User UUID: ${session['user_uuid']}');
          print('   Updated: ${session['updated_at']}');
          return session;
        } else {
          print('⚠️ No sessions returned from query');
        }
      } else {
        print('❌ HTTP error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e, stackTrace) {
      print('❌ Error fetching latest session: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// ✅ NEW: Get resumable session (paused or active only)
  Future<Map<String, dynamic>?> getResumableSession(String userUuid) async {
    return getLatestSession(userUuid, statuses: ['paused', 'active']);
  }

  /// Get all sessions for current user (all statuses: active, paused, stopped)
  Future<List<Map<String, dynamic>>> getAllSessions({
    String? userUuid,
    int limit = 50,
  }) async {
    print('📡 getAllSessions called with userUuid: $userUuid');
    return getSessions(userUuid: userUuid);
  }

  /// ✅ NEW: Get session dates only (for local streak calculation)
  Future<List<String>> getSessionDates(String userUuid) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/live_sessions?user_uuid=eq.$userUuid&select=created_at&order=created_at.desc',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map<String>((e) => e['created_at'] as String).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error fetching session dates: $e');
      return [];
    }
  }

  // ============================================================================
  // ACHIEVEMENT SYSTEM - NEW METHODS
  // ============================================================================

  /// Get user's streak (current and longest)
  Future<Map<String, int>> getUserStreak(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'calculate_user_streak',
        params: {'p_user_id': userId},
      );

      if (response != null && response is List && response.isNotEmpty) {
        return {
          'current_streak': response[0]['current_streak'] ?? 0,
          'longest_streak': response[0]['longest_streak'] ?? 0,
        };
      }
      return {'current_streak': 0, 'longest_streak': 0};
    } catch (e) {
      print('❌ Error getting user streak: $e');
      return {'current_streak': 0, 'longest_streak': 0};
    }
  }

  /// Get user's stats from user_profiles
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/user_profiles?id=eq.$userId&select=total_sessions,total_time_seconds,total_ayahs_read',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return data[0] as Map<String, dynamic>;
        }
      }
      return {
        'total_sessions': 0,
        'total_time_seconds': 0,
        'total_ayahs_read': 0,
      };
    } catch (e) {
      print('❌ Error getting user stats: $e');
      return {
        'total_sessions': 0,
        'total_time_seconds': 0,
        'total_ayahs_read': 0,
      };
    }
  }

  /// Get all available achievements
  Future<List<Map<String, dynamic>>> getAllAchievements() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/achievements?is_active=eq.true&order=sort_order',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('❌ Error getting all achievements: $e');
      return [];
    }
  }

  /// Get user's earned achievements
  Future<List<Map<String, dynamic>>> getUserAchievements(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/user_achievements?user_id=eq.$userId&select=*,achievements(*)',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('❌ Error getting user achievements: $e');
      return [];
    }
  }

  /// Check and grant new achievements (returns newly earned ones)
  Future<List<Map<String, dynamic>>> checkNewAchievements(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'check_and_grant_achievements',
        params: {'p_user_id': userId},
      );

      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      print('❌ Error checking achievements: $e');
      return [];
    }
  }

  /// Get user's subscription plan
  Future<String> getUserSubscriptionPlan(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/subscriptions?user_id=eq.$userId&select=plan&limit=1',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return data[0]['plan'] ?? 'free';
        }
      }
      return 'free';
    } catch (e) {
      print('❌ Error getting subscription: $e');
      return 'free';
    }
  }

  /// ✅ NEW: Update user's subscription plan (after successful transaction)
  /// Upserts the subscription record - creates if not exists, updates if exists
  Future<bool> updateUserSubscriptionPlan(String userId, String plan) async {
    try {
      print('📝 Updating subscription for user $userId to: $plan');

      // Check if subscription exists
      final checkResponse = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/subscriptions?user_id=eq.$userId&select=id',
        ),
        headers: _headers,
      );

      final exists =
          checkResponse.statusCode == 200 &&
          (jsonDecode(checkResponse.body) as List).isNotEmpty;

      if (exists) {
        // Update existing subscription
        final response = await http.patch(
          Uri.parse('$supabaseUrl/rest/v1/subscriptions?user_id=eq.$userId'),
          headers: {
            ..._headers,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: jsonEncode({
            'plan': plan,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          print('✅ Subscription updated successfully');
          return true;
        } else {
          print(
            '❌ Failed to update subscription: ${response.statusCode} - ${response.body}',
          );
          return false;
        }
      } else {
        // Insert new subscription
        final response = await http.post(
          Uri.parse('$supabaseUrl/rest/v1/subscriptions'),
          headers: {
            ..._headers,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: jsonEncode({
            'user_id': userId,
            'plan': plan,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          print('✅ Subscription created successfully');
          return true;
        } else {
          print(
            '❌ Failed to create subscription: ${response.statusCode} - ${response.body}',
          );
          return false;
        }
      }
    } catch (e) {
      print('❌ Error updating subscription: $e');
      return false;
    }
  }

  /// Get user's daily goal
  Future<Map<String, dynamic>?> getUserGoal(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/user_goals?user_id=eq.$userId&is_active=eq.true&limit=1',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return data[0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting user goal: $e');
      return null;
    }
  }

  /// Set user's daily goal
  Future<bool> setUserGoal(
    String userId,
    String goalType,
    int targetValue,
  ) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // 1. Upsert Master Goal Setting
      // Constraint: user_goals_user_id_key (user_id)
      await Supabase.instance.client.from('user_goals').upsert({
        'user_id': userId,
        'goal_type': goalType,
        'target_value': targetValue,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // 2. Upsert Today's Progress Snapshot
      // Constraint: daily_goal_progress_user_id_goal_date_key (user_id, goal_date)
      await Supabase.instance.client.from('daily_goal_progress').upsert({
        'user_id': userId,
        'goal_date': today,
        'goal_type': goalType,
        'target_value': targetValue,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,goal_date');

      return true;
    } catch (e) {
      print('❌ Error setting user goal: $e');
      return false;
    }
  }

  /// Get today's goal progress
  Future<Map<String, dynamic>?> getDailyGoalProgress(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/daily_goal_progress?user_id=eq.$userId&goal_date=eq.$today&limit=1',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return data[0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting daily goal progress: $e');
      return null;
    }
  }

  // ============================================================================
  // ACTIVITY PAGE - OPTIMIZED (SINGLE CALL)
  // ============================================================================

  /// Get ALL activity page data in ONE call (optimized)
  /// Returns: chart_data, stats (per period), badges, pages_data
  Future<Map<String, dynamic>?> getActivityPageData(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_activity_page_data',
        params: {'p_user_id': userId},
      );

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      print('❌ Error getting activity page data: $e');
      return null;
    }
  }

  // ============================================================================
  // COMPLETION PAGE - OPTIMIZED (SINGLE CALL)
  // ============================================================================

  /// Get ALL completion data in ONE call (fastest)
  /// Returns: progress (per surah), last_read, stats
  Future<Map<String, dynamic>?> getCompletionData(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_completion_data',
        params: {'p_user_id': userId},
      );

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      print('❌ Error getting completion data: $e');
      return null;
    }
  }

  // ============================================================================
  // ACHIEVEMENTS PAGE - OPTIMIZED (SINGLE CALL)
  // ============================================================================

  /// Get ALL achievements data in ONE call
  /// Returns: latest_badge, earned_badges, remaining_badges, stats
  Future<Map<String, dynamic>?> getAchievementsData(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_achievements_data',
        params: {'p_user_id': userId},
      );

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      print('❌ Error getting achievements data: $e');
      return null;
    }
  }

  // ============================================================================
  // HOME PAGE - OPTIMIZED (SINGLE CALL)
  // ============================================================================

  /// Get ALL home page data in ONE call (lightweight)
  /// Returns: today_goal, recent_badges, streak, stats, badges_count
  Future<Map<String, dynamic>?> getHomePageData(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_home_page_data',
        params: {'p_user_id': userId},
      );

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      print('❌ Error getting home page data: $e');
      return null;
    }
  }
}
