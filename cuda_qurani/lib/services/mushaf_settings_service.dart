import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/enums/mushaf_layout.dart';

class MushafSettingsService extends ChangeNotifier {
  static const String _keyMushafLayout = 'mushaf_layout';
  static const String _keyShowTajweedColors = 'show_tajweed_colors';
  static const String _keyHighlightMistakeHistory = 'highlight_mistake_history';
  static const String _keyColorSimilarPhrases = 'color_similar_phrases';
  static const String _keyHideUnreadAyat = 'hide_unread_ayat';
  static const String _keyHideVerseMarkers = 'hide_verse_markers';

  static final MushafSettingsService _instance =
      MushafSettingsService._internal();
  factory MushafSettingsService() => _instance;
  MushafSettingsService._internal();

  SharedPreferences? _prefs;

  /// Initialize service (call once at app startup)
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Generic getter for boolean settings
  bool _getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  /// Generic setter for boolean settings
  Future<void> _setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
    notifyListeners();
  }

  // Getters
  bool get showTajweedColors => _getBool(_keyShowTajweedColors);
  bool get highlightMistakeHistory => _getBool(_keyHighlightMistakeHistory);
  bool get colorSimilarPhrases => _getBool(_keyColorSimilarPhrases);
  bool get hideUnreadAyat => _getBool(_keyHideUnreadAyat, defaultValue: true);
  bool get hideVerseMarkers => _getBool(_keyHideVerseMarkers);

  // Setters
  Future<void> setShowTajweedColors(bool value) =>
      _setBool(_keyShowTajweedColors, value);
  Future<void> setHighlightMistakeHistory(bool value) =>
      _setBool(_keyHighlightMistakeHistory, value);
  Future<void> setColorSimilarPhrases(bool value) =>
      _setBool(_keyColorSimilarPhrases, value);
  Future<void> setHideUnreadAyat(bool value) =>
      _setBool(_keyHideUnreadAyat, value);
  Future<void> setHideVerseMarkers(bool value) =>
      _setBool(_keyHideVerseMarkers, value);

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
    notifyListeners();
  }
}