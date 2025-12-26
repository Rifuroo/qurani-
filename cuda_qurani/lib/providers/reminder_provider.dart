import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';
import '../core/services/language_service.dart';

class ReminderProvider extends ChangeNotifier {
  static const String _streakReminderKey = 'streak_reminder_enabled';
  
  bool _streakReminderEnabled = false;
  final NotificationService _notificationService = NotificationService();

  bool get streakReminderEnabled => _streakReminderEnabled;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _streakReminderEnabled = prefs.getBool(_streakReminderKey) ?? false;
    
    await _notificationService.initialize();
    
    // Sync FCM token if logged in
    final lang = LanguageService().currentLanguage;
    await _syncFCMToken(languageCode: lang, notificationEnabled: _streakReminderEnabled);

    // Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _syncFCMToken(newToken: token);
    });

    // Listen to auth state changes (login/logout)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        print('🔑 User signed in, syncing FCM token...');
        final lang = LanguageService().currentLanguage;
        _syncFCMToken(languageCode: lang, notificationEnabled: _streakReminderEnabled);
      }
    });
    
    notifyListeners();
  }

  Future<void> _syncFCMToken({String? newToken, String? languageCode, bool? notificationEnabled}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final token = newToken ?? await _notificationService.getFCMToken();
      if (token == null) return;

      print('🔄 Syncing FCM Token for user ${user.id} (Lang: $languageCode, Enabled: $notificationEnabled)...');

      final data = <String, dynamic>{
        'user_id': user.id,
        'fcm_token': token,
        'device_type': defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Only update language_code if provided
      if (languageCode != null) {
        data['language_code'] = languageCode;
      }
      
      // Only update notification_enabled if provided
      if (notificationEnabled != null) {
        data['notification_enabled'] = notificationEnabled;
      }

      await Supabase.instance.client.from('user_fcm_tokens').upsert(
        data,
        onConflict: 'fcm_token',
      );
      
      print('✅ FCM Token synced successfully');
    } catch (e) {
      print('❌ Error syncing FCM token: $e');
    }
  }

  Future<void> toggleStreakReminder(bool value) async {
    _streakReminderEnabled = value;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_streakReminderKey, value);

    final lang = LanguageService().currentLanguage;

    if (value) {
      await _notificationService.initialize();
      await _notificationService.requestPermissions();
    }
    
    // Sync the notification_enabled status to database
    await _syncFCMToken(languageCode: lang, notificationEnabled: value);

    notifyListeners();
  }
  
  Future<bool> requestPermissions() async {
    await _notificationService.initialize();
    return await _notificationService.requestPermissions();
  }

  /// Call this method when user changes language in settings
  Future<void> syncLanguagePreference(String languageCode) async {
    print('🌐 Language changed to: $languageCode, syncing to server...');
    await _syncFCMToken(languageCode: languageCode);
  }

}
