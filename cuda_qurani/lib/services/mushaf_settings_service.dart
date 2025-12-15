// lib/services/mushaf_settings_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../core/enums/mushaf_layout.dart';

class MushafSettingsService {
  static const String _keyMushafLayout = 'mushaf_layout';
  
  static final MushafSettingsService _instance = MushafSettingsService._internal();
  factory MushafSettingsService() => _instance;
  MushafSettingsService._internal();

  SharedPreferences? _prefs;

  /// Initialize service (call once at app startup)
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get current mushaf layout
  Future<MushafLayout> getMushafLayout() async {
    await initialize();
    final value = _prefs!.getString(_keyMushafLayout) ?? 'qpc';
    return MushafLayoutExtension.fromString(value);
  }

  /// Set mushaf layout
  Future<void> setMushafLayout(MushafLayout layout) async {
    await initialize();
    await _prefs!.setString(_keyMushafLayout, layout.toStringValue());
    print('✅ Mushaf layout saved: ${layout.displayName}');
  }
}