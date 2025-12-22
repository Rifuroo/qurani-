// lib\screens\main\stt\controllers\stt_controller.dart

import 'dart:async';
import 'dart:io';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/models/playback_settings_model.dart';
import 'package:cuda_qurani/models/quran_models.dart';
import 'package:cuda_qurani/screens/main/home/services/juz_service.dart';
import 'package:cuda_qurani/screens/main/stt/database/db_helper.dart';
import 'package:cuda_qurani/services/global_ayat_services.dart';
import 'package:cuda_qurani/services/listening_audio_services.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/services/reciter_database_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../data/models.dart' hide TartibStatus;
import '../services/quran_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'package:cuda_qurani/services/audio_service.dart';
import 'package:cuda_qurani/services/websocket_service.dart';
import 'package:cuda_qurani/services/supabase_service.dart'; // ? NEW: For session management
import 'package:cuda_qurani/services/auth_service.dart'; // ? NEW: For user UUID
import 'package:cuda_qurani/config/app_config.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/core/widgets/achievement_popup.dart'; // ? NEW: Achievement popup
import 'package:cuda_qurani/providers/premium_provider.dart'; // ✅ NEW: Premium gating
import 'package:cuda_qurani/models/premium_features.dart'; // ✅ NEW: Premium features

class SttController with ChangeNotifier {
  final int? suratId;
  final int? pageId;
  final int? juzId;
  final bool isFromHistory;
  final Map<String, dynamic>? initialWordStatusMap;
  final String? resumeSessionId; // ? NEW: Continue existing session
  final ValueNotifier<PageDisplayData> appBarNotifier = ValueNotifier(
    PageDisplayData.initial(),
  );
  int? _determinedSurahId;

  MushafLayout _mushafLayout = MushafLayout.qpc;
  MushafLayout get mushafLayout => _mushafLayout;

  // ✅ TAMBAHKAN getter untuk total pages (dynamic based on layout)
  int get totalPages => _mushafLayout.totalPages;

  SttController({
    this.suratId,
    this.pageId,
    this.juzId,
    this.isFromHistory = false,
    this.initialWordStatusMap,
    this.resumeSessionId, // ? NEW
  }) {
    print(
      '🗃️ SttController: CONSTRUCTOR - surah:$suratId page:$pageId juz:$juzId',
    );
    _webSocketService = WebSocketService(serverUrl: AppConfig.websocketUrl);
    print(
      '🔧 SttController: WebSocketService initialized, calling _initializeWebSocket()...',
    );
    try {
      _initializeWebSocket();

      // ? NEW: Apply initial word status map immediately (for resume from history)
      if (initialWordStatusMap != null &&
          initialWordStatusMap!.isNotEmpty &&
          suratId != null) {
        _applyInitialWordStatusMap(suratId!, initialWordStatusMap!);
      }
      print('✅ SttController: _initializeWebSocket() completed');
    } catch (e, stack) {
      print('❌ SttController: _initializeWebSocket() FAILED: $e');
      print('Stack trace: $stack');
    }
  }

  Future<void> switchMushafLayout(MushafLayout newLayout) async {
    if (_mushafLayout == newLayout) return;

    appLogger.log(
      'LAYOUT_SWITCH',
      'Switching: ${_mushafLayout.displayName} → ${newLayout.displayName}',
    );

    // ✅ CRITICAL: Stop ALL background tasks FIRST
    print('[LAYOUT_SWITCH] 🛑 Stopping background tasks...');
    _isPreloadingPages = false; // Stop preloading immediately
    await Future.delayed(const Duration(milliseconds: 200)); // Let tasks finish

    // ✅ STEP 1: Close ALL databases
    print('[LAYOUT_SWITCH] 🔒 Closing all databases...');
    await DBHelper.closeAllDatabases();
    await LocalDatabaseService.closePageDatabase();
    print('[LAYOUT_SWITCH] ✅ All databases closed');

    // ✅ STEP 2: Wait for file system
    await Future.delayed(const Duration(milliseconds: 200));

    // ✅ STEP 3: Update service first
    await _sqliteService.setMushafLayout(newLayout);

    // ✅ STEP 4: Update local state
    _mushafLayout = newLayout;

    // ✅ STEP 5: Clear ALL caches
    pageCache.clear();
    _sqliteService.clearPageCache();
    _lastLoadedAyatsPage = null;
    _lastPreloadedPage = null;

    // ✅ STEP 6: Adjust current page if exceeds new layout's max
    if (_currentPage > newLayout.totalPages) {
      _currentPage = newLayout.totalPages;
    }
    if (_listViewCurrentPage > newLayout.totalPages) {
      _listViewCurrentPage = newLayout.totalPages;
    }

    // ✅ STEP 7: Reload current page data
    _isDataLoaded = false;
    await _loadSinglePageData(_currentPage);

    // ✅ STEP 8: Notify listeners to update UI
    notifyListeners();

    appLogger.log(
      'LAYOUT_SWITCH',
      '✅ Layout switched to ${newLayout.displayName} (${newLayout.totalPages} pages)',
    );
  }

  // ✅ NEW: Apply word status map from Supabase data
  void _applyInitialWordStatusMap(int surahId, Map<String, dynamic> wordMap) {
    print('?? Applying initial word status map for surah $surahId');
    print('   Input data: $wordMap');

    _wordStatusMap.clear();
    wordMap.forEach((ayahKey, wordData) {
      final int ayahNum = int.tryParse(ayahKey) ?? -1;
      if (ayahNum > 0 && wordData is Map) {
        final key = _wordKey(surahId, ayahNum);
        _wordStatusMap[key] = {};
        (wordData as Map<String, dynamic>).forEach((wordIndexKey, status) {
          final int wordIndex = int.tryParse(wordIndexKey) ?? -1;
          if (wordIndex >= 0) {
            _wordStatusMap[key]![wordIndex] = _mapWordStatus(status.toString());
          }
        });
      }
    });

    print('? Applied word status: ${_wordStatusMap.length} ayahs colored');
    print('   Word status map: $_wordStatusMap');
    notifyListeners();
  }

  // Services
  final QuranService _sqliteService = QuranService();
  final AppLogger appLogger = AppLogger();
  final SupabaseService _supabaseService = SupabaseService(); // ? NEW
  final AuthService _authService = AuthService(); // ? NEW

  // ? NEW: Resumable session detection
  bool _hasResumableSession = false;
  bool get hasResumableSession => _hasResumableSession;

  // Core State
  bool _isLoading = true;
  String? _errorMessage = '';
  List<AyatData> _ayatList = [];
  int _currentAyatIndex = 0;
  String _suratNameSimple = '';
  String _suratVersesCount = '';
  DateTime? _sessionStartTime;
  Map<int, AyatProgress> _ayatProgress = {};

  // UI State
  bool _isUIVisible = true;
  bool _isQuranMode = true;
  bool _hideUnreadAyat = false;
  bool _showLogs = false;
  int _currentPage = 1;
  int _listViewCurrentPage = 1;
  bool _isDataLoaded = false; // Prevent unnecessary reloads
  bool _isDisposed =
      false; // FIX: Track disposal state to prevent background task errors
  List<AyatData> _currentPageAyats = [];
  final ScrollController _scrollController = ScrollController();

  // Backend Integration - Recording & WebSocket
  final AudioService _audioService = AudioService();
  late final WebSocketService _webSocketService;
  bool _isRecording = false;
  bool _isConnected = false;
  String? _sessionId;
  int _expectedAyah = 1;
  final Map<int, TartibStatus> _tartibStatus = {};
  // ? FIX: Key = "surahId:ayahNumber" untuk hindari collision antar surah
  final Map<String, Map<int, WordStatus>> _wordStatusMap = {};
  List<WordFeedback> _currentWords =
      []; // ✅ ADD: Store current words for realtime updates
  StreamSubscription? _wsSubscription;
  StreamSubscription? _connectionSubscription;

  // ? NEW: Achievement system
  List<Map<String, dynamic>> _newlyEarnedAchievements = [];
  List<Map<String, dynamic>> get newlyEarnedAchievements =>
      _newlyEarnedAchievements;

  // ? NEW: Rate Limit System
  Map<String, dynamic>? _rateLimit;
  bool _isRateLimitExceeded = false;
  String _rateLimitPlan = 'free';

  Map<String, dynamic>? get rateLimit => _rateLimit;
  bool get isRateLimitExceeded => _isRateLimitExceeded;
  String get rateLimitPlan => _rateLimitPlan;
  int get rateLimitCurrent => _rateLimit?['current'] ?? 0;
  int get rateLimitMax => _rateLimit?['limit'] ?? 3;
  int get rateLimitRemaining => _rateLimit?['remaining'] ?? 0;
  int get rateLimitResetSeconds => _rateLimit?['reset_in_seconds'] ?? 0;

  String get rateLimitResetFormatted {
    final seconds = rateLimitResetSeconds;
    if (seconds <= 0) return '';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours jam $mins menit';
    }
    return '$mins menit';
  }

  // ? NEW: Duration Limit System
  String _durationWarning = '';
  bool _isDurationWarningActive = false;
  bool _isDurationLimitExceeded = false;
  Map<String, dynamic>? _durationLimit;

  String get durationWarning => _durationWarning;
  bool get isDurationWarningActive => _isDurationWarningActive;
  bool get isDurationLimitExceeded => _isDurationLimitExceeded;
  Map<String, dynamic>? get durationLimit => _durationLimit;
  int get durationMaxMinutes => _durationLimit?['max_minutes'] ?? 15;
  bool get isDurationUnlimited => _durationLimit?['is_unlimited'] ?? false;

  // // ?? NEW: Surah Mismatch Detection
  // // bool _isSurahMismatch = false;
  // String? _surahMismatchWarning;
  // int? _detectedMismatchSurah;
  // String? _detectedMismatchSurahName;

  // // bool get isSurahMismatch => _isSurahMismatch;
  // String? get surahMismatchWarning => _surahMismatchWarning;
  // int? get detectedMismatchSurah => _detectedMismatchSurah;
  // String? get detectedMismatchSurahName => _detectedMismatchSurahName;

  // Getters for recording state
  bool get isRecording => _isRecording;
  bool get isConnected => _isConnected;

  // ✅ NEW: Direct access to service connection state (always fresh)
  bool get isServiceConnected => _webSocketService.isConnected;

  int get expectedAyah => _expectedAyah;
  Map<int, TartibStatus> get tartibStatus => _tartibStatus;
  // ? FIX: Key = "surahId:ayahNumber"
  Map<String, Map<int, WordStatus>> get wordStatusMap => _wordStatusMap;

  // ? Helper: Generate word status key
  String _wordKey(int surahId, int ayahNumber) => '$surahId:$ayahNumber';

  /// 🆕 NEW: Map audio segment word_index (QPC-based) to actual layout word_index
  /// 🆕 NEW: Map audio segment word_index (QPC-based) to actual layout word_index
  int _mapAudioIndexToLayoutIndex(
    int audioWordIndex,
    int surahId,
    int ayahNumber,
  ) {
    // For QPC layout, no mapping needed (1:1)
    if (_mushafLayout == MushafLayout.qpc) {
      return audioWordIndex;
    }

    // ✅ CRITICAL FIX: For IndoPak, use _currentPageAyats (most reliable source)
    // _ayatList might be filtered or incomplete, but _currentPageAyats has full page data
    final ayat = _currentPageAyats.firstWhere(
      (a) => a.surah_id == surahId && a.ayah == ayahNumber,
      orElse: () {
        print(
          '⚠️ MAPPING FALLBACK: Ayah $surahId:$ayahNumber not in _currentPageAyats, trying _ayatList',
        );
        return _ayatList.firstWhere(
          (a) => a.surah_id == surahId && a.ayah == ayahNumber,
          orElse: () {
            print(
              '❌ MAPPING ERROR: Ayah $surahId:$ayahNumber not found anywhere!',
            );
            return _ayatList.isNotEmpty
                ? _ayatList.first
                : _currentPageAyats.first;
          },
        );
      },
    );

    final indopakWordCount = ayat.words.length;

    // ✅ STRATEGY: Proportional mapping based on word count ratio
    // Since we don't have QPC word count in memory, we'll use a heuristic:
    // If audio index exceeds IndoPak count, it means QPC has more words

    if (audioWordIndex < indopakWordCount) {
      // Direct mapping possible (same or audio has fewer words)
      print(
        '🗺️ MAPPING: Direct map $audioWordIndex → $audioWordIndex (within bounds)',
      );
      return audioWordIndex;
    }

    // Audio index exceeds IndoPak count - need proportional mapping
    // Estimate QPC word count from audio index + safety margin
    final estimatedQpcCount = audioWordIndex + 1;
    final ratio = indopakWordCount / estimatedQpcCount.toDouble();
    final mappedIndex = (audioWordIndex * ratio).floor();
    final clampedIndex = mappedIndex.clamp(0, indopakWordCount - 1);

    print(
      '🗺️ MAPPING: Proportional $audioWordIndex → $clampedIndex (IndoPak: $indopakWordCount words, estimated QPC: $estimatedQpcCount)',
    );

    return clampedIndex;
  }

  // ? Helper: Get word status for specific surah:ayah:word
  WordStatus? getWordStatus(int surahId, int ayahNumber, int wordIndex) {
    final key = _wordKey(surahId, ayahNumber);
    final wordMap = _wordStatusMap[key];

    if (wordMap == null) {
      print('?? getWordStatus: No word map for $surahId:$ayahNumber');
      return null;
    }

    // ? CRITICAL: Return null for invalid index (prevent RangeError)
    if (wordIndex < 0 || !wordMap.containsKey(wordIndex)) {
      print(
        '?? getWordStatus: Invalid wordIndex $wordIndex for $surahId:$ayahNumber (has ${wordMap.length} words)',
      );
      return null;
    }

    return wordMap[wordIndex];
  }

  List<WordFeedback> get currentWords =>
      _currentWords; // ✅ ADD: Getter for currentWords

  // Page Pre-loading Cache
  final Map<int, List<MushafPageLine>> pageCache = {};
  final MetadataCacheService _metadataCache = MetadataCacheService();

  bool _isPreloadingPages = false;
  // Tambahkan property ini setelah deklarasi _isPreloadingPages
  bool _stopPreloading = false; // ✅ NEW: Flag to stop background tasks

  // Getters for UI
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AyatData> get ayatList => _ayatList;
  int get currentAyatIndex => _currentAyatIndex;
  // FIX: Check both list not empty AND index is valid (>= 0)
  int get currentAyatNumber =>
      _ayatList.isNotEmpty &&
          _currentAyatIndex >= 0 &&
          _currentAyatIndex < _ayatList.length
      ? _ayatList[_currentAyatIndex].ayah
      : 1;
  String get suratNameSimple => _suratNameSimple;
  String get suratVersesCount => _suratVersesCount;
  DateTime? get sessionStartTime => _sessionStartTime;
  Map<int, AyatProgress> get ayatProgress => _ayatProgress;
  bool get isUIVisible => _isUIVisible;
  bool get isQuranMode => _isQuranMode;
  bool get hideUnreadAyat => _hideUnreadAyat;
  bool get showLogs => _showLogs;
  int get currentPage => _currentPage;
  List<AyatData> get currentPageAyats => _currentPageAyats;
  ScrollController get scrollController => _scrollController;
  int get listViewCurrentPage => _listViewCurrentPage;

  // Listening
  bool _isListeningMode = false;
  PlaybackSettings? _playbackSettings;
  ListeningAudioService? _listeningAudioService;
  StreamSubscription? _verseChangeSubscription;
  StreamSubscription? _wordHighlightSubscription;
  bool get isListeningMode => _isListeningMode;
  PlaybackSettings? get playbackSettings => _playbackSettings;
  ListeningAudioService? get listeningAudioService => _listeningAudioService;
  // ===== INITIALIZATION =====
  Future<void> initializeApp() async {
    appLogger.log('APP_INIT', 'Starting OPTIMIZED page-based initialization');
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    // ? NEW: Check for resumable session
    await _checkForResumableSession();

    try {
      await _sqliteService.initialize();

      _mushafLayout = _sqliteService.currentLayout;
      appLogger.log(
        'APP_INIT',
        'Loaded layout: ${_mushafLayout.displayName} (${_mushafLayout.totalPages} pages)',
      );

      // ðŸš€ STEP 1: Determine target page FIRST
      int targetPage = await _determineTargetPage();
      _currentPage = targetPage;
      _listViewCurrentPage = targetPage;
      _isDataLoaded = false;

      appLogger.log('APP_INIT', 'Target page determined: $targetPage');

      // 🚀 STEP 2: Load ONLY that page (minimal data)
      await _loadSinglePageData(targetPage);

      _sessionStartTime = DateTime.now();

      _isDataLoaded = true;

      // Mark as ready INSTANTLY
      _isLoading = false;
      notifyListeners();

      appLogger.log(
        'APP_INIT',
        'App ready - Page $targetPage loaded instantly',
      );

      // 🚀 STEP 3: Background tasks
      Future.microtask(() {
        if (_isQuranMode) {
          _preloadAdjacentPagesAggressively();
        }
      });
    } catch (e) {
      final errorString = 'Failed to initialize: $e';
      appLogger.log('APP_INIT_ERROR', errorString);
      _errorMessage = errorString;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startListening(PlaybackSettings settings) async {
    appLogger.log(
      'LISTENING',
      'Starting listening mode with settings: $settings',
    );

    print('?? Listening Mode: Passive learning (no detection)');

    try {
      // ?? Clear previous state
      // ✅ CRITICAL FIX: Stop any existing listening session first
      if (_isListeningMode && _listeningAudioService != null) {
        print(
          '🛑 Stopping existing listening session before starting new one...',
        );
        await stopListening();
        // Wait a bit to ensure cleanup completes
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 🧹 Clear previous state
      _tartibStatus.clear();
      _wordStatusMap.clear();
      _expectedAyah = settings.startVerse;
      _sessionId = null;
      _errorMessage = '';

      // ? NEW: AUTO-NAVIGATE TO TARGET PAGE (OPTIMIZED)
      print('?? Checking if navigation needed...');
      final targetPage = await LocalDatabaseService.getPageNumber(
        settings.startSurahId,
        settings.startVerse,
      );

      print('   Current page: $_currentPage');
      print(
        '   Target page: $targetPage (Surah ${settings.startSurahId}:${settings.startVerse})',
      );

      if (_currentPage != targetPage) {
        print(
          '?? Auto-navigating from page $_currentPage to page $targetPage...',
        );

        // ? FIX: Use lightweight navigation (NO full reload)
        await _navigateToPageForListening(targetPage, settings.startSurahId);

        print('? Navigation complete, now at page $_currentPage');
      } else {
        print('? Already at target page $targetPage, no navigation needed');
      }

      // ?? Initialize listening audio service
      _listeningAudioService = ListeningAudioService();
      await _listeningAudioService!.initialize(settings, settings.reciter);

      _playbackSettings = settings;
      _isListeningMode = true;

      print('?? Starting Listening Mode (Passive - No Backend Detection)');

      // ?? Subscribe to verse changes
      // ?? Subscribe to verse changes
      _verseChangeSubscription = _listeningAudioService!.currentVerseStream?.listen((
        verse,
      ) async {
        print(
          '?? [VERSE CHANGE] Now playing: ${verse.surahId}:${verse.verseNumber}',
        );

        if (verse.surahId == -999 && verse.verseNumber == -999) {
          print('?? Listening completed - resetting state');
          _handleListeningCompletion();
          return;
        }

        // ? Check if verse is on different page
        try {
          final targetPage = await LocalDatabaseService.getPageNumber(
            verse.surahId,
            verse.verseNumber,
          );

          if (targetPage != _currentPage) {
            print(
              '?? Auto-navigating: Page $_currentPage ? $targetPage (for ${verse.surahId}:${verse.verseNumber})',
            );
            await _navigateToPageForListening(targetPage, verse.surahId);
            print('? Navigation complete, page now: $_currentPage');
          }
        } catch (e) {
          print(
            '?? Failed to get page number for ${verse.surahId}:${verse.verseNumber}: $e',
          );
        }

        // ? CRITICAL: Clear ALL highlights before updating index
        final allKeys = _wordStatusMap.keys.toList();
        for (final key in allKeys) {
          _wordStatusMap[key]?.clear();
        }
        print('   ?? Cleared all highlights (${allKeys.length} ayahs)');

        // ? CRITICAL: Update _currentAyatIndex using _currentPageAyats
        final ayatIndex = _currentPageAyats.indexWhere(
          (a) => a.surah_id == verse.surahId && a.ayah == verse.verseNumber,
        );

        if (ayatIndex >= 0) {
          _currentAyatIndex = ayatIndex;

          final currentAyat = _currentPageAyats[ayatIndex];
          print(
            '? [VERSE CHANGE] Updated index: $ayatIndex ? ${verse.surahId}:${verse.verseNumber} (${currentAyat.words.length} words)',
          );

          // ? CRITICAL: Initialize word status map for NEW ayat
          final currentKey = _wordKey(verse.surahId, verse.verseNumber);
          _wordStatusMap[currentKey] = {};
          for (int i = 0; i < currentAyat.words.length; i++) {
            _wordStatusMap[currentKey]![i] = WordStatus.pending;
          }
          print(
            '   ?? Initialized ${currentAyat.words.length} words for highlighting',
          );

          notifyListeners();
        } else {
          print(
            '?? CRITICAL: Ayat ${verse.surahId}:${verse.verseNumber} NOT FOUND!',
          );
          print(
            '   Available: ${_currentPageAyats.map((a) => "${a.surah_id}:${a.ayah}").join(", ")}',
          );
        }
      });

      // ?? Subscribe to word highlights
      _wordHighlightSubscription = _listeningAudioService!.wordHighlightStream?.listen((
        audioWordIndex, // 🔴 RENAMED: ini dari audio segments (QPC-based)
      ) {
        print(
          '🎧 Word highlight event received (audio index): $audioWordIndex',
        );

        // ? Handle reset signal (-1)
        if (audioWordIndex == -1) {
          print('🔄 Reset signal received, clearing highlights');

          // Clear ALL word status maps to prevent stuck highlights
          final allKeys = _wordStatusMap.keys.toList();
          for (final key in allKeys) {
            _wordStatusMap[key]?.clear();
          }
          print('   Cleared all word highlights (${allKeys.length} ayahs)');
          notifyListeners();
          return;
        }

        // ? CRITICAL FIX: Find current ayat from currentPageAyats using verse change state
        AyatData? currentAyat;

        // Use _currentAyatIndex which is updated by verse change subscription
        if (_currentAyatIndex >= 0 &&
            _currentAyatIndex < _currentPageAyats.length) {
          currentAyat = _currentPageAyats[_currentAyatIndex];
          print(
            '   Current ayat: ${currentAyat.surah_id}:${currentAyat.ayah} (${currentAyat.words.length} words)',
          );
        } else {
          print(
            '❌ Invalid _currentAyatIndex: $_currentAyatIndex (pageAyats: ${_currentPageAyats.length})',
          );
          return; // ? EXIT early if invalid index
        }

        if (currentAyat != null) {
          // 🆕 MAP audio word index to layout-specific word index
          final layoutWordIndex = _mapAudioIndexToLayoutIndex(
            audioWordIndex,
            currentAyat.surah_id,
            currentAyat.ayah,
          );

          final currentKey = _wordKey(currentAyat.surah_id, currentAyat.ayah);

          // ✅ ADD: Enhanced debugging untuk tracking mapping
          print(
            '🗺️ WORD INDEX MAPPING: audio=$audioWordIndex → layout=$layoutWordIndex (${_mushafLayout.displayName})',
          );
          print(
            '   Ayat: ${currentAyat.surah_id}:${currentAyat.ayah}, Words in layout: ${currentAyat.words.length}',
          );
          print(
            '   Current _wordStatusMap[$currentKey] before update: ${_wordStatusMap[currentKey]}',
          );

          print(
            '🗺️ WORD INDEX MAPPING: audio=$audioWordIndex → layout=$layoutWordIndex (${_mushafLayout.displayName})',
          );
          final words = currentAyat.words;

          // ? CRITICAL: Validate layoutWordIndex before accessing array
          if (layoutWordIndex < 0 || layoutWordIndex >= words.length) {
            print(
              '❌ Invalid layoutWordIndex: $layoutWordIndex for ayat ${currentAyat.surah_id}:${currentAyat.ayah} (has ${words.length} words)',
            );
            return; // ? EXIT early if invalid word index
          }

          if (!_wordStatusMap.containsKey(currentKey)) {
            _wordStatusMap[currentKey] = {};
          }

          // ? CRITICAL: Clear ALL other ayahs' highlights first (prevent stuck colors)
          final allKeys = _wordStatusMap.keys
              .where((k) => k != currentKey)
              .toList();
          for (final key in allKeys) {
            _wordStatusMap[key]?.clear();
          }

          // Update word status for UI - highlight ONLY current word
          // ✅ CRITICAL FIX: Update word status using layoutWordIndex (not loop variable i)
          // Initialize all words as pending first
          for (int i = 0; i < words.length; i++) {
            _wordStatusMap[currentKey]![i] = WordStatus.pending;
          }

          // Then set ONLY the mapped word as processing
          if (layoutWordIndex >= 0 && layoutWordIndex < words.length) {
            _wordStatusMap[currentKey]![layoutWordIndex] =
                WordStatus.processing;
            print(
              '   ✨ Highlighted word $layoutWordIndex in ${currentAyat.surah_id}:${currentAyat.ayah}',
            );
          } else {
            print(
              '   ⚠️ Cannot highlight: layoutWordIndex $layoutWordIndex out of bounds (0-${words.length - 1})',
            );
          }

          notifyListeners();
        }
      });

      // ?? Start playback
      await _listeningAudioService!.startPlayback();

      _isRecording = true;
      _hideUnreadAyat = false;

      appLogger.log('LISTENING', 'Listening mode started successfully');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to start listening: $e';
      _isListeningMode = false;
      _isRecording = false;
      appLogger.log('LISTENING_ERROR', e.toString());
      print('? Start listening failed: $e');
      notifyListeners();
    }
  }

  /// Stop Listening Mode
  Future<void> stopListening() async {
    print('?? Manually stopping listening mode...');

    try {
      // Stop audio playback
      await _listeningAudioService?.stopPlayback();

      // Cancel subscriptions
      await _verseChangeSubscription?.cancel();
      await _wordHighlightSubscription?.cancel();

      // Dispose audio service
      _listeningAudioService?.dispose();
      _listeningAudioService = null;

      // ? FIX: Reset state properly
      _isListeningMode = false;
      _isRecording = false;
      _playbackSettings = null;

      // Clear visual states
      _tartibStatus.clear();
      _wordStatusMap.clear();

      appLogger.log('LISTENING', 'Stopped manually');
      print('? Listening mode stopped');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to stop listening: $e';
      appLogger.log('LISTENING_ERROR', e.toString());
      print('? Stop listening failed: $e');
      notifyListeners();
    }
  }

  /// ? NEW: Handle listening mode completion
  Future<void> _handleListeningCompletion() async {
    print('?? Listening session completed');

    try {
      // Stop audio playback (if not already stopped)
      await _listeningAudioService?.stopPlayback();

      // Cancel subscriptions
      await _verseChangeSubscription?.cancel();
      await _wordHighlightSubscription?.cancel();

      // Dispose audio service
      _listeningAudioService?.dispose();
      _listeningAudioService = null;

      // ? CRITICAL: Reset all state flags
      _isListeningMode = false;
      _isRecording = false;
      _playbackSettings = null;

      // Clear visual states
      _tartibStatus.clear();
      _wordStatusMap.clear();

      appLogger.log('LISTENING', 'Completed and reset');
      print('? All listening state reset');

      notifyListeners();
    } catch (e) {
      appLogger.log('LISTENING_ERROR', 'Completion error: $e');
      print('? Completion handler failed: $e');

      // ? Still reset state even if error occurs
      _isListeningMode = false;
      _isRecording = false;
      notifyListeners();
    }
  }

  /// Pause listening (pause audio, but keep WebSocket alive)
  Future<void> pauseListening() async {
    if (_listeningAudioService != null && _isListeningMode) {
      // ✅ CRITICAL: Notify listeners BEFORE await untuk UI update yang lebih cepat
      // State sudah di-update di pausePlayback() sebelum await
      notifyListeners();
      await _listeningAudioService!.pausePlayback();
      print('?? Listening paused');
      print('⏸️ Listening paused');
      // ✅ Notify lagi setelah await untuk memastikan state ter-update
      notifyListeners();
    }
  }

  /// Resume listening
  Future<void> resumeListening() async {
    if (_listeningAudioService != null && _isListeningMode) {
      // ✅ CRITICAL: Notify listeners BEFORE await untuk UI update yang lebih cepat
      // State sudah di-update di resumePlayback() sebelum await
      notifyListeners();
      await _listeningAudioService!.resumePlayback();
      print('?? Listening resumed');
      print('▶️ Listening resumed');
      // ✅ Notify lagi setelah await untuk memastikan state ter-update
      notifyListeners();
    }
  }

  // ADD NEW METHOD: Determine target page from navigation params
  Future<int> _determineTargetPage() async {
    // Priority: pageId > juzId > suratId

    if (pageId != null) {
      appLogger.log('NAV', 'Direct navigation to page $pageId');
      return pageId!;
    }

    if (juzId != null) {
      appLogger.log('NAV', 'Navigation from Juz $juzId');

      // Get juz metadata
      final juzData = await JuzService.getJuz(juzId!);
      if (juzData == null) {
        throw Exception('Juz $juzId not found');
      }

      // Parse first_verse_key (format: "surah:ayah")
      final firstVerseKey = juzData['first_verse_key'] as String;
      final parts = firstVerseKey.split(':');
      final surahNum = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);

      // Get page number for this ayah
      final page = await LocalDatabaseService.getPageNumber(surahNum, ayahNum);
      appLogger.log(
        'NAV',
        'Juz $juzId starts at page $page (${surahNum}:${ayahNum})',
      );
      return page;
    }

    if (suratId != null) {
      appLogger.log('NAV', 'Navigation from Surah $suratId');

      // Get first page of this surah
      final page = await LocalDatabaseService.getPageNumber(suratId!, 1);
      appLogger.log('NAV', 'Surah $suratId starts at page $page');
      return page;
    }

    // Fallback (should never happen due to assertion)
    return 1;
  }

  // ✅ OPTIMIZED: Use QuranService batch loading for 3-5x faster performance
  Future<void> _loadMultiplePagesParallel(List<int> pageNumbers) async {
    if (pageNumbers.isEmpty) return;

    final startTime = DateTime.now();
    appLogger.log(
      'PARALLEL_LOAD',
      'Loading ${pageNumbers.length} pages: $pageNumbers',
    );

    try {
      // STEP 1: Separate cached vs uncached pages
      final uncachedPages = <int>[];
      int cachedCount = 0;

      for (final pageNum in pageNumbers) {
        // Check SttController cache
        if (pageCache.containsKey(pageNum)) {
          cachedCount++;
          continue;
        }

        // Check QuranService cache
        final serviceCache = _sqliteService.getCachedPage(pageNum);
        if (serviceCache != null) {
          pageCache[pageNum] = serviceCache;
          cachedCount++;
          continue;
        }

        uncachedPages.add(pageNum);
      }

      if (cachedCount > 0) {
        appLogger.log(
          'PARALLEL_LOAD',
          '$cachedCount/${pageNumbers.length} pages already cached',
        );
      }

      // STEP 2: Batch load uncached pages using QuranService batch method
      if (uncachedPages.isNotEmpty) {
        final batchResults = await _sqliteService.getMushafPageLinesBatch(
          uncachedPages,
        );

        // STEP 3: Update cache with batch results
        for (final entry in batchResults.entries) {
          pageCache[entry.key] = entry.value;
        }

        final duration = DateTime.now().difference(startTime);
        appLogger.log(
          'PARALLEL_LOAD',
          '✅ Batch loaded ${batchResults.length} pages in ${duration.inMilliseconds}ms (${(duration.inMilliseconds / batchResults.length).toStringAsFixed(1)}ms/page)',
        );
      }

      // STEP 4: Notify listeners once after all updates
      if (uncachedPages.isNotEmpty) {
        notifyListeners();
      }

      final totalDuration = DateTime.now().difference(startTime);
      appLogger.log(
        'PARALLEL_LOAD',
        'Successfully cached ${pageNumbers.length} pages in ${totalDuration.inMilliseconds}ms',
      );
    } catch (e) {
      appLogger.log('PARALLEL_LOAD_ERROR', 'Batch load failed: $e');
    }
  }

  // REPLACE existing _loadSinglePageData method
  Future<void> _loadSinglePageData(int pageNumber) async {
    appLogger.log('DATA', '🚀 INSTANT LOAD: Page $pageNumber + adjacent pages');

    try {
      // ✅ STEP 1: Determine pages to load (main + 2 before + 2 after = 5 pages)
      final pagesToLoad = <int>[];

      // Add main page first (priority)
      pagesToLoad.add(pageNumber);

      // Add adjacent pages
      if (pageNumber > 1) pagesToLoad.add(pageNumber - 1);
      if (pageNumber > 2) pagesToLoad.add(pageNumber - 2);
      if (pageNumber < 604) pagesToLoad.add(pageNumber + 1);
      if (pageNumber < 603) pagesToLoad.add(pageNumber + 2);

      // ✅ STEP 2: Load all pages in PARALLEL
      await _loadMultiplePagesParallel(pagesToLoad);

      // ✅ STEP 3: Extract main page data for UI
      final pageLines = pageCache[pageNumber];
      if (pageLines == null || pageLines.isEmpty) {
        throw Exception('Main page $pageNumber failed to load');
      }

      // ✅ STEP 4: Determine and STORE surah ID from first ayah
      for (final line in pageLines) {
        if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
          final firstSegment = line.ayahSegments!.first;
          _determinedSurahId = firstSegment.surahId;

          // Get surah metadata (minimal)
          final chapter = await _sqliteService.getChapterInfo(
            _determinedSurahId!,
          );
          _suratNameSimple = chapter.nameSimple;
          _suratVersesCount = chapter.versesCount.toString();

          // Build minimal ayat list for THIS PAGE ONLY
          final Set<String> uniqueAyahs = {};
          for (final line in pageLines) {
            if (line.ayahSegments != null) {
              for (final segment in line.ayahSegments!) {
                final key = '${segment.surahId}:${segment.ayahNumber}';
                uniqueAyahs.add(key);
              }
            }
          }

          // Load only ayahs on this page
          _ayatList = [];
          for (final ayahKey in uniqueAyahs) {
            final parts = ayahKey.split(':');
            final surahId = int.parse(parts[0]);
            final ayahNum = int.parse(parts[1]);

            final ayahWords = await _sqliteService.getAyahWords(
              surahId,
              ayahNum,
              isQuranMode: true,
            );
            final juz = _sqliteService.calculateJuzAccurate(surahId, ayahNum);

            _ayatList.add(
              AyatData(
                surah_id: surahId,
                ayah: ayahNum,
                words: ayahWords,
                page: pageNumber,
                juz: juz,
                fullArabicText: ayahWords.map((w) => w.text).join(' '),
              ),
            );
          }

          // Sort by surah then ayah
          _ayatList.sort((a, b) {
            if (a.surah_id != b.surah_id)
              return a.surah_id.compareTo(b.surah_id);
            return a.ayah.compareTo(b.ayah);
          });

          // ? Simpan semua ayat page untuk UI rendering (layout mushaf)
          final allPageAyats = List<AyatData>.from(_ayatList);

          if (suratId != null && !_isListeningMode) {
            final beforeCount = _ayatList.length;
            _ayatList = _ayatList.where((a) => a.surah_id == suratId).toList();
            _determinedSurahId = suratId;
            print(
              '? PROCESSING: $beforeCount ? ${_ayatList.length} ayahs (surah $suratId only)',
            );
            print('   UI will show all ${allPageAyats.length} ayahs on page');
          }

          _currentAyatIndex = 0;

          // ? UI tetap tampilkan SEMUA ayat di page (layout mushaf lengkap)
          _currentPageAyats = allPageAyats;

          appLogger.log(
            'DATA',
            '✅ Instant load complete: ${_ayatList.length} ayahs on page $pageNumber (Surah $_determinedSurahId)',
          );
          appLogger.log(
            'DATA',
            '📦 Cache status: ${pageCache.length} pages cached (${pagesToLoad.length} just loaded)',
          );

          notifyListeners();
          return;
        }
      }

      throw Exception('No valid data on page $pageNumber');
    } catch (e) {
      appLogger.log('DATA_ERROR', 'Failed to load page $pageNumber: $e');
      rethrow;
    }
  }

  Future<void> _loadAyatData() async {
    appLogger.log('DATA', 'Loading ayat data for surah_id $suratId');
    try {
      // Use optimized batch loading
      final results = await Future.wait([
        _sqliteService.getChapterInfo(suratId!),
        _sqliteService.getSurahAyatDataOptimized(
          suratId!,
          isQuranMode: _isQuranMode,
        ),
      ]);

      final chapter = results[0] as ChapterData;
      _ayatList = results[1] as List<AyatData>;

      _suratNameSimple = chapter.nameSimple;
      _suratVersesCount = chapter.versesCount.toString();

      if (_ayatList.isNotEmpty) {
        _currentPage = _ayatList.first.page;
        // Load page data in background, don't await
        _loadCurrentPageAyats();
      }

      appLogger.log('DATA', 'Loaded ${_ayatList.length} ayat instantly');
      notifyListeners();
    } catch (e) {
      appLogger.log('DATA_ERROR', 'Failed to load ayat data - $e');
      throw Exception('Data loading failed: $e');
    }
  }

  // ? NEW: Optimized data loading that preserves page position
  Future<void> _loadAyatDataOptimized(int targetPage) async {
    appLogger.log(
      'DATA_OPTIMIZED',
      'Loading data with target page: $targetPage',
    );

    try {
      // ? FIX: Initialize with nullable type, then validate
      int? surahIdForPage;

      // Determine surah ID from target page
      if (suratId != null) {
        surahIdForPage = suratId!;
        appLogger.log(
          'DATA_OPTIMIZED',
          'Using direct suratId: $surahIdForPage',
        );
      } else if (_determinedSurahId != null) {
        surahIdForPage = _determinedSurahId!;
        appLogger.log(
          'DATA_OPTIMIZED',
          'Using determined surahId: $surahIdForPage',
        );
      } else {
        // Get surah from cached page data or database
        if (pageCache.containsKey(targetPage)) {
          final pageLines = pageCache[targetPage]!;
          for (final line in pageLines) {
            if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
              surahIdForPage = line.ayahSegments!.first.surahId;
              appLogger.log(
                'DATA_OPTIMIZED',
                'Found surahId from cache: $surahIdForPage',
              );
              break;
            }
          }
        }

        // ? FIX: Fallback if still null
        if (surahIdForPage == null) {
          appLogger.log(
            'DATA_OPTIMIZED',
            'Loading from database to find surahId...',
          );
          final pageLines = await _sqliteService.getMushafPageLines(targetPage);

          // Find first valid ayah segment
          for (final line in pageLines) {
            if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
              surahIdForPage = line.ayahSegments!.first.surahId;
              appLogger.log(
                'DATA_OPTIMIZED',
                'Found surahId from DB: $surahIdForPage',
              );
              break;
            }
          }
        }
      }

      // ? VALIDATION: Throw error if still null
      if (surahIdForPage == null) {
        throw Exception('Cannot determine surah ID for page $targetPage');
      }

      // Load chapter info
      final chapter = await _sqliteService.getChapterInfo(surahIdForPage);
      _suratNameSimple = chapter.nameSimple;
      _suratVersesCount = chapter.versesCount.toString();
      _determinedSurahId = surahIdForPage;

      // Load ayat list if not already loaded
      if (_ayatList.isEmpty) {
        _ayatList = await _sqliteService.getSurahAyatDataOptimized(
          surahIdForPage,
          isQuranMode: _isQuranMode,
        );
        appLogger.log('DATA_OPTIMIZED', 'Loaded ${_ayatList.length} ayats');
      }

      // ? CRITICAL: Set to target page, NOT first page
      _currentPage = targetPage;

      // Update current ayat index based on target page
      if (_ayatList.isNotEmpty) {
        final targetAyat = _ayatList.firstWhere(
          (a) => a.page == targetPage,
          orElse: () => _ayatList.first,
        );
        _currentAyatIndex = _ayatList.indexOf(targetAyat);
        appLogger.log(
          'DATA_OPTIMIZED',
          'Set current ayat index to: $_currentAyatIndex',
        );
      }

      await _loadCurrentPageAyats();
      _isDataLoaded = true;

      appLogger.log(
        'DATA_OPTIMIZED',
        'Data loaded successfully, positioned at page $targetPage',
      );
    } catch (e) {
      appLogger.log('DATA_OPTIMIZED_ERROR', 'Failed to load data: $e');
      rethrow;
    }
  }

  // ✅ CRITICAL: Track last loaded page to prevent duplicate calls
  int? _lastLoadedAyatsPage;

  Future<void> _loadCurrentPageAyats() async {
    // ✅ OPTIMIZED: Prevent duplicate calls for same page
    if (_lastLoadedAyatsPage == _currentPage) {
      return; // Already loaded for this page
    }

    if (!_isQuranMode) {
      _currentPageAyats = _ayatList;
      _lastLoadedAyatsPage = _currentPage;
      notifyListeners();
      return;
    }
    try {
      // ✅ CRITICAL: Load current page ayats FIRST (priority)
      // This ensures UI updates immediately with current page data
      final currentPageAyatsFuture = _sqliteService.getCurrentPageAyats(
        _currentPage,
      );

      // ✅ Wait for current page ayats to load (priority)
      _currentPageAyats = await currentPageAyatsFuture;
      _lastLoadedAyatsPage = _currentPage;

      appLogger.log(
        'DATA',
        'Loaded ${_currentPageAyats.length} ayats for page $_currentPage',
      );

      // ✅ CRITICAL: Notify listeners IMMEDIATELY after current page loaded
      // This ensures UI shows current page data right away
      notifyListeners();

      // ✅ Background: Preload adjacent pages AFTER current page is shown
      // This doesn't block UI update
      Future.microtask(() => _preloadAdjacentPagesAggressively());
    } catch (e) {
      appLogger.log('DATA_PAGE_ERROR', 'Error loading page ayats - $e');
      _currentPageAyats = [];
      notifyListeners();
    }
  }

  // ✅ CRITICAL: Track last preloaded page to prevent duplicate calls
  int? _lastPreloadedPage;
  DateTime? _lastPreloadTime;

  Future<void> _preloadAdjacentPagesAggressively() async {
    // ✅ CRITICAL: Check disposal state AND stop flag BEFORE any async operation
    if (_isDisposed || _stopPreloading) {
      print('[PRELOAD] Controller disposed or stopped, skipping preload');
      return;
    }

    // ✅ CRITICAL: Prevent duplicate preload calls for same page
    if (_isPreloadingPages) {
      return; // Already preloading
    }

    // ✅ Debounce: Don't preload if same page was preloaded recently (< 500ms)
    if (_lastPreloadedPage == _currentPage &&
        _lastPreloadTime != null &&
        DateTime.now().difference(_lastPreloadTime!).inMilliseconds < 500) {
      return; // Too soon, skip
    }

    _isPreloadingPages = true;
    _lastPreloadedPage = _currentPage;
    _lastPreloadTime = DateTime.now();

    try {
      final pagesToPreload = <int>[];

      // ✅ Check stop flag before building list
      if (_stopPreloading) {
        _isPreloadingPages = false;
        return;
      }

      // ✅ OPTIMIZED: Prioritize immediate adjacent pages first
      if (_currentPage > 1) pagesToPreload.add(_currentPage - 1);
      if (_currentPage < totalPages) pagesToPreload.add(_currentPage + 1);

      // Then load expanding radius pages
      for (int i = 2; i <= cacheRadius; i++) {
        if (_stopPreloading) break; // ✅ Check on each iteration
        if (_currentPage - i >= 1) pagesToPreload.add(_currentPage - i);
        if (_currentPage + i <= totalPages)
          pagesToPreload.add(_currentPage + i);
      }

      // Rest of the method remains the same...
      // (keep existing code for loading pages)

      final immediatePages = <int>[];
      final backgroundPages = <int>[];

      for (final page in pagesToPreload) {
        if (_isDisposed || _stopPreloading) {
          print('[PRELOAD] Stopped during page filtering, aborting');
          return;
        }

        if (pageCache.containsKey(page)) continue;

        final serviceCache = _sqliteService.getCachedPage(page);
        if (serviceCache != null) {
          pageCache[page] = serviceCache;
          continue;
        }

        final distance = (page - _currentPage).abs();
        if (distance <= 20) {
          immediatePages.add(page);
        } else {
          backgroundPages.add(page);
        }
      }

      // ✅ OPTIMIZED: Load immediate pages using batch method
      if (immediatePages.isNotEmpty && !_stopPreloading) {
        try {
          final batchResults = await _sqliteService.getMushafPageLinesBatch(
            immediatePages,
          );

          if (_isDisposed || _stopPreloading) return;

          // Update cache with batch results
          for (final entry in batchResults.entries) {
            pageCache[entry.key] = entry.value;
          }

          appLogger.log(
            'CACHE',
            '⚡ Immediate batch loaded ${batchResults.length} pages',
          );
        } catch (e) {
          if (!_isDisposed && !_stopPreloading) {
            appLogger.log('CACHE_ERROR', 'Immediate batch load failed: $e');
          }
        }
      }

      if (backgroundPages.isNotEmpty && !_isDisposed && !_stopPreloading) {
        Future.microtask(() async {
          const batchSize = 15; // Load 15 pages per batch
          int totalLoaded = 0;

          for (int i = 0; i < backgroundPages.length; i += batchSize) {
            if (_isDisposed || _stopPreloading) {
              appLogger.log('PRELOAD', 'Stopped during background load');
              break;
            }

            final batch = backgroundPages.skip(i).take(batchSize).toList();

            try {
              final batchResults = await _sqliteService.getMushafPageLinesBatch(
                batch,
              );

              if (_isDisposed || _stopPreloading) break;

              // Update cache
              for (final entry in batchResults.entries) {
                pageCache[entry.key] = entry.value;
              }

              totalLoaded += batchResults.length;

              if (totalLoaded % 30 == 0) {
                appLogger.log(
                  'CACHE',
                  'Background preloaded $totalLoaded/${backgroundPages.length} pages...',
                );
              }

              // Small delay between batches to avoid overwhelming DB
              await Future.delayed(const Duration(milliseconds: 100));
            } catch (e) {
              if (!_isDisposed && !_stopPreloading) {
                appLogger.log('CACHE_ERROR', 'Background batch failed: $e');
              }
            }
          }

          if (!_isDisposed && !_stopPreloading) {
            appLogger.log(
              'CACHE',
              '✅ Background preload complete: $totalLoaded pages cached',
            );
            _cleanupDistantCache();
          }
        });
      } else if (!_isDisposed && !_stopPreloading) {
        _cleanupDistantCache();
      }
    } finally {
      _isPreloadingPages = false;
    }
  }

  void _cleanupDistantCache() {
    // ✅ OPTIMIZED: Only evict when cache is VERY large and pages are VERY far
    if (pageCache.length > cacheEvictionThreshold) {
      final sortedKeys = pageCache.keys.toList()
        ..sort(
          (a, b) =>
              (a - _currentPage).abs().compareTo((b - _currentPage).abs()),
        );

      // ✅ Dynamic: Use totalPages for validation
      final keysToRemove = sortedKeys
          .where(
            (key) =>
                (key - _currentPage).abs() > cacheEvictionDistance ||
                key > totalPages,
          ) // ✅ ADD: Remove pages beyond current layout max
          .take(pageCache.length - maxCacheSize)
          .toList();

      for (final key in keysToRemove) {
        pageCache.remove(key);
        if (keysToRemove.length % 10 == 0) {
          // Only log occasionally
          appLogger.log(
            'CACHE',
            'Removed page $key (distance: ${(key - _currentPage).abs()}, max: $totalPages)',
          );
        }
      }
    }
  }

  void navigateToPage(int newPage) {
    if (newPage < 1 || newPage > totalPages || newPage == _currentPage) {
      appLogger.log(
        'NAV',
        'Invalid navigation to page $newPage (max: $totalPages)',
      );
      return;
    }
    if (newPage < 1 || newPage > totalPages || newPage == _currentPage) {
      appLogger.log(
        'NAV',
        'Invalid navigation to page $newPage (max: $totalPages)',
      );
      return;
    }

    appLogger.log('NAV', '📄 Navigating from page $_currentPage to $newPage');
    // ✅ FIX: Update AppBar instantly BEFORE any async work
    _updateSurahNameForPageSync(newPage); // Load from cache (instant)
    updateVisiblePageQuiet(newPage); // Update AppBar notifier

    // ✅ CRITICAL FIX: Stop listening mode when user manually navigates
    if (_isListeningMode && _listeningAudioService != null) {
      print('🛑 User navigated during listening - stopping listening mode...');
      // Stop immediately (fire-and-forget, but set flag to prevent new sessions)
      _isListeningMode =
          false; // Set flag immediately to prevent race conditions
      stopListening().catchError((e) {
        print('⚠️ Error stopping listening during navigation: $e');
        // Ensure flag is still false even if error occurs
        _isListeningMode = false;
      });
    }

    _currentPage = newPage;
    // ✅ CRITICAL: Reset last loaded ayats page to force reload
    _lastLoadedAyatsPage = null;

    // ✅ CRITICAL: Check both SttController cache AND QuranService cache
    // QuranService cache is shared singleton, so check it first
    if (!pageCache.containsKey(newPage)) {
      final serviceCache = _sqliteService.getCachedPage(newPage);
      if (serviceCache != null) {
        // ✅ Sync from QuranService cache to SttController cache
        pageCache[newPage] = serviceCache;
        appLogger.log('NAV', '✅ Synced page $newPage from QuranService cache');
      } else if (_sqliteService.isPageLoading(newPage)) {
        // ✅ OPTIMIZED: If page is already loading, wait for it instead of loading again
        final loadingFuture = _sqliteService.getLoadingFuture(newPage);
        if (loadingFuture != null) {
          appLogger.log('NAV', '⏳ Page $newPage already loading, waiting...');
          loadingFuture
              .then((lines) {
                pageCache[newPage] = lines;
                _updateSurahNameForPage(newPage);
                _loadCurrentPageAyats();
                notifyListeners();
                Future.microtask(() => _preloadAdjacentPagesAggressively());
              })
              .catchError((e) {
                appLogger.log(
                  'NAV_ERROR',
                  'Failed to wait for page $newPage: $e',
                );
                // Fallback to normal load
                _loadSinglePageData(newPage).then((_) {
                  _updateSurahNameForPage(newPage);
                  _loadCurrentPageAyats();
                  notifyListeners();
                  Future.microtask(() => _preloadAdjacentPagesAggressively());
                });
              });
          return; // Exit early, will update when load completes
        }
      }
    }

    // ✅ Check if target page is already cached
    if (pageCache.containsKey(newPage)) {
      appLogger.log('NAV', '⚡ INSTANT: Page $newPage already in cache');

      // Update surah name immediately from cache
      _updateSurahNameForPage(newPage);

      // Update current page ayats immediately (no loading)
      _loadCurrentPageAyats();

      // Update ayat index
      if (_currentPageAyats.isNotEmpty) {
        final firstAyatOnPage = _currentPageAyats.first;
        final newIndex = _ayatList.indexWhere(
          (a) =>
              a.surah_id == firstAyatOnPage.surah_id &&
              a.ayah == firstAyatOnPage.ayah,
        );
        if (newIndex >= 0) {
          _currentAyatIndex = newIndex;
          appLogger.log('NAV', 'Updated ayat index to $_currentAyatIndex');
        }
      }

      notifyListeners();

      // Preload more pages in background
      Future.microtask(() => _preloadAdjacentPagesAggressively());
    } else {
      // ✅ Page not cached - load it + adjacent pages immediately
      appLogger.log('NAV', '🔥 Loading page $newPage + adjacent pages...');

      // Load with parallel fetch (will cache adjacent pages too)
      _loadSinglePageData(newPage)
          .then((_) {
            // Update surah name after page loaded
            _updateSurahNameForPage(newPage);

            _loadCurrentPageAyats();

            if (_currentPageAyats.isNotEmpty) {
              final firstAyatOnPage = _currentPageAyats.first;
              final newIndex = _ayatList.indexWhere(
                (a) =>
                    a.surah_id == firstAyatOnPage.surah_id &&
                    a.ayah == firstAyatOnPage.ayah,
              );
              if (newIndex >= 0) {
                _currentAyatIndex = newIndex;
              }
            }

            notifyListeners();

            // Continue preloading in background
            Future.microtask(() => _preloadAdjacentPagesAggressively());
          })
          .catchError((e) {
            appLogger.log(
              'NAV_ERROR',
              'Failed to navigate to page $newPage: $e',
            );
          });
    }
  }

  /// ? NEW: Lightweight navigation for listening mode (NO full reload)
  Future<void> _navigateToPageForListening(
    int targetPage,
    int targetSurahId,
  ) async {
    if (targetPage < 1 || targetPage > totalPages) {
      appLogger.log('NAV', 'Invalid page: $targetPage (max: $totalPages)');
      return;
    }

    appLogger.log(
      'NAV_LISTENING',
      '?? Navigating to page $targetPage for listening (Surah $targetSurahId)',
    );

    _currentPage = targetPage;
    _listViewCurrentPage = targetPage;

    // ? CRITICAL: Check cache first (should be instant)
    if (pageCache.containsKey(targetPage)) {
      appLogger.log('NAV_LISTENING', '? INSTANT: Page $targetPage in cache');

      // Update surah name from cache (instant)
      await _updateSurahNameForPage(targetPage);

      // Load current page ayats (instant from cache)
      await _loadCurrentPageAyats();

      // ? CRITICAL: Don't filter _ayatList by suratId for listening mode
      // Keep ALL ayats on page for wordStatusMap to work
      if (_currentPageAyats.isNotEmpty) {
        _ayatList = List<AyatData>.from(_currentPageAyats);

        // Find first ayat of target surah
        final firstTargetAyat = _ayatList.firstWhere(
          (a) => a.surah_id == targetSurahId,
          orElse: () => _ayatList.first,
        );
        _currentAyatIndex = _ayatList.indexOf(firstTargetAyat);

        appLogger.log(
          'NAV_LISTENING',
          '? Loaded ${_ayatList.length} ayats, current index: $_currentAyatIndex',
        );
      }

      notifyListeners();

      // Preload adjacent pages in background
      Future.microtask(() => _preloadAdjacentPagesAggressively());
      return;
    }

    // ? Page not cached - load with minimal delay
    appLogger.log(
      'NAV_LISTENING',
      '?? Loading page $targetPage from database...',
    );

    try {
      // Load page with parallel loading
      await _loadSinglePageData(targetPage);

      // Update UI state
      await _updateSurahNameForPage(targetPage);
      await _loadCurrentPageAyats();

      // ? CRITICAL: Keep ALL ayats on page (don't filter)
      if (_currentPageAyats.isNotEmpty) {
        _ayatList = List<AyatData>.from(_currentPageAyats);

        final firstTargetAyat = _ayatList.firstWhere(
          (a) => a.surah_id == targetSurahId,
          orElse: () => _ayatList.first,
        );
        _currentAyatIndex = _ayatList.indexOf(firstTargetAyat);

        appLogger.log(
          'NAV_LISTENING',
          '? Loaded ${_ayatList.length} ayats, current index: $_currentAyatIndex',
        );
      }

      notifyListeners();

      Future.microtask(() => _preloadAdjacentPagesAggressively());
    } catch (e) {
      appLogger.log('NAV_LISTENING_ERROR', 'Failed to navigate: $e');
    }
  }

  // ===== NEW METHOD: Update surah name for current page =====
  Future<void> _updateSurahNameForPage(int pageNumber) async {
    try {
      // ✅ Priority 1: Use metadata cache (FASTEST - no database query)
      final surahName = _metadataCache.getPrimarySurahForPage(pageNumber);

      if (surahName.isNotEmpty && surahName != 'Page $pageNumber') {
        // Extract surah ID from cache
        final surahIds = _metadataCache.getSurahIdsForPage(pageNumber);
        if (surahIds != null && surahIds.isNotEmpty) {
          final surahId = surahIds.first;

          if (_determinedSurahId != surahId) {
            _determinedSurahId = surahId;

            // Get full metadata from cache
            final surahMeta = _metadataCache.getSurah(surahId);
            if (surahMeta != null) {
              _suratNameSimple = surahMeta['name_simple'] as String;
              _suratVersesCount = surahMeta['verses_count'].toString();

              appLogger.log(
                'SURAH_UPDATE',
                'Updated to: $_suratNameSimple (Page $pageNumber) - FROM CACHE',
              );
              notifyListeners();
              return;
            }
          }
        }
      }

      // Priority 2: Use cached page data (fallback)
      if (pageCache.containsKey(pageNumber)) {
        final pageLines = pageCache[pageNumber]!;

        for (final line in pageLines) {
          if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
            final firstSegment = line.ayahSegments!.first;
            final surahId = firstSegment.surahId;

            if (_determinedSurahId != surahId) {
              _determinedSurahId = surahId;

              final chapter = await _sqliteService.getChapterInfo(surahId);
              _suratNameSimple = chapter.nameSimple;
              _suratVersesCount = chapter.versesCount.toString();

              appLogger.log(
                'SURAH_UPDATE',
                'Updated to: $_suratNameSimple (Page $pageNumber) - FROM PAGE CACHE',
              );
              notifyListeners();
            }
            return;
          }
        }
      }

      // Priority 3: Use _currentPageAyats if available
      if (_currentPageAyats.isNotEmpty) {
        final firstAyat = _currentPageAyats.first;
        final surahId = firstAyat.surah_id;

        if (_determinedSurahId != surahId) {
          _determinedSurahId = surahId;

          final chapter = await _sqliteService.getChapterInfo(surahId);
          _suratNameSimple = chapter.nameSimple;
          _suratVersesCount = chapter.versesCount.toString();

          appLogger.log(
            'SURAH_UPDATE',
            'Updated to: $_suratNameSimple (from ayats)',
          );
          notifyListeners();
        }
        return;
      }

      // Priority 4: Load from database (slowest fallback)
      final pageLines = await _sqliteService.getMushafPageLines(pageNumber);
      for (final line in pageLines) {
        if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
          final firstSegment = line.ayahSegments!.first;
          final surahId = firstSegment.surahId;

          _determinedSurahId = surahId;

          final chapter = await _sqliteService.getChapterInfo(surahId);
          _suratNameSimple = chapter.nameSimple;
          _suratVersesCount = chapter.versesCount.toString();

          appLogger.log(
            'SURAH_UPDATE',
            'Updated to: $_suratNameSimple (loaded from DB)',
          );
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      appLogger.log('SURAH_UPDATE_ERROR', 'Failed to update surah name: $e');
    }
  }

  void updatePageCache(int page, List<MushafPageLine> lines) {
    // ✅ OPTIMIZED: Update cache WITHOUT notifyListeners
    // UI will update on next natural rebuild cycle
    pageCache[page] = lines;

    // ✅ Only notify if this is current visible page
    if (page == _currentPage || page == _listViewCurrentPage) {
      notifyListeners();
    }
  }

  // ===== UI TOGGLES & ACTIONS =====
  void toggleUIVisibility() {
    _isUIVisible = !_isUIVisible;
    notifyListeners();
  }

  Future<void> toggleQuranMode() async {
    appLogger.log(
      'MODE_TOGGLE',
      'Switching from ${_isQuranMode ? "Mushaf" : "List"} to ${!_isQuranMode ? "Mushaf" : "List"}',
    );

    // ? STEP 1: Preserve current position
    final targetPage = _isQuranMode ? _currentPage : _listViewCurrentPage;
    appLogger.log('MODE_TOGGLE', 'Target page after toggle: $targetPage');

    // ? STEP 2: Toggle mode flag FIRST
    _isQuranMode = !_isQuranMode;

    // ? IMMEDIATE: Notify UI of mode change (quick feedback)
    notifyListeners();

    // ? STEP 3: Smart data loading (skip if already loaded)
    if (!_isDataLoaded || _ayatList.isEmpty) {
      appLogger.log('MODE_TOGGLE', 'Loading data (first time or empty)');
      await _loadAyatDataOptimized(targetPage);
    } else {
      appLogger.log('MODE_TOGGLE', 'Skipping reload - data already loaded');

      // Just update current page without reloading
      _currentPage = targetPage;

      // Update surah name for target page
      await _updateSurahNameForPage(targetPage);

      // Load page-specific data if switching to mushaf
      if (_isQuranMode) {
        await _loadCurrentPageAyats();

        // ? IMPORTANT: Ensure page is in cache before switching
        if (!pageCache.containsKey(targetPage)) {
          appLogger.log(
            'MODE_TOGGLE',
            'Loading target page $targetPage to cache',
          );
          final lines = await _sqliteService.getMushafPageLines(targetPage);
          pageCache[targetPage] = lines;
        }

        // Preload adjacent pages
        Future.microtask(() => _preloadAdjacentPagesAggressively());
      }
    }

    // ? FINAL: Notify UI again after data ready
    notifyListeners();

    appLogger.log(
      'MODE_TOGGLE',
      'Toggle complete - now at page $_currentPage (${_isQuranMode ? "Mushaf" : "List"})',
    );
  }

  void toggleHideUnread() {
    _hideUnreadAyat = !_hideUnreadAyat;
    notifyListeners();
  }

  void toggleLogs() {
    _showLogs = !_showLogs;
    notifyListeners();
  }

  void clearLogs() {
    appLogger.clear();
    notifyListeners();
  }

  void handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'logs':
        toggleLogs();
        break;
      case 'reset':
        _showResetDialog(context);
        break;
      case 'export':
        exportSession(context);
        break;
    }
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: warningColor, size: 18),
            SizedBox(width: 4),
            Text('Reset Session', style: TextStyle(fontSize: 14)),
          ],
        ),
        content: const Text(
          'Reset current session? This will restart the app.',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performReset(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Reset', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _performReset(BuildContext context) {
    appLogger.log('RESET', 'Performing session reset');
    _currentAyatIndex = 0;
    _sessionStartTime = DateTime.now();
    notifyListeners();
  }

  void exportSession(BuildContext context) {
    final sessionData = {
      'surah': _suratNameSimple,
      'session_duration': _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inMinutes
          : 0,
      'total_ayat': _ayatList.length,
    };
    appLogger.log('EXPORT', 'Session exported - $sessionData');
  }

  // ===== UTILITY & HELPER METHODS =====
  String formatSurahIdForGlyph(int surahId) {
    if (surahId <= 9) return 'surah00$surahId';
    if (surahId <= 99) return 'surah0$surahId';
    return 'surah$surahId';
  }

  int calculateJuz(int surahId, int ayahNumber) {
    return _sqliteService.calculateJuzAccurate(surahId, ayahNumber);
  }

  static bool containsArabicNumbers(String text) {
    return RegExp(r'[� -٩]+').hasMatch(text);
  }

  static bool isPureArabicNumber(String text) {
    final trimmedText = text.trim();
    return RegExp(r'^[� -٩۰۱۲۳۴۵۶۷۸۹ۺۻ۞ﮞﮟ\s]+$').hasMatch(trimmedText) &&
        containsArabicNumbers(trimmedText);
  }

  List<TextSegment> segmentText(String text) {
    List<TextSegment> segments = [];
    List<String> words = text.split(' ');
    for (String word in words) {
      if (word.trim().isEmpty) continue;
      if (isPureArabicNumber(word)) {
        segments.add(TextSegment(text: word, isArabicNumber: true));
      } else {
        segments.add(TextSegment(text: word, isArabicNumber: false));
      }
    }
    return segments;
  }

  // ===== WEBSOCKET & RECORDING =====
  void _initializeWebSocket() {
    print('🔌 SttController: Initializing WebSocket subscriptions...');

    // ✅ Cancel old subscriptions if they exist
    _wsSubscription?.cancel();
    _connectionSubscription?.cancel();

    // ✅ Create new subscriptions (will get fresh streams if controllers were recreated)
    _wsSubscription = _webSocketService.messages.listen(
      _handleWebSocketMessage,
      onError: (error) {
        print('❌ SttController: Message stream error: $error');
      },
      onDone: () {
        print('� ️ SttController: Message stream closed');
      },
    );

    _connectionSubscription = _webSocketService.connectionStatus.listen(
      (isConnected) {
        if (_isConnected != isConnected) {
          _isConnected = isConnected;
          if (_isConnected) {
            _errorMessage = '';
            print('✅ SttController: Connection status changed to CONNECTED');
          } else if (_isRecording) {
            _errorMessage = 'Connection lost. Attempting to reconnect...';
            print(
              '� ️ SttController: Connection status changed to DISCONNECTED',
            );
          }
          notifyListeners();
        }
      },
      onError: (error) {
        print('❌ SttController: Connection stream error: $error');
      },
      onDone: () {
        print('� ️ SttController: Connection stream closed');
      },
    );

    print('? SttController: WebSocket subscriptions initialized');

    // ? OPTIMIZED: NO pre-connect - WebSocket connects ONLY when user slides button
    // This makes page load faster and lighter
    print('?? WebSocket will connect when user starts recording');
  }

  Future<void> _connectWebSocket() async {
    try {
      _webSocketService.enableAutoReconnect();
      await _webSocketService.connect();
      _isConnected = _webSocketService.isConnected;
      appLogger.log('WEBSOCKET', 'Connected: $_isConnected');
    } catch (e) {
      appLogger.log('WEBSOCKET_ERROR', 'Connection failed: $e');
    }
  }

  /// Ensure WebSocket is connected (with timeout)
  /// ? IMPROVED: Force reconnect jika connection stale (backend restart)
  Future<bool> _ensureConnected({
    int timeoutMs = 1500,
    bool forceNew = false,
  }) async {
    // ? Force new connection jika diminta (setelah backend restart)
    if (forceNew) {
      print('?? Force reconnecting WebSocket...');
      await _webSocketService.forceReconnect();
      _isConnected = _webSocketService.isConnected;
      return _isConnected;
    }

    if (_webSocketService.isConnected) {
      print('? WebSocket already connected!');
      return true;
    }

    print('?? Connecting WebSocket...');
    final connectStart = DateTime.now();

    await _connectWebSocket();

    // Fast polling with timeout
    final stopwatch = Stopwatch()..start();
    while (!_webSocketService.isConnected &&
        stopwatch.elapsedMilliseconds < timeoutMs) {
      await Future.delayed(const Duration(milliseconds: 20));
    }

    final elapsed = DateTime.now().difference(connectStart).inMilliseconds;
    _isConnected = _webSocketService.isConnected;

    if (_isConnected) {
      print('? WebSocket connected in ${elapsed}ms');
    } else {
      // ? NEW: Try force reconnect if normal connect failed
      print('?? Normal connect failed, trying force reconnect...');
      await _webSocketService.forceReconnect();
      _isConnected = _webSocketService.isConnected;

      if (_isConnected) {
        print('? Force reconnect succeeded!');
      } else {
        print('? WebSocket timeout after ${elapsed}ms');
      }
    }

    return _isConnected;
  }

  Future<void> _handleWebSocketMessage(Map<String, dynamic> message) async {
    final type = message['type'];
    appLogger.log('WS_MESSAGE', 'Received: $type');
    print('🔔 STT CONTROLLER: Received message type: $type');

    switch (type) {
      case 'word_processing':
        final int processingAyah = message['ayah'] ?? 0;
        final int processingWordIndex = message['word_index'] ?? 0;
        final int processingSurah =
            message['surah'] ?? suratId ?? _determinedSurahId ?? 1;
        _currentAyatIndex = _ayatList.indexWhere(
          (a) => a.ayah == processingAyah && a.surah_id == processingSurah,
        );
        final processingKey = _wordKey(processingSurah, processingAyah);
        if (!_wordStatusMap.containsKey(processingKey))
          _wordStatusMap[processingKey] = {};
        _wordStatusMap[processingKey]![processingWordIndex] =
            WordStatus.processing;
        notifyListeners();
        break;

      case 'skip_rejected':
        _errorMessage = message['message'] ?? 'Please read in order';
        notifyListeners();
        Future.delayed(const Duration(seconds: 3), () {
          if (_errorMessage == message['message']) {
            _errorMessage = '';
            notifyListeners();
          }
        });
        break;

      // ?? DISABLED: word_processing handler - backend no longer sends this
      // Processing status is now set via next_word_index in word_feedback
      // case 'word_processing':
      //   final int procAyah = message['ayah'] ?? 0;
      //   final int procWordIndex = message['word_index'] ?? 0;
      //   final int procSurah = message['surah'] ?? suratId ?? _determinedSurahId ?? 1;
      //
      //   // Update word status to processing (blue/yellow)
      //   final procKey = _wordKey(procSurah, procAyah);
      //   if (!_wordStatusMap.containsKey(procKey)) {
      //     _wordStatusMap[procKey] = {};
      //   }
      //   _wordStatusMap[procKey]![procWordIndex] = WordStatus.processing;
      //
      //   // Also update _currentWords if available
      //   if (_currentWords.isNotEmpty && procWordIndex < _currentWords.length) {
      //     _currentWords[procWordIndex] = WordFeedback(
      //       text: _currentWords[procWordIndex].text,
      //       status: WordStatus.processing,
      //       wordIndex: procWordIndex,
      //       similarity: 0.0,
      //     );
      //   }
      //
      //   notifyListeners();
      //   break;

      case 'word_feedback':
        final int feedbackAyah = message['ayah'] ?? 0;
        final int feedbackWordIndex = message['word_index'] ?? 0;
        final String status = message['status'] ?? 'pending';
        final String expectedWord = message['expected_word'] ?? '';
        final String transcribedWord = message['transcribed_word'] ?? '';
        final int totalWords = message['total_words'] ?? 0;
        final int feedbackSurah =
            message['surah'] ?? suratId ?? _determinedSurahId ?? 1;

        _currentAyatIndex = _ayatList.indexWhere(
          (a) => a.ayah == feedbackAyah && a.surah_id == feedbackSurah,
        );

        // UPDATE _wordStatusMap dengan key "surahId:ayahNumber"
        final feedbackKey = _wordKey(feedbackSurah, feedbackAyah);
        if (!_wordStatusMap.containsKey(feedbackKey))
          _wordStatusMap[feedbackKey] = {};
        _wordStatusMap[feedbackKey]![feedbackWordIndex] = _mapWordStatus(
          status,
        );
        print(
          '🗺️ STT: Updated wordStatusMap[$feedbackKey][$feedbackWordIndex] = ${_mapWordStatus(status)}',
        );
        print(
          '🗺️ STT: Full wordStatusMap[$feedbackKey] = ${_wordStatusMap[feedbackKey]}',
        );

        // 🔥 NEW: Update _currentWords REALTIME
        if (_currentWords.isEmpty || _currentWords.length != totalWords) {
          print(
            '🔥 STT: Initializing _currentWords for ayah $feedbackAyah with $totalWords words',
          );
          _currentWords = List.generate(
            totalWords,
            (i) => WordFeedback(
              text: '',
              status: WordStatus.pending,
              wordIndex: i,
              similarity: 0.0,
            ),
          );
        }

        if (feedbackWordIndex >= 0 &&
            feedbackWordIndex < _currentWords.length) {
          _currentWords[feedbackWordIndex] = WordFeedback(
            text: expectedWord,
            status: _mapWordStatus(status),
            wordIndex: feedbackWordIndex,
            similarity: (message['similarity'] ?? 0.0).toDouble(),
            transcribedWord: transcribedWord,
          );
          print(
            '🔥 STT REALTIME: Updated _currentWords[$feedbackWordIndex] = $expectedWord (${_mapWordStatus(status)})',
          );
        }

        // ✅ NEW: Set NEXT word to processing (blue) based on next_word_index from backend
        final int? nextWordIndex = message['next_word_index'];
        if (nextWordIndex != null &&
            nextWordIndex < totalWords &&
            nextWordIndex >= 0 &&
            nextWordIndex < _currentWords.length) {
          // Only set processing if word is still pending (not already matched/mismatched)
          final currentNextStatus = _wordStatusMap[feedbackKey]?[nextWordIndex];
          if (currentNextStatus == null ||
              currentNextStatus == WordStatus.pending) {
            _wordStatusMap[feedbackKey]![nextWordIndex] = WordStatus.processing;
            _currentWords[nextWordIndex] = WordFeedback(
              text: _currentWords[nextWordIndex].text,
              status: WordStatus.processing,
              wordIndex: nextWordIndex,
              similarity: 0.0,
            );
          }
        }

        notifyListeners();
        break;

      case 'progress':
        final int completedAyah = message['ayah'];
        print('📥 STT: Progress for ayah $completedAyah');

        // 🚫 DON'T overwrite _currentWords if still recording same ayah!
        // word_feedback updates are more accurate and realtime
        if (!_isRecording ||
            _currentAyatIndex !=
                _ayatList.indexWhere((a) => a.ayah == completedAyah)) {
          if (message['words'] != null) {
            _currentWords = (message['words'] as List)
                .map((w) => WordFeedback.fromJson(w))
                .toList();
            print('🎨 STT: Parsed ${_currentWords.length} words for display');
          }

          // Update expected ayah from backend
          if (message['expected_ayah'] != null) {
            _expectedAyah = message['expected_ayah'];
            print('✅ STT: Updated expected_ayah to: $_expectedAyah');
          }

          // ✅ Only update currentAyatIndex if NOT recording
          if (!_isRecording) {
            _currentAyatIndex = _ayatList.indexWhere(
              (a) => a.ayah == _expectedAyah,
            );
            print('✅ STT: Moved currentAyatIndex to: $_currentAyatIndex');
          }
        } else {
          print(
            '🚫 STT SKIP: Keeping realtime word_feedback data (recording in progress)',
          );
        }

        // Update tartib status from backend
        if (message['tartib_status'] != null) {
          final Map<String, dynamic> backendTartib = message['tartib_status'];
          backendTartib.forEach((key, value) {
            final int ayahNum = int.tryParse(key) ?? -1;
            if (ayahNum > 0) {
              final String statusStr = value.toString().toLowerCase();
              switch (statusStr) {
                case 'correct':
                  _tartibStatus[ayahNum] = TartibStatus.correct;
                  break;
                case 'skipped':
                  _tartibStatus[ayahNum] = TartibStatus.skipped;
                  break;
                default:
                  _tartibStatus[ayahNum] = TartibStatus.unread;
              }
            }
          });
        }

        notifyListeners();
        break;

      case 'ayah_complete':
        final int completedSurah =
            message['surah'] ?? suratId ?? _determinedSurahId ?? 1;
        final int completedAyah = message['ayah'] ?? 0;
        final int nextAyah = message['next_ayah'] ?? 0;
        _tartibStatus[completedAyah] = TartibStatus.correct;
        // ? Cari ayah dengan surah yang benar
        _currentAyatIndex = _ayatList.indexWhere(
          (a) => a.ayah == nextAyah && a.surah_id == completedSurah,
        );

        // 🔵 TARTEEL-STYLE: Set first word of NEXT ayah to processing immediately
        // This ensures smooth transition - new ayah starts with blue indicator
        if (nextAyah > 0) {
          final nextAyahKey = _wordKey(completedSurah, nextAyah);
          if (!_wordStatusMap.containsKey(nextAyahKey)) {
            _wordStatusMap[nextAyahKey] = {};
          }
          // Set word 0 to processing (blue)
          _wordStatusMap[nextAyahKey]![0] = WordStatus.processing;
          print(
            '🔵 STT: Ayah complete! Set first word of next ayah to processing - $nextAyahKey[0]',
          );
        }

        notifyListeners();
        break;

      case 'started':
        _tartibStatus.clear();
        _expectedAyah = message['expected_ayah'] ?? 1;
        _sessionId = message['session_id'];
        final int startedSurah = message['surah'] ?? suratId ?? 1;

        // ? Handle rate_limit info from backend
        if (message['rate_limit'] != null) {
          _rateLimit = Map<String, dynamic>.from(message['rate_limit']);
          _rateLimitPlan = _rateLimit?['plan'] ?? 'free';
          _isRateLimitExceeded = false;
          print(
            '?? Rate Limit: ${_rateLimit?['current']}/${_rateLimit?['limit']} sessions (${_rateLimitPlan})',
          );
        }

        // ? Handle duration_limit info from backend
        if (message['duration_limit'] != null) {
          _durationLimit = Map<String, dynamic>.from(message['duration_limit']);
          _isDurationLimitExceeded = false;
          _isDurationWarningActive = false;
          print(
            '? Duration Limit: ${_durationLimit?['max_minutes']} min (unlimited: ${_durationLimit?['is_unlimited']})',
          );
        }

        // ? RESTORE word_status_map dari backend (jika ada session sebelumnya)
        // Key format: "surahId:ayahNumber" untuk hindari collision antar surah
        if (message['word_status_map'] != null &&
            (message['word_status_map'] as Map).isNotEmpty) {
          final Map<String, dynamic> backendWordMap =
              message['word_status_map'];
          _wordStatusMap.clear();
          backendWordMap.forEach((ayahKey, wordMap) {
            final int ayahNum = int.tryParse(ayahKey) ?? -1;
            if (ayahNum > 0 && wordMap is Map) {
              final key = _wordKey(startedSurah, ayahNum);
              _wordStatusMap[key] = {};
              (wordMap as Map<String, dynamic>).forEach((wordIndexKey, status) {
                final int wordIndex = int.tryParse(wordIndexKey) ?? -1;
                if (wordIndex >= 0) {
                  _wordStatusMap[key]![wordIndex] = _mapWordStatus(
                    status.toString(),
                  );
                }
              });
            }
          });
          print(
            '? STT: Restored ${_wordStatusMap.length} ayahs with word colors for surah $startedSurah',
          );
        } else {
          _wordStatusMap.clear();
          print('?? STT: Fresh session, no previous word status');
        }

        // ?? TARTEEL-STYLE: Set first word to processing immediately when session starts
        // This gives immediate visual feedback that system is ready and listening
        final int startAyah = message['expected_ayah'] ?? 1;
        final firstWordKey = _wordKey(startedSurah, startAyah);
        if (!_wordStatusMap.containsKey(firstWordKey)) {
          _wordStatusMap[firstWordKey] = {};
        }
        // Only set if word 0 is not already matched/mismatched (for resume sessions)
        if (_wordStatusMap[firstWordKey]![0] == null ||
            _wordStatusMap[firstWordKey]![0] == WordStatus.pending) {
          _wordStatusMap[firstWordKey]![0] = WordStatus.processing;
          print(
            '🔵 STT: Set first word to processing (Tarteel-style) - $firstWordKey[0]',
          );
        }

        appLogger.log(
          'SESSION',
          'Started: $_sessionId (restored: ${_wordStatusMap.isNotEmpty})',
        );
        notifyListeners();
        break;

      case 'error':
        final errorCode = message['code'];
        _errorMessage = message['message'];

        // ? Handle RATE_LIMIT_EXCEEDED error
        if (errorCode == 'RATE_LIMIT_EXCEEDED') {
          _isRateLimitExceeded = true;
          if (message['rate_limit'] != null) {
            _rateLimit = Map<String, dynamic>.from(message['rate_limit']);
            _rateLimitPlan = _rateLimit?['plan'] ?? 'free';
          }
          print(
            '?? Rate Limit Exceeded: ${_rateLimit?['current']}/${_rateLimit?['limit']}',
          );
          print('   Reset in: ${rateLimitResetFormatted}');
        }

        notifyListeners();
        break;

      // ? NEW: Handle duration warning (3 minutes remaining)
      case 'duration_warning':
        final remainingSeconds = message['remaining_seconds'] ?? 0;
        final remainingFormatted = message['remaining_formatted'] ?? '';
        _durationWarning = 'Sisa waktu $remainingFormatted';
        _isDurationWarningActive = true;
        print('?? Duration warning: $remainingFormatted remaining');
        notifyListeners();
        break;

      // ? NEW: Handle duration limit exceeded
      case 'duration_limit':
        final elapsedFormatted = message['elapsed_formatted'] ?? '15:00';
        _isDurationLimitExceeded = true;
        _durationWarning = 'Batas waktu 15 menit tercapai';
        _isRecording = false;
        print('?? Duration limit reached: $elapsedFormatted');
        notifyListeners();
        break;

      // // ?? NEW: Handle surah mismatch warning
      // case 'surah_mismatch':
      //   final expectedSurah = message['expected_surah'] ?? 0;
      //   final detectedSurah = message['detected_surah'] ?? 0;
      //   final detectedSurahName = message['detected_surah_name'] ?? 'Surah $detectedSurah';
      //   final mismatchMessage = message['message'] ?? 'Surah tidak sesuai';

      //   print('?? SURAH MISMATCH DETECTED!');
      //   print('   Expected: Surah $expectedSurah');
      //   print('   Detected: $detectedSurahName (Surah $detectedSurah)');

      //   // Set warning message to display in UI
      //   // _surahMismatchWarning = mismatchMessage;
      //   // _isSurahMismatch = true;
      //   // _detectedMismatchSurah = detectedSurah;
      //   // _detectedMismatchSurahName = detectedSurahName;

      //   notifyListeners();

      //   // Auto-clear warning after 10 seconds
      //   // Future.delayed(const Duration(seconds: 10), () {
      //   //   if (_isSurahMismatch) {
      //   //     _isSurahMismatch = false;
      //   //     _surahMismatchWarning = null;
      //   //     notifyListeners();
      //   //   }
      //   // });
      //   // break;

      // ? NEW: Handle paused message from backend
      case 'paused':
        final pausedSessionId = message['session_id'];
        final pausedSurah = message['surah'] ?? 0;
        final pausedAyah = message['ayah'] ?? 0;
        final pausedPosition = message['position'] ?? 0;

        print('?? STT: Session PAUSED');
        print('   Session ID: $pausedSessionId');
        print(
          '   Location: Surah $pausedSurah, Ayah $pausedAyah, Word ${pausedPosition + 1}',
        );

        _sessionId = pausedSessionId;
        _isRecording = false;

        // Show pause confirmation message
        _errorMessage = 'Session paused. You can resume anytime.';
        notifyListeners();

        // Clear message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_errorMessage == 'Session paused. You can resume anytime.') {
            _errorMessage = '';
            notifyListeners();
          }
        });
        break;

      // ? NEW: Handle resumed message from backend
      case 'resumed':
        final resumedSurah = message['surah'] ?? 0;
        final resumedAyah = message['ayah'] ?? 0;
        final resumedPosition = message['position'] ?? 0;

        print('?? STT: Session RESUMED');
        print(
          '   Location: Surah $resumedSurah, Ayah $resumedAyah, Word ${resumedPosition + 1}',
        );

        // ? CRITICAL: Navigate to the correct PAGE for this ayah
        try {
          final targetPage = await LocalDatabaseService.getPageNumber(
            resumedSurah,
            resumedAyah,
          );

          print(
            '?? Resume target page: $targetPage (for Surah $resumedSurah, Ayah $resumedAyah)',
          );

          // Update page if different from current
          if (_currentPage != targetPage) {
            print('?? Navigating from page $_currentPage to page $targetPage');
            _currentPage = targetPage;
            _listViewCurrentPage = targetPage;

            // Load ayats for the target page
            await _loadCurrentPageAyats();
          }
        } catch (e) {
          print('?? Failed to get page number: $e');
          // Continue anyway with current page
        }

        // Update current ayat index
        _currentAyatIndex = _ayatList.indexWhere((a) => a.ayah == resumedAyah);

        // If ayat not found in current list, try to find it
        if (_currentAyatIndex == -1) {
          print('?? Ayah $resumedAyah not found in current ayat list');
          // Try to find any ayat from the resumed surah
          _currentAyatIndex = _ayatList.indexWhere(
            (a) => a.surah_id == resumedSurah,
          );
          if (_currentAyatIndex == -1) {
            print('?? Surah $resumedSurah not found, defaulting to index 0');
            _currentAyatIndex = 0;
          }
        }

        print('?? Resume ayat index: $_currentAyatIndex');

        // Restore word status map if provided (key = "surahId:ayahNumber")
        if (message['word_status_map'] != null) {
          final Map<String, dynamic> backendWordMap =
              message['word_status_map'];
          backendWordMap.forEach((ayahKey, wordMap) {
            final int ayahNum = int.tryParse(ayahKey) ?? -1;
            if (ayahNum > 0 && wordMap is Map) {
              final key = _wordKey(resumedSurah, ayahNum);
              _wordStatusMap[key] = {};
              (wordMap as Map<String, dynamic>).forEach((wordIndexKey, status) {
                final int wordIndex = int.tryParse(wordIndexKey) ?? -1;
                if (wordIndex >= 0) {
                  _wordStatusMap[key]![wordIndex] = _mapWordStatus(
                    status.toString(),
                  );
                }
              });
            }
          });
          print(
            '? Restored word status for ${_wordStatusMap.length} ayahs (surah $resumedSurah)',
          );
        }

        // ? Restore verse status (ayah-level colors: matched/mismatched)
        if (message['verse_status_map'] != null) {
          final Map<String, dynamic> verseStatusMap =
              message['verse_status_map'] as Map<String, dynamic>;
          verseStatusMap.forEach((ayahKey, status) {
            final int ayahNum = int.tryParse(ayahKey) ?? -1;
            if (ayahNum > 0) {
              // Store verse status for UI display
              // This is used for ayah-level coloring (entire ayah hijau/merah)
              // You can add this to your state if needed
              print('? Restored verse status: Ayah $ayahNum = $status');
            }
          });
        }

        // ? Restore tartib status
        if (message['tartib_status'] != null) {
          final Map<String, dynamic> tartibMap =
              message['tartib_status'] as Map<String, dynamic>;
          tartibMap.forEach((ayahKey, status) {
            final int ayahNum = int.tryParse(ayahKey) ?? -1;
            if (ayahNum > 0) {
              final String statusStr = status.toString().toLowerCase();
              switch (statusStr) {
                case 'correct':
                  _tartibStatus[ayahNum] = TartibStatus.correct;
                  break;
                case 'skipped':
                  _tartibStatus[ayahNum] = TartibStatus.skipped;
                  break;
                default:
                  _tartibStatus[ayahNum] = TartibStatus.unread;
              }
            }
          });
          print('? Restored tartib status for ${_tartibStatus.length} ayahs');
        }

        _errorMessage =
            'Session resumed: Surah $resumedSurah, Ayah $resumedAyah, Word ${resumedPosition + 1}';
        notifyListeners();

        // Clear message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_errorMessage ==
              'Session resumed: Surah $resumedSurah, Ayah $resumedAyah, Word ${resumedPosition + 1}') {
            _errorMessage = '';
            notifyListeners();
          }
        });
        break;

      // ? NEW: Handle continued message from backend (restore previous session)
      case 'continued':
        final continuedSessionId = message['session_id'];
        final continuedSurah = message['surah'] ?? 0;
        final continuedAyah = message['ayah'] ?? 0;
        final continuedWord = message['word'] ?? 1;
        final continuedLocation = message['location'] ?? '';
        final continuedMode = message['mode'] ?? 'surah';
        final stats = message['stats'] as Map<String, dynamic>?;

        print('?? STT: Session CONTINUED');
        print('   Session ID: $continuedSessionId');
        print('   Location: $continuedLocation (word: $continuedWord)');
        print('   Mode: $continuedMode');
        if (stats != null) {
          print(
            '   Stats: ${stats['total_words_read']} words, ${stats['accuracy']}% accuracy',
          );
        }

        _sessionId = continuedSessionId;

        // Navigate to correct page
        try {
          final targetPage = await LocalDatabaseService.getPageNumber(
            continuedSurah,
            continuedAyah,
          );

          if (_currentPage != targetPage) {
            print('?? Navigating to page $targetPage');
            _currentPage = targetPage;
            _listViewCurrentPage = targetPage;
            await _loadCurrentPageAyats();
          }
        } catch (e) {
          print('?? Failed to get page number: $e');
        }

        // Update current position
        _currentAyatIndex = _ayatList.indexWhere(
          (a) => a.ayah == continuedAyah,
        );
        if (_currentAyatIndex == -1) {
          _currentAyatIndex = _ayatList.indexWhere(
            (a) => a.surah_id == continuedSurah,
          );
          if (_currentAyatIndex == -1) _currentAyatIndex = 0;
        }

        // ? CRITICAL: Restore word status map (for word coloring)
        // Key format: "surahId:ayahNumber"
        if (message['word_status_map'] != null) {
          final Map<String, dynamic> backendWordMap =
              message['word_status_map'];
          _wordStatusMap.clear();
          backendWordMap.forEach((ayahKey, wordMap) {
            final int ayahNum = int.tryParse(ayahKey) ?? -1;
            if (ayahNum > 0 && wordMap is Map) {
              final key = _wordKey(continuedSurah, ayahNum);
              _wordStatusMap[key] = {};
              (wordMap as Map<String, dynamic>).forEach((wordIndexKey, status) {
                final int wordIndex = int.tryParse(wordIndexKey) ?? -1;
                if (wordIndex >= 0) {
                  _wordStatusMap[key]![wordIndex] = _mapWordStatus(
                    status.toString(),
                  );
                }
              });
            }
          });
          print(
            '? Restored word status for ${_wordStatusMap.length} ayahs (surah $continuedSurah)',
          );
          print('   Word status map: $_wordStatusMap');
        }

        _errorMessage = 'Session continued from $continuedLocation';
        notifyListeners();

        // Clear message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_errorMessage == 'Session continued from $continuedLocation') {
            _errorMessage = '';
            notifyListeners();
          }
        });
        break;

      // ? NEW: Handle summary message from backend
      case 'summary':
        print('?? STT: Received session SUMMARY');

        final summaryAyah = message['ayah'] ?? 0;
        final wordResults = message['word_results'] as List?;
        final accuracy = message['accuracy'] as Map<String, dynamic>?;

        if (accuracy != null) {
          final benar = accuracy['benar'] ?? 0;
          final salah = accuracy['salah'] ?? 0;
          final total = accuracy['total'] ?? 0;
          final accuracyPct = accuracy['accuracy'] ?? 0.0;

          print('   ? Benar: $benar');
          print('   ? Salah: $salah');
          print('   ?? Total: $total');
          print('   ?? Accuracy: ${accuracyPct.toStringAsFixed(1)}%');
        }

        if (wordResults != null) {
          print('   ?? Word results: ${wordResults.length} words');
        }

        _isRecording = false;
        notifyListeners();
        break;

      // ? NEW: Handle completed message from backend
      case 'completed':
        print('? STT: Session COMPLETED');

        _isRecording = false;
        _errorMessage = 'Session completed successfully!';
        notifyListeners();

        // ? NEW: Check for new achievements after session completes
        _checkForNewAchievements();

        // Clear message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_errorMessage == 'Session completed successfully!') {
            _errorMessage = '';
            notifyListeners();
          }
        });
        break;
    }
  }

  /// ? NEW: Check for newly earned achievements after session ends
  Future<void> _checkForNewAchievements() async {
    final userId = _authService.userId;
    if (userId == null) return;

    try {
      print('?? Checking for new achievements...');
      final achievements = await _supabaseService.checkNewAchievements(userId);

      if (achievements.isNotEmpty) {
        print('?? New achievements earned: ${achievements.length}');
        for (final a in achievements) {
          print('   ${a['newly_earned_emoji']} ${a['newly_earned_title']}');
        }

        _newlyEarnedAchievements = achievements;
        notifyListeners();
      } else {
        print('?? No new achievements earned');
      }
    } catch (e) {
      print('? Error checking achievements: $e');
    }
  }

  /// Clear the newly earned achievements list (call after showing popup)
  void clearNewAchievements() {
    _newlyEarnedAchievements = [];
    notifyListeners();
  }

  // ✅ NEW: Premium provider reference for feature gating
  PremiumProvider? _premiumProvider;

  /// ✅ NEW: Set premium provider from context (call from widget)
  void setPremiumProvider(PremiumProvider provider) {
    _premiumProvider = provider;
  }

  WordStatus _mapWordStatus(String status) {
    // ✅ FREE USER: Only current word shows processing (blue)
    // Previous words reset to pending (white) - NO permanent colors
    final isPremium =
        _premiumProvider?.canAccess(PremiumFeature.permanentWordColors) ?? true;

    switch (status.toLowerCase()) {
      case 'matched':
      case 'correct':
      case 'close': // ✅ Close = hampir benar = HIJAU
      case 'benar': // ? Backend sends "benar" for correct words
        // ✅ FREE: Return pending (white) so color disappears after processing
        return isPremium ? WordStatus.matched : WordStatus.pending;
      case 'processing':
        return WordStatus.processing; // Always show current word as blue
      case 'mismatched':
      case 'incorrect':
      case 'salah': // ? Backend sends "salah" for incorrect words
        // ✅ FREE: Return pending (white) so color disappears after processing
        return isPremium ? WordStatus.mismatched : WordStatus.pending;
      case 'skipped':
        // ✅ FREE: Return pending (white) so color disappears after processing
        return isPremium ? WordStatus.skipped : WordStatus.pending;
      default:
        return WordStatus.pending;
    }
  }

  /// ? NEW: Resume from existing session
  /// ✅ PREMIUM ONLY: FREE users cannot resume session
  Future<void> resumeFromSession(Map<String, dynamic> session) async {
    // ✅ PREMIUM GATE: Check if user can resume session
    final canResume =
        _premiumProvider?.canAccess(PremiumFeature.sessionResume) ?? false;
    if (!canResume) {
      print('❌ Resume Session: Feature not available for FREE users');
      _errorMessage = 'Resume session is a premium feature';
      notifyListeners();
      return;
    }

    print('🔄 Resuming session: ${session['session_id']}');
    print(
      '   Location: Surah ${session['surah_id']}, Ayah ${session['ayah']}, Word ${(session['position'] ?? 0) + 1}',
    );

    try {
      // Connect WebSocket if not connected
      if (!_webSocketService.isConnected) {
        print('?? Connecting to WebSocket...');
        await _webSocketService.connect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Send resume request
      _webSocketService.sendResumeSession(
        sessionId: session['session_id'],
        surahNumber: session['surah_id'],
        position: session['position'],
      );

      print('? Resume request sent, waiting for backend response...');
    } catch (e) {
      print('? Failed to resume session: $e');
      _errorMessage = 'Failed to resume session: $e';
      notifyListeners();
    }
  }

  /// ? NEW: Continue session (restore word colors from backend)
  /// This is like Tarteel - loads all previous word status from Redis
  Future<void> continueSession(String sessionId) async {
    try {
      print('?? Continuing session: $sessionId');

      // Connect WebSocket if not connected
      if (!_webSocketService.isConnected) {
        print('?? Connecting to WebSocket...');
        await _webSocketService.connect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Send continue request - this will load word_status_map from Redis
      _webSocketService.sendContinueSession(sessionId: sessionId);

      print(
        '? Continue request sent, waiting for backend response with word colors...',
      );
    } catch (e) {
      print('? Failed to continue session: $e');
      _errorMessage = 'Failed to continue session: $e';
      notifyListeners();
    }
  }

  /// ? NEW: Check for resumable session (internal)
  Future<void> _checkForResumableSession() async {
    try {
      if (!_authService.isAuthenticated) {
        print('?? User not authenticated, no resumable session');
        _hasResumableSession = false;
        return;
      }

      final userUuid = _authService.userId;
      if (userUuid == null) {
        print('?? User UUID is null');
        _hasResumableSession = false;
        return;
      }

      print('?? Checking for resumable session...');
      final latestSession = await _supabaseService.getResumableSession(
        userUuid,
      );

      if (latestSession != null) {
        print('? Found resumable session: ${latestSession['session_id']}');
        print(
          '   Surah: ${latestSession['surah_id']}, Ayah: ${latestSession['ayah']}',
        );
        _hasResumableSession = true;
      } else {
        print('?? No resumable session found');
        _hasResumableSession = false;
      }

      notifyListeners();
    } catch (e) {
      print('? Error checking for resumable session: $e');
      _hasResumableSession = false;
      notifyListeners();
    }
  }

  /// ? NEW: Resume last session (called by button)
  Future<void> resumeLastSession() async {
    try {
      if (!_authService.isAuthenticated) {
        print('?? Cannot resume: User not authenticated');
        return;
      }

      final userUuid = _authService.userId;
      if (userUuid == null) {
        print('?? Cannot resume: User UUID is null');
        return;
      }

      print('?? Fetching resumable session...');
      final session = await _supabaseService.getResumableSession(userUuid);

      if (session != null) {
        print('? Resuming session: ${session['session_id']}');
        await resumeFromSession(session);
        _hasResumableSession = false; // Clear flag after resume
        notifyListeners();
      } else {
        print('?? No session to resume');
        _errorMessage = 'No paused session found';
        notifyListeners();
      }
    } catch (e) {
      print('? Error resuming last session: $e');
      _errorMessage = 'Failed to resume session: $e';
      notifyListeners();
    }
  }

  Future<void> startRecording() async {
    print('?? startRecording(): Checking WebSocket...');

    // ? OPTIMIZED: Fast connection check
    // WebSocket sudah pre-connected di background saat page load
    // Jika belum ready, tunggu max 2 detik
    final isReady = await _ensureConnected(timeoutMs: 2000);
    if (!isReady) {
      print('? startRecording(): WebSocket not ready!');
      _errorMessage = 'Cannot connect to server';
      notifyListeners();
      return;
    }
    print('? startRecording(): WebSocket ready!');

    try {
      print('✅ startRecording(): Connected, clearing state...');
      _tartibStatus.clear();
      // ? FIX: Don't clear wordStatusMap if resuming from history (colors already applied)
      if (resumeSessionId == null) {
        _wordStatusMap.clear();
        print('   Cleared wordStatusMap (new session)');
      } else {
        print('   Keeping wordStatusMap (resuming session: $resumeSessionId)');
      }
      _expectedAyah = 1;
      _sessionId = resumeSessionId; // ? Use existing session_id if resuming
      _errorMessage = '';

      // ✅ FIX: Determine surah ID with proper priority
      int recordingSurahId;

      if (suratId != null) {
        // Direct surah navigation
        recordingSurahId = suratId!;
        appLogger.log('RECORDING', 'Using direct suratId: $recordingSurahId');
      } else if (_determinedSurahId != null) {
        // From page/juz navigation - use determined surah
        recordingSurahId = _determinedSurahId!;
        appLogger.log(
          'RECORDING',
          'Using determined suratId from page: $recordingSurahId',
        );
      } else if (_ayatList.isNotEmpty) {
        // Fallback: use first ayat's surah
        recordingSurahId = _ayatList.first.surah_id;
        appLogger.log(
          'RECORDING',
          'Fallback: Using first ayat surah: $recordingSurahId',
        );
      } else {
        throw Exception(
          'Cannot determine surah ID for recording - no data loaded',
        );
      }

      print(
        '📤 startRecording(): Sending START message for surah $recordingSurahId...',
      );

      // ? Send with page/juz info if available
      final firstAyah = _ayatList.isNotEmpty ? _ayatList.first.ayah : 1;

      // ✅ FIX: isResume true ONLY when resumeSessionId is set (from Resume History)
      final bool shouldResume = resumeSessionId != null;

      _webSocketService.sendStartRecording(
        recordingSurahId,
        pageId: pageId,
        juzId: juzId,
        ayah: firstAyah,
        isFromHistory: isFromHistory,
        sessionId: resumeSessionId,
        isResume:
            shouldResume, // ✅ NEW: Backend will restore words only if true
      );

      print('🎙️ startRecording(): Starting audio recording...');
      await _audioService.startRecording(
        onAudioChunk: (base64Audio) {
          if (_webSocketService.isConnected) {
            _webSocketService.sendAudioChunk(base64Audio);
          }
        },
      );
      _hideUnreadAyat = true;
      _isRecording = true;
      appLogger.log('RECORDING', 'Started for surah $recordingSurahId');
      print('✅ startRecording(): Recording started successfully');
      notifyListeners();
    } catch (e) {
      print('❌ startRecording(): Exception: $e');
      _errorMessage = 'Failed to start: $e';
      _isRecording = false;
      appLogger.log('RECORDING_ERROR', e.toString());
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    print('🛑 stopRecording(): Called');
    try {
      await _audioService.stopRecording();
      _webSocketService
          .sendPauseRecording(); // ? Changed: PAUSE (was sendStopRecording)
      _isRecording = false;
      appLogger.log('RECORDING', 'Stopped');
      print('✅ stopRecording(): Stopped successfully');
      notifyListeners();
    } catch (e) {
      print('❌ stopRecording(): Exception: $e');
      _errorMessage = 'Failed to stop: $e';
      appLogger.log('RECORDING_ERROR', e.toString());
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> reconnect() async {
    _errorMessage = 'Reconnecting...';
    _isConnected = false;
    notifyListeners();

    _webSocketService.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await _connectWebSocket();

    if (_isConnected && _sessionId != null) {
      _webSocketService.sendRecoverSession(_sessionId!);
    }

    _errorMessage = _isConnected ? '' : 'Reconnect failed';
    notifyListeners();
  }

  // REPLACE method updateVisiblePage dengan:
  void updateVisiblePage(int pageNumber) {
    if (_currentPage != pageNumber) {
      appLogger.log(
        'VISIBLE_PAGE',
        'Updating visible page: $_currentPage ? $pageNumber',
      );

      _currentPage = pageNumber;

      if (!_isQuranMode) {
        _listViewCurrentPage = pageNumber;
        appLogger.log('VISIBLE_PAGE', 'List view position saved: $pageNumber');
      }

      _updateSurahNameForPage(pageNumber);

      if (_ayatList.isNotEmpty) {
        final firstAyatOnPage = _ayatList.firstWhere(
          (a) => a.page == pageNumber,
          orElse: () => _ayatList.first,
        );
        final newIndex = _ayatList.indexOf(firstAyatOnPage);
        if (newIndex >= 0) {
          _currentAyatIndex = newIndex;
          appLogger.log(
            'VISIBLE_PAGE',
            'Updated ayat index to: $_currentAyatIndex',
          );
        }
      }

      // ? FIX: Don't preload if scrolling (prevents database lock)
      if (!_isQuranMode) {
        Future.microtask(() => _preloadAdjacentPagesAggressively());
      }

      notifyListeners();
    }
  }

  /// ✅ ULTIMATE: Update AppBar info instantly without triggering full UI rebuild
  void updateVisiblePageQuiet(int pageNumber) {
    // 1. Update internal state silent (tanpa notifyListeners)
    if (_currentPage != pageNumber) {
      _currentPage = pageNumber;
      if (!_isQuranMode) {
        _listViewCurrentPage = pageNumber;
      }
    }

    // 2. Resolve Metadata Instantly (Synchronous)
    String surahName = _suratNameSimple;
    int juzNum = 1; // Default fallback

    try {
      // Priority: Metadata Cache (Instant)
      final surahIds = _metadataCache.getSurahIdsForPage(pageNumber);
      if (surahIds.isNotEmpty) {
        final surahId = surahIds.first;
        final surahMeta = _metadataCache.getSurah(surahId);
        if (surahMeta != null) {
          surahName = surahMeta['name_simple'] ?? surahName;
        }

        // Calculate Juz accurately without AyatData
        // (Menggunakan helper service atau logic estimasi juz yang ada)
        // Disini kita gunakan existing method jika memungkinkan, atau fallback ke
        // metadata mapping jika JuzService support getJuzByPage (ideal)
        // Untuk sekarang kita gunakan calculation dari SQLite service yang cached
        juzNum = _sqliteService.calculateJuzAccurate(surahId, 1);
      }
    } catch (e) {
      // Silent fail, keep previous data
    }

    // 3. Update Notifier (Hanya widget AppBar yang mendengar ini yang akan rebuild)
    // Ini menghilangkan flicker pada body aplikasi
    appBarNotifier.value = PageDisplayData(
      pageNumber: pageNumber,
      surahName: surahName,
      juzNumber: juzNum,
    );

    // 4. Trigger Background Preload (tetap jalan tapi low priority)
    if (!_isQuranMode) {
      // Gunakan microtask agar tidak memblock UI frame saat ini
      Future.microtask(() => _preloadAdjacentPagesAggressively());
    }
  }

  /// ✅ NEW: Instant metadata update (NO async, NO database)
  void _updateSurahNameForPageInstant(int pageNumber) {
    try {
      // Priority 1: Use metadata cache (INSTANT - no DB query)
      final surahIds = _metadataCache.getSurahIdsForPage(pageNumber);
      if (surahIds != null && surahIds.isNotEmpty) {
        final surahId = surahIds.first;
        final surahMeta = _metadataCache.getSurah(surahId);

        if (surahMeta != null && _determinedSurahId != surahId) {
          _determinedSurahId = surahId;
          _suratNameSimple = surahMeta['name_simple'] as String;
          _suratVersesCount = surahMeta['verses_count'].toString();
          return; // ✅ EXIT - metadata updated instantly
        }
      }

      // Priority 2: Use cached page data (no DB query)
      if (pageCache.containsKey(pageNumber)) {
        final pageLines = pageCache[pageNumber]!;
        for (final line in pageLines) {
          if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
            final surahId = line.ayahSegments!.first.surahId;
            if (_determinedSurahId != surahId) {
              _determinedSurahId = surahId;
              // ✅ Async load in background (won't block UI)
              _sqliteService.getChapterInfo(surahId).then((chapter) {
                _suratNameSimple = chapter.nameSimple;
                _suratVersesCount = chapter.versesCount.toString();
                // ✅ Notify ONLY after background load completes
                notifyListeners();
              });
            }
            return; // ✅ EXIT - will update in background
          }
        }
      }

      // Priority 3: Fallback - use current page ayats
      if (_currentPageAyats.isNotEmpty) {
        final surahId = _currentPageAyats.first.surah_id;
        if (_determinedSurahId != surahId) {
          _determinedSurahId = surahId;
          _sqliteService.getChapterInfo(surahId).then((chapter) {
            _suratNameSimple = chapter.nameSimple;
            _suratVersesCount = chapter.versesCount.toString();
            notifyListeners();
          });
        }
      }
    } catch (e) {
      // ✅ Silent fail - don't spam console
      appLogger.log('SURAH_UPDATE_INSTANT_ERROR', 'Page $pageNumber: $e');
    }
  }

  /// ✅ NEW: Synchronous version for instant AppBar update during navigation
  void _updateSurahNameForPageSync(int pageNumber) {
    try {
      // Priority 1: Use metadata cache (INSTANT)
      final surahIds = _metadataCache.getSurahIdsForPage(pageNumber);
      if (surahIds != null && surahIds.isNotEmpty) {
        final surahId = surahIds.first;
        final surahMeta = _metadataCache.getSurah(surahId);

        if (surahMeta != null && _determinedSurahId != surahId) {
          _determinedSurahId = surahId;
          _suratNameSimple = surahMeta['name_simple'] as String;
          _suratVersesCount = surahMeta['verses_count'].toString();
          return; // ✅ EXIT - metadata updated instantly
        }
      }

      // Priority 2: Use cached page data (no DB query)
      if (pageCache.containsKey(pageNumber)) {
        final pageLines = pageCache[pageNumber]!;
        for (final line in pageLines) {
          if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
            final surahId = line.ayahSegments!.first.surahId;
            if (_determinedSurahId != surahId) {
              _determinedSurahId = surahId;
              // Load chapter info in background (won't block UI)
              _sqliteService.getChapterInfo(surahId).then((chapter) {
                _suratNameSimple = chapter.nameSimple;
                _suratVersesCount = chapter.versesCount.toString();
                // Don't call notifyListeners here - appBarNotifier already updated
              });
            }
            return; // ✅ EXIT - will update in background
          }
        }
      }

      // Priority 3: Fallback - use current page ayats
      if (_currentPageAyats.isNotEmpty) {
        final surahId = _currentPageAyats.first.surah_id;
        if (_determinedSurahId != surahId) {
          _determinedSurahId = surahId;
          _sqliteService.getChapterInfo(surahId).then((chapter) {
            _suratNameSimple = chapter.nameSimple;
            _suratVersesCount = chapter.versesCount.toString();
          });
        }
      }
    } catch (e) {
      appLogger.log('SURAH_UPDATE_SYNC_ERROR', 'Page $pageNumber: $e');
    }
  }

  // ===== DISPOSAL =====
  @override
  void dispose() {
    print('💀 SttController: DISPOSE CALLED for surah $suratId');
    appLogger.log('DISPOSAL', 'Starting cleanup process');

    // ✅ CRITICAL: Set disposal flag FIRST to stop all background tasks
    _isDisposed = true;

    // ✅ Wait a bit for background tasks to check the flag
    Future.delayed(const Duration(milliseconds: 100));

    _verseChangeSubscription?.cancel();
    _wordHighlightSubscription?.cancel();
    _listeningAudioService?.dispose();
    ReciterDatabaseService.dispose();

    _wsSubscription?.cancel();
    _connectionSubscription?.cancel();

    _audioService.dispose();
    _scrollController.dispose();

    // ✅ Dispose logger LAST (after background tasks stopped)
    appLogger.dispose();

    super.dispose();
  }
}

// ✅ NEW: Lightweight model for AppBar updates (No database dependency)
class PageDisplayData {
  final int pageNumber;
  final String surahName;
  final int juzNumber;
  final bool isArabic;

  const PageDisplayData({
    required this.pageNumber,
    required this.surahName,
    required this.juzNumber,
    this.isArabic = false,
  });

  // Default state
  factory PageDisplayData.initial() {
    return const PageDisplayData(
      pageNumber: 1,
      surahName: 'Al-Fatihah',
      juzNumber: 1,
    );
  }
}
