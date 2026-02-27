import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/models/playback_settings_model.dart';
import 'package:cuda_qurani/models/quran_models.dart';
import 'package:cuda_qurani/screens/main/home/services/juz_service.dart';
import 'package:cuda_qurani/screens/main/stt/database/db_helper.dart';
import 'package:cuda_qurani/services/global_ayat_services.dart';
import 'package:cuda_qurani/services/listening_audio_services.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/services/reciter_database_service.dart';
import 'package:cuda_qurani/screens/main/stt/utils/ayah_char_mapper.dart';
import '../data/models.dart' hide TartibStatus;
import '../services/quran_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'package:cuda_qurani/services/audio_service.dart';
import 'package:cuda_qurani/services/websocket_service.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/services/auth_service.dart';
import 'package:cuda_qurani/config/app_config.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/ayah_options_sheet.dart';
import 'package:cuda_qurani/models/premium_features.dart';
import 'package:cuda_qurani/screens/main/stt/services/mutashabihat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SttController extends ChangeNotifier {
  // Core State
  bool _isLoading = true;
  String? _errorMessage = '';
  List<AyatData> _ayatList = [];
  // ✅ O(1) LOOKUP: Map "surahId:ayahNumber" -> Index in _ayatList
  final Map<String, int> _ayahIndexMap = {};
  // ✅ O(1) LOOKUP: Map "surahId:ayahNumber" -> Ayah index for CURRENT page
  final Map<String, int> _currentPageAyahIndexMap = {};

  // ✅ PERF FIX: Pre-compiled RegExp for stripping markers — was compiled per-word inside loops
  static final RegExp _markerStripper = RegExp(
    r'[\u0660-\u0669\u06F0-\u06F90-9\u06DD\uFD3E\uFD3F\u06D4\u066B\u066C\u0600-\u060F\(\)\[\]\{\}]',
  );

  final int? suratId;
  final int? pageId;
  final int? juzId;
  final bool isFromHistory;
  final Map<String, dynamic>? initialWordStatusMap;
  final String? resumeSessionId;
  final ValueNotifier<PageDisplayData> appBarNotifier = ValueNotifier(
    PageDisplayData.initial(),
  );
  int? _determinedSurahId;

  MushafLayout _mushafLayout = MushafLayout.qpc;
  MushafLayout get mushafLayout => _mushafLayout;

  // ✅ NEW: Highlight specific ayah (from deep link)
  final int? highlightAyahId;

  // ✅ NEW: Navigated/Highlighted Ayah State (Persistent)
  int? _navigatedAyahId;
  int? get navigatedAyahId => _navigatedAyahId;

  void onAyahNavigated(int ayahId) {
    _navigatedAyahId = ayahId;
    notifyListeners();
  }

  void clearNavigatedAyah() {
    if (_navigatedAyahId == null) return;
    _navigatedAyahId = null;
    notifyListeners();
  }

  // ✅ Granular Context State
  int? _activeSurahId;
  int? _activeAyahNumber;
  int? get activeSurahId => _activeSurahId;
  int? get activeAyahNumber => _activeAyahNumber;

  // ✅ TAMBAHKAN getter untuk total pages (dynamic based on layout)
  int get totalPages => _mushafLayout.totalPages;

  int? _topVerseId; // ✅ NEW: Tracks the verse at the top of the viewport
  int? _topVersePage;
  int? get topVerseId => _topVerseId;

  void updateTopVerse(int ayahId, int pageNumber) {
    if (_topVerseId == ayahId) return;
    _topVerseId = ayahId;
    _topVersePage = pageNumber;

    // ✅ Track top verse only in List View (Mushaf View handles it via page)
    if (_isQuranMode) return;

    // ✅ OPTIMIZATION: Instant Surah/Juz detection from global ayah ID (O(1))
    final context = GlobalAyatService.fromGlobalAyat(ayahId);
    final surahId = context['surah_id']!;
    final ayahNum = context['ayah_number']!;

    _activeSurahId = surahId;
    _activeAyahNumber = ayahNum;

    // ✅ UI THROTTLING: Update AppBar only IF surah or juz CHANGES
    // This prevents expensive rebuilds of the UI overlay every time a single verse scrolls.
    final currentData = appBarNotifier.value;
    final juzNum = _sqliteService.calculateJuzAccurate(surahId, ayahNum);

    if (currentData.surahName == 'Surah' || // Initial state
        _determinedSurahId != surahId ||
        currentData.juzNumber != juzNum ||
        currentData.pageNumber != pageNumber) {
      _determinedSurahId = surahId;

      // Load Surah metadata for AppBar (priority: Cache -> Background DB)
      final surahMeta = _metadataCache.getSurah(surahId);
      if (surahMeta != null) {
        _suratNameSimple = surahMeta['name_simple'] as String;
        _suratVersesCount = surahMeta['verses_count'].toString();

        appBarNotifier.value = PageDisplayData(
          pageNumber: pageNumber,
          surahName: _suratNameSimple,
          juzNumber: juzNum,
          isArabic: false, // Could be enhanced later
        );
      } else {
        // Fallback for metadata (unlikely if preloaded)
        _sqliteService.getChapterInfo(surahId).then((chapter) {
          _suratNameSimple = chapter.nameSimple;
          _suratVersesCount = chapter.versesCount.toString();

          appBarNotifier.value = PageDisplayData(
            pageNumber: pageNumber,
            surahName: _suratNameSimple,
            juzNumber: juzNum,
          );
        });
      }
    }
  }

  // ✅ Phase 7: Estimation methods removed — anchor-based architecture
  // uses offset 0.0 by construction, no estimation needed.

  SttController({
    this.suratId,
    this.pageId,
    this.juzId,
    this.isFromHistory = false,
    this.initialWordStatusMap,
    this.resumeSessionId, // ? NEW
    this.highlightAyahId, // ✅ NEW
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

    // ✅ NEW: Initialize synchronization anchors
    if (highlightAyahId != null) {
      _topVerseId = highlightAyahId;
      _topVersePage = pageId;
      print(
        '📍 SttController: Initialized synchronization anchor to Verse $highlightAyahId',
      );
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
    _renderCache.clear(); // ✅ Clear render cache
    _geometryCache.clear(); // ✅ Clear geometry cache
    _sqliteService.clearPageCache();
    _ayahIndexMap.clear();
    _currentPageAyahIndexMap.clear();
    _prebuiltSpans.clear(); // ✅ Clear span cache
    _lastLoadedAyatsPage = null;
    _lastPreloadedPage = null;
    await _metadataCache.rebuildForLayout(
      newLayout,
    ); // ✅ REBUILD METADATA MAPPING

    // ✅ STEP 6: Accurate Page Mapping (Verse-Centeric)
    // Instead of just clamping, we find the page for the verse we were looking at
    int? resumeAyahId = _topVerseId;
    if (resumeAyahId == null && _currentPageAyats.isNotEmpty) {
      resumeAyahId = _currentPageAyats.first.id;
    }

    if (resumeAyahId != null) {
      final surahId = resumeAyahId ~/ 1000;
      final ayahNumber = resumeAyahId % 1000;
      final newPage = await _sqliteService.getPageForAyah(surahId, ayahNumber);
      _currentPage = newPage;
      _listViewCurrentPage = newPage;
      _topVerseId = resumeAyahId; // ✅ Persist for initialization jump
      print(
        '[LAYOUT_SWITCH] 📍 Mapped context to Page $_currentPage (Ayah $surahId:$ayahNumber)',
      );
    } else {
      // Fallback: Clamp if no verse context
      if (_currentPage > newLayout.totalPages)
        _currentPage = newLayout.totalPages;
      if (_listViewCurrentPage > newLayout.totalPages)
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
  final MutashabihatService _mutashabihatService = MutashabihatService();
  final AppLogger appLogger = AppLogger();
  final SupabaseService _supabaseService = SupabaseService(); // ? NEW
  final AuthService _authService = AuthService(); // ? NEW

  // ? NEW: Resumable session detection
  bool _hasResumableSession = false;
  bool get hasResumableSession => _hasResumableSession;

  // ✅ DUAL-PHASE RENDERING STATE
  bool _isSwiping = false;
  Timer? _settleTimer;
  final Map<String, List<InlineSpan>> _prebuiltSpans = {};

  // STT State
  int _currentAyatIndex = -1;
  String _suratNameSimple = '';
  String _suratVersesCount = '';
  DateTime? _sessionStartTime;
  int?
  _recordingSurahId; // ✅ NEW: Anchors the STT session to prevent race conditions during swipe
  Map<int, AyatProgress> _ayatProgress = {};

  // UI State
  bool _isUIVisible = true;
  bool _isQuranMode = true;
  bool _hideUnreadAyat = false;
  bool _showLogs = false;
  int _currentPage = 1;
  int _listViewCurrentPage = 1;
  bool _isDataLoaded = false;
  bool _isDisposed = false;
  bool _isTransitioningMode = false; // ✅ NEW Phase 3: Input latency guard
  List<AyatData> _currentPageAyats = [];
  final ScrollController _scrollController = ScrollController();

  // Backend Integration - Recording & WebSocket
  final AudioService _audioService = AudioService();

  // ✅ AYAH LONG-PRESS OPTIONS STATE
  AyahSegment? _selectedAyahForOptions;
  AyahSegment? get selectedAyahForOptions => _selectedAyahForOptions;

  void setSelectedAyahForOptions(AyahSegment? segment) {
    if (_selectedAyahForOptions == segment) return;
    _selectedAyahForOptions = segment;
    notifyListeners();
  }

  void clearSelectedAyahForOptions() {
    if (_selectedAyahForOptions == null) return;
    _selectedAyahForOptions = null;
    notifyListeners();
  }

  late final WebSocketService _webSocketService;
  bool _isRecording = false;
  bool _isConnected = false;
  String? _sessionId;
  int _expectedAyah = 1;
  final Map<int, TartibStatus> _tartibStatus = {};
  final Map<String, Map<int, WordStatus>> _wordStatusMap = {};
  int _wordStatusRevision = 0; // ✅ NEW: State tracker for wordStatusMap changes
  int get wordStatusRevision => _wordStatusRevision;

  List<WordFeedback> _currentWords = [];
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
    int audioTotal,
    int surahId,
    int ayahNumber, {
    int minWordIndex = 0,
  }) {
    // ✅ Phase 3 GUARD: Return last stable index during mode transitions
    if (_isTransitioningMode) return _lastClampedIndex;

    // Universal Ratio Calculation (Round 10)
    // ratio = (current - min) / (max - min)
    double ratio = 0.0;
    if (audioTotal > minWordIndex) {
      ratio =
          (audioWordIndex - minWordIndex) /
          (audioTotal - minWordIndex).toDouble();
    } else {
      // ✅ FIX Round 10: If only 1 audio word, stay at ratio 0.0 (first word)
      // This prevents jumping to the end-of-ayah symbol in QPC
      ratio = 0.0;
    }

    // ✅ O(1) LOOKUP: Replace expensive firstWhere scans
    final key = _wordKey(surahId, ayahNumber);
    final currentPageIndex = _currentPageAyahIndexMap[key];
    final globalIndex = _ayahIndexMap[key];

    final ayat = currentPageIndex != null
        ? _currentPageAyats[currentPageIndex]
        : (globalIndex != null ? _ayatList[globalIndex] : null);

    if (ayat == null) {
      return 0; // Fallback
    }

    // ✅ CRITICAL FIX Round 10: In QPC layout, the LAST word element is the Ayah Number symbol.
    // We MUST exclude it from the highlightable range.
    int layoutWordCount = ayat.words.length;
    if (_mushafLayout == MushafLayout.qpc && layoutWordCount > 1) {
      layoutWordCount -= 1; // Filter out the Ayah Number symbol
    }

    final mappedIndex = (ratio * layoutWordCount).floor();
    final clampedIndex = mappedIndex.clamp(0, layoutWordCount - 1);
    _lastClampedIndex = clampedIndex; // ✅ Record for guard

    final logTag = _mushafLayout == MushafLayout.qpc ? 'QPC' : 'STT';
    print(
      '📍 MAPPING (Round 10 - $logTag): Audio $audioWordIndex [$minWordIndex-$audioTotal] -> Ratio ${ratio.toStringAsFixed(2)} -> Layout $clampedIndex/$layoutWordCount (Ayah $surahId:$ayahNumber)',
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
  final Map<int, QuranPageRenderModel> _renderCache = {}; // ✅ NEW: Phase 2
  final Map<int, PageGeometry> _geometryCache = {}; // ✅ NEW: Coordinate cache
  final MetadataCacheService _metadataCache = MetadataCacheService();
  double? _viewportWidth; // ✅ Screen width for geometry computation

  Map<int, PageGeometry> get geometryCache => _geometryCache;

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
  bool get isDataLoaded => _isDataLoaded;
  bool get isTransitioningMode => _isTransitioningMode;
  List<AyatData> get currentPageAyats => _currentPageAyats;

  // ✅ Translation toggle
  bool _showTranslationInListView = true;
  bool get showTranslationInListView => _showTranslationInListView;

  bool _showTafsirInListView = true;
  bool get showTafsirInListView => _showTafsirInListView;

  Future<void> setShowTranslation(bool value) async {
    if (_showTranslationInListView == value) return;
    _showTranslationInListView = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_translation_list_view', value);
  }

  Future<void> setShowTafsir(bool value) async {
    if (_showTafsirInListView == value) return;
    _showTafsirInListView = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_tafsir_list_view', value);
  }

  Future<void> _loadTranslationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _showTranslationInListView =
        prefs.getBool('show_translation_list_view') ?? true;
    _showTafsirInListView = prefs.getBool('show_tafsir_list_view') ?? true;
  }

  // ✅ ACCESSORS FOR MAPS
  Map<String, int> get ayahIndexMap => _ayahIndexMap;
  Map<String, int> get currentPageAyahIndexMap => _currentPageAyahIndexMap;
  bool get isSwiping => _isSwiping;
  Map<String, List<InlineSpan>> get prebuiltSpans => _prebuiltSpans;

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
  bool get isPaused =>
      _listeningAudioService?.isPaused ?? false; // ✅ RELIABLE getter for UI

  // Word Status Tracking (O(1) optimization)
  final Map<String, int> _lastHighlightedIdx = {};
  String? _currentHighlightKey;
  int? _currentHighlightWordIdx;
  int _lastClampedIndex = 0; // ✅ Tracking for transition guard

  String? get currentHighlightKey => _currentHighlightKey;
  int? get currentHighlightWordIdx => _currentHighlightWordIdx;

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
      await _mutashabihatService.initialize();

      _mushafLayout = _sqliteService.currentLayout;
      appLogger.log(
        'APP_INIT',
        'Loaded layout: ${_mushafLayout.displayName} (${_mushafLayout.totalPages} pages)',
      );

      // ✅ Load persisted user settings (translation toggle, etc.)
      await _loadTranslationSetting();

      // ðŸš€ STEP 1: Determine target page FIRST
      int targetPage = await _determineTargetPage();
      _currentPage = targetPage;
      _listViewCurrentPage = targetPage;
      _isDataLoaded = false;

      appLogger.log('APP_INIT', 'Target page determined: $targetPage');

      // 🚀 STEP 2: Load ONLY that page (minimal data)
      await _loadSinglePageData(targetPage);

      // ✅ NEW: Highlight specific ayah if requested (Deep Link)
      if (highlightAyahId != null) {
        final index = _currentPageAyats.indexWhere(
          (a) => a.ayah == highlightAyahId,
        );
        if (index != -1) {
          _currentAyatIndex = index;
          appLogger.log(
            'APP_INIT',
            'Highlighting deep link ayah: $highlightAyahId (index $index)',
          );
        }
      }

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
          // ✅ Aggressive preloading
          _sqliteService.preloadAllPagesInBackground();
          _preloadAdjacentPagesAggressively();
        }
      });
    } catch (e) {
      final errorString = 'Failed to initialize: $e';
      appLogger.log('APP_INIT_ERROR', errorString);
      _errorMessage = errorString;
      _isLoading = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ NEW: Play specific Ayah (Start Listening from here)
  Future<void> playAyah(AyahSegment segment) async {
    appLogger.log(
      'AUDIO',
      'Requesting playback for Surah ${segment.surahId}:${segment.ayahNumber}',
    );

    // Default to Mishari for now (TODO: User preference)
    const reciterIdentifier = 'mishari-alafasy';

    // Get Surah stats to find endVerse (play until end of Surah)
    final surahMeta = MetadataCacheService().getSurah(segment.surahId);
    final endVerse = surahMeta?['verses_count'] as int? ?? segment.ayahNumber;

    final settings = PlaybackSettings(
      startSurahId: segment.surahId,
      startVerse: segment.ayahNumber,
      endSurahId: segment.surahId,
      endVerse: endVerse,
      reciter: reciterIdentifier,
    );

    await startListening(settings);
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
      int targetPage;
      try {
        // ✅ CORRECTED: Use getPageForAyah instance method
        targetPage = await _sqliteService.getPageForAyah(
          settings.startSurahId,
          settings.startVerse,
        );
      } catch (e) {
        print('[DB] Error getting page number: $e');
        // Fallback: stay on current page if DB fails, don't force page 1
        targetPage = _currentPage;
      }

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
        if (_isTransitioningMode)
          return; // ✅ Phase 3 GUARD: Suppress during transition

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
          // ✅ CORRECTED: Use getPageForAyah instance method
          final targetPage = await _sqliteService.getPageForAyah(
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

        // ✅ REFINE: Don't clear highlights on verse change, wait for next highlight
        // This prevents the "blink" between ayahs
        // final allKeys = _wordStatusMap.keys.toList();
        // for (final key in allKeys) {
        //   _wordStatusMap[key]?.clear();
        // }
        // print('   🧹 Removed aggressive clear highlights (${allKeys.length} ayahs)');

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

      _wordHighlightSubscription = _listeningAudioService!.wordHighlightStream?.listen((
        event, // 🔴 UPDATED: WordHighlight event
      ) {
        if (_isTransitioningMode)
          return; // ✅ Phase 3 GUARD: Suppress during transition

        final audioWordIndex = event.index;
        final audioTotal = event.total;
        // 🔇 Reduced verbose logging
        // print('🎧 Word highlight event received (audio index): $audioWordIndex');

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
          /* print(
            '   Current ayat: ${currentAyat.surah_id}:${currentAyat.ayah} (${currentAyat.words.length} words)',
          ); */
        } else {
          print(
            '❌ Invalid _currentAyatIndex: $_currentAyatIndex (pageAyats: ${_currentPageAyats.length})',
          );
          return; // ? EXIT early if invalid index
        }

        if (currentAyat != null) {
          // 🆕 MAP audio word index to layout-specific word index (Round 7: Universal)
          final layoutWordIndex = _mapAudioIndexToLayoutIndex(
            event.index,
            event.total,
            currentAyat.surah_id,
            currentAyat.ayah,
            minWordIndex: event.min,
          );

          final currentKey = _wordKey(currentAyat.surah_id, currentAyat.ayah);

          // 🔇 Reduced verbose mapping logs
          /* 
          print(
            '🗺️ WORD INDEX MAPPING: audio=$audioWordIndex → layout=$layoutWordIndex (${_mushafLayout.displayName})',
          );
          print(
            '   Ayat: ${currentAyat.surah_id}:${currentAyat.ayah}, Words in layout: ${currentAyat.words.length}',
          );
          print(
            '   Current _wordStatusMap[$currentKey] before update: ${_wordStatusMap[currentKey]}',
          );
          */
          final words = currentAyat.words;

          // ✅ CRITICAL: Validate layoutWordIndex before accessing array
          if (layoutWordIndex < 0 || layoutWordIndex >= words.length) {
            print(
              '❌ Invalid layoutWordIndex: $layoutWordIndex for ayat ${currentAyat.surah_id}:${currentAyat.ayah} (has ${words.length} words)',
            );
            return; // ✅ EXIT early if invalid word index
          }

          if (!_wordStatusMap.containsKey(currentKey)) {
            _wordStatusMap[currentKey] = {};
            // ✅ Initialize all words as pending ONLY on first access
            for (int i = 0; i < words.length; i++) {
              _wordStatusMap[currentKey]![i] = WordStatus.pending;
            }
          }

          // ✅ O(1) OPTIMIZATION: Clear ONLY the previous processing word directly
          final lastIdx = _lastHighlightedIdx[currentKey];

          // ⚡️ PERFORMANCE: Early exit if we are STILL on the same layout word
          // This prevents redundant notifyListeners() and Mushaf rebuilds
          if (lastIdx == layoutWordIndex) return;

          if (lastIdx != null) {
            _wordStatusMap[currentKey]![lastIdx] = WordStatus.pending;
          }
          _lastHighlightedIdx[currentKey] = layoutWordIndex;

          // ✅ CLEAR PREVIOUS AYAH if we just transitioned to a new one
          // This replaces the expensive allKeys.forEach loop
          _wordStatusMap.forEach((key, statusMap) {
            if (key != currentKey && statusMap.isNotEmpty) {
              statusMap.clear();
            }
          });

          // Set current word as processing
          if (layoutWordIndex >= 0 && layoutWordIndex < words.length) {
            _wordStatusMap[currentKey]![layoutWordIndex] =
                WordStatus.processing;
            _currentHighlightKey = currentKey;
            _currentHighlightWordIdx = layoutWordIndex;
            _wordStatusRevision++; // ✅ NEW: Sync UI
            /* print(
              '   ✨ Highlighted word $layoutWordIndex in ${currentAyat.surah_id}:${currentAyat.ayah}',
            ); */
          } else {
            print(
              '   ⚠️ Cannot highlight: layoutWordIndex $layoutWordIndex out of bounds (0-${words.length - 1})',
            );
          }

          _wordStatusRevision++; // ✅ NEW: Trigger rebuild for UI
          if (!_isTransitioningMode)
            notifyListeners(); // ✅ Suppress during transition
        }
      });

      // ?? Start playback
      await _listeningAudioService!.startPlayback();

      // ✅ FIX: Removed erroneous _isRecording = true; (Listening mode is passive)
      _hideUnreadAyat = false;
      _wordStatusRevision++; // ✅ Sync UI

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
      _currentHighlightKey = null; // ✅ Reset instantly
      _currentHighlightWordIdx = null; // ✅ Reset instantly
      _recordingSurahId = null; // ✅ Release anchor
      _wordStatusRevision++; // ✅ NEW: Force one last clean repaint

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

  /// ✅ NEW: Handle listening mode completion
  Future<void> _handleListeningCompletion() async {
    print('🎵 Listening session completed');

    try {
      // ✅ CRITICAL FIX: Delay BEFORE resetting isListeningMode
      // This ensures the last word highlight (e.g., "لِلْمُتَّقِينَ") is visible
      // Without this, the UI renders transparent because isListeningMode is already false
      print('⏳ Waiting 500ms for last word highlight to be visible...');
      notifyListeners(); // Trigger UI update for the last highlight
      await Future.delayed(const Duration(milliseconds: 500));

      // Stop audio playback (if not already stopped)
      await _listeningAudioService?.stopPlayback();

      // Cancel subscriptions
      await _verseChangeSubscription?.cancel();
      await _wordHighlightSubscription?.cancel();

      // Dispose audio service
      _listeningAudioService?.dispose();
      _listeningAudioService = null;

      // ✅ CRITICAL: Reset all state flags AFTER delay
      _isListeningMode = false;
      _isRecording = false;
      _playbackSettings = null;

      // Clear visual states
      _tartibStatus.clear();
      _wordStatusMap.clear();
      _lastHighlightedIdx.clear();
      _currentHighlightKey = null; // ✅ NEW: Reset instantly on auto-completion
      _currentHighlightWordIdx =
          null; // ✅ NEW: Reset instantly on auto-completion
      _wordStatusRevision++; // ✅ NEW: Force one last clean repaint

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

      // Get page number for this ayah using instance service
      // ✅ FIX: Use _sqliteService instead of static LocalDatabaseService
      int page;
      try {
        page = await _sqliteService.getPageForAyah(surahNum, ayahNum);
      } catch (e) {
        print('[DB] Error getting page number (Juz $juzId): $e');
        page = 1; // Fallback
      }

      appLogger.log(
        'NAV',
        'Juz $juzId starts at page $page (${surahNum}:${ayahNum})',
      );
      return page;
    }

    if (suratId != null) {
      appLogger.log('NAV', 'Navigation from Surah $suratId');

      // Get first page of this surah
      // ✅ FIX: Use _sqliteService instead of static LocalDatabaseService
      int page;
      try {
        page = await _sqliteService.getPageForAyah(suratId!, 1);
      } catch (e) {
        print('[DB] Error getting page number (Surah $suratId): $e');
        page = 1; // Fallback
      }

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
          // ✅ FIX: Update AppBar notifier immediately after metadata loaded
          final juzNum = _sqliteService.calculateJuzAccurate(
            _determinedSurahId!,
            1,
          );
          appBarNotifier.value = PageDisplayData(
            pageNumber: pageNumber,
            surahName: _suratNameSimple,
            juzNumber: juzNum,
          );

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
            // ✅ PRE-SORT WORDS: Eliminate O(N log N) from build()
            ayahWords.sort((a, b) => a.wordNumber.compareTo(b.wordNumber));

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
            // ✅ Populate O(1) map
            _ayahIndexMap['$surahId:$ayahNum'] = _ayatList.length - 1;
          }

          // Sort by surah then ayah
          _ayatList.sort((a, b) {
            if (a.surah_id != b.surah_id)
              return a.surah_id.compareTo(b.surah_id);
            return a.ayah.compareTo(b.ayah);
          });

          // ✅ Atomic Sync
          _syncAyahIndices();

          // ✅ PRECOMPUTE RENDER MODEL: Eliminate O(N) map aggregation from build()
          _precomputeRenderModel(pageNumber);

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

          // ✅ Atomic Sync Page Map
          _syncCurrentPageAyahIndices();

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

        // ✅ Atomic Sync
        _syncAyahIndices();

        appLogger.log('DATA_OPTIMIZED', 'Loaded ${_ayatList.length} ayats');
      }

      // ✅ PRE-SORT WORDS in _ayatList (if not already handled)
      for (final ayah in _ayatList) {
        ayah.words.sort((a, b) => a.wordNumber.compareTo(b.wordNumber));
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

      // ✅ PRECOMPUTE RENDER MODEL
      _precomputeRenderModel(targetPage);

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

  // ✅ NEW: Atomic map synchronization for O(1) lookups
  void _syncAyahIndices() {
    _ayahIndexMap.clear();
    for (int i = 0; i < _ayatList.length; i++) {
      final a = _ayatList[i];
      _ayahIndexMap['${a.surah_id}:${a.ayah}'] = i;
    }
  }

  void _syncCurrentPageAyahIndices() {
    _currentPageAyahIndexMap.clear();
    for (int i = 0; i < _currentPageAyats.length; i++) {
      final a = _currentPageAyats[i];
      _currentPageAyahIndexMap['${a.surah_id}:${a.ayah}'] = i;
    }
  }

  Future<void> _loadCurrentPageAyats({bool skipNotify = false}) async {
    // ✅ OPTIMIZED: Prevent duplicate calls for same page
    if (_lastLoadedAyatsPage == _currentPage) {
      return; // Already loaded for this page
    }

    if (!_isQuranMode) {
      _currentPageAyats = _ayatList;
      _lastLoadedAyatsPage = _currentPage;
      if (!skipNotify)
        notifyListeners(); // ✅ PERF FIX: Skip when caller batches
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

      // ✅ WARMUP: Build spans for current page too
      final fontFamily = _mushafLayout.isGlyphBased
          ? 'p$_currentPage'
          : 'IndoPak-Nastaleeq';
      warmupSpansForPage(_currentPage, fontFamily);

      // ✅ Atomic Sync Page Map
      _syncCurrentPageAyahIndices();

      appLogger.log(
        'DATA',
        'Loaded ${_currentPageAyats.length} ayats for page $_currentPage',
      );

      // ✅ PERF FIX: Skip notification when caller will batch it
      if (!skipNotify) notifyListeners();

      // ✅ Background: Preload adjacent pages AFTER current page is shown
      // This doesn't block UI update
      Future.microtask(() => _preloadAdjacentPagesAggressively());
    } catch (e) {
      appLogger.log('DATA_PAGE_ERROR', 'Error loading page ayats - $e');
      _currentPageAyats = [];
      if (!skipNotify) notifyListeners();
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
        if (_stopPreloading) break;
        if (_currentPage - i >= 1) pagesToPreload.add(_currentPage - i);
        if (_currentPage + i <= totalPages)
          pagesToPreload.add(_currentPage + i);
      }

      final immediatePages = <int>[];
      final backgroundPages = <int>[];

      for (final page in pagesToPreload) {
        if (_isDisposed || _stopPreloading) return;

        if (pageCache.containsKey(page)) continue;

        final serviceCache = _sqliteService.getCachedPage(page);
        if (serviceCache != null) {
          pageCache[page] = serviceCache;
          // Ensure spans/geometry are warmed up if not already
          final fontFamily = _mushafLayout.isGlyphBased
              ? 'p$page'
              : 'IndoPak-Nastaleeq';
          warmupSpansForPage(page, fontFamily);
          continue;
        }

        final distance = (page - _currentPage).abs();
        if (distance <= 10) {
          // Larger "immediate" range for faster startup
          immediatePages.add(page);
        } else {
          backgroundPages.add(page);
        }
      }

      // ✅ STEP 1: Load IMMEDIATE pages (parallel)
      if (immediatePages.isNotEmpty && !_stopPreloading) {
        try {
          final batchResults = await _sqliteService.getMushafPageLinesBatch(
            immediatePages,
          );
          if (_isDisposed || _stopPreloading) return;

          for (final entry in batchResults.entries) {
            pageCache[entry.key] = entry.value;
            final fontFamily = _mushafLayout.isGlyphBased
                ? 'p${entry.key}'
                : 'IndoPak-Nastaleeq';
            warmupSpansForPage(entry.key, fontFamily);
          }
        } catch (e) {
          appLogger.log('CACHE_ERROR', 'Immediate batch load failed: $e');
        }
      }

      if (backgroundPages.isNotEmpty && !_isDisposed && !_stopPreloading) {
        Future.microtask(() async {
          const batchSize =
              2; // ✅ REDUCED: Load only 2 pages per batch to keep UI thread responsive
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
                // ✅ WARMUP SPANS: Build spans in background
                final fontFamily = _mushafLayout.isGlyphBased
                    ? 'p${entry.key}'
                    : 'IndoPak-Nastaleeq';
                warmupSpansForPage(entry.key, fontFamily);
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
        _geometryCache.remove(key); // ✅ CRITICAL: Evict geometry too

        // ✅ NEW: Evict prebuilt spans to release font references
        _prebuiltSpans.removeWhere(
          (k, _) => k.startsWith('p$key' + '_'),
        ); // ✅ Faster key matching

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

  // ✅ PHASE 2: Precompute render models to eliminate build() overhead
  void _precomputeRenderModel(int pageNumber) {
    if (_renderCache.containsKey(pageNumber)) return;

    final lines = pageCache[pageNumber];
    if (lines == null || lines.isEmpty) return;

    final List<QuranLineRenderModel> renderLines = [];
    final Map<String, List<WordData>> completeAyahs = {};
    final Map<String, AyahSegment> ayahMetadataMap = {};
    int? resolvedJuz;

    // 1. First Pass: Aggregate and Sort
    for (final line in lines) {
      if (line.lineType == 'ayah' && line.ayahSegments != null) {
        for (final segment in line.ayahSegments!) {
          final key = '${segment.surahId}:${segment.ayahNumber}';
          final words = segment.words;

          // PRE-SORT words immediately if they aren't already
          words.sort((a, b) => a.wordNumber.compareTo(b.wordNumber));

          completeAyahs.putIfAbsent(key, () => []).addAll(words);
          if (!ayahMetadataMap.containsKey(key)) {
            ayahMetadataMap[key] = segment;
          }

          if (resolvedJuz == null) {
            resolvedJuz = _sqliteService.calculateJuzAccurate(
              segment.surahId,
              segment.ayahNumber,
            );
          }
        }
      }
    }

    // 2. Second Pass: Build Ordered Line Models
    final Set<String> renderedAyahs = {};
    for (final line in lines) {
      switch (line.lineType) {
        case 'surah_name':
          renderLines.add(SurahNameLineModel(line));
          break;
        case 'basmallah':
          renderLines.add(BasmallahLineModel());
          break;
        case 'ayah':
          if (line.ayahSegments != null) {
            for (final segment in line.ayahSegments!) {
              // ✅ CRITICAL FIX: Only render the verse on the page where it BEGINS.
              // If this is a continuation segment (isStartOfAyah == false), skip it.
              if (!segment.isStartOfAyah) continue;

              final key = '${segment.surahId}:${segment.ayahNumber}';
              if (!renderedAyahs.contains(key)) {
                renderedAyahs.add(key);

                // 🚀 PULL-FORWARD STRATEGY: Combine spanning segments
                final List<WordData> words = List.from(completeAyahs[key]!);

                if (!segment.isEndOfAyah) {
                  int nextP = pageNumber + 1;
                  bool foundEnd = false;
                  while (nextP <= totalPages && !foundEnd) {
                    final nextLines = pageCache[nextP];
                    if (nextLines == null) break;

                    bool foundOnThisPage = false;
                    for (final nl in nextLines) {
                      if (nl.lineType == 'ayah' && nl.ayahSegments != null) {
                        for (final ns in nl.ayahSegments!) {
                          if (ns.surahId == segment.surahId &&
                              ns.ayahNumber == segment.ayahNumber) {
                            words.addAll(ns.words);
                            foundOnThisPage = true;
                            if (ns.isEndOfAyah) {
                              foundEnd = true;
                              break;
                            }
                          }
                        }
                      }
                      if (foundEnd) break;
                    }
                    if (!foundOnThisPage) break;
                    nextP++;
                  }
                }

                // Ensure words are sorted by number
                words.sort((a, b) => a.wordNumber.compareTo(b.wordNumber));

                final completeSegment = AyahSegment(
                  surahId: segment.surahId,
                  ayahNumber: segment.ayahNumber,
                  words: words,
                  isStartOfAyah: true,
                  isEndOfAyah: true,
                );
                renderLines.add(AyahLineModel(completeSegment));
              }
            }
          }
          break;
      }
    }

    _renderCache[pageNumber] = QuranPageRenderModel(
      pageNumber: pageNumber,
      juzNumber: resolvedJuz ?? 1,
      lines: renderLines,
    );
  }

  QuranPageRenderModel? getRenderModel(int pageNumber) {
    if (!_renderCache.containsKey(pageNumber)) {
      _precomputeRenderModel(pageNumber);
    }
    return _renderCache[pageNumber];
  }

  void navigateToPage(int newPage) {
    if (newPage < 1 || newPage > totalPages || newPage == _currentPage) {
      appLogger.log(
        'NAV',
        'Invalid navigation to page $newPage (max: $totalPages)',
      );
      return;
    }
    // ✅ PERF FIX: Removed duplicate guard block (was identical dead code)

    appLogger.log('NAV', '📄 Navigating from page $_currentPage to $newPage');
    // ✅ FIX: Update AppBar instantly BEFORE any async work
    _updateSurahNameForPageSync(newPage); // Load from cache (instant)
    updateVisiblePageQuiet(newPage); // Update AppBar notifier

    // ✅ BACKGROUND PLAY: Removed auto-stop for Listening mode.
    // Audio will continue playing as the user browses the Mushaf.

    // ✅ RECORDING SECURITY: Stop recording when user navigates to a different page.
    if (_isRecording) {
      print('🛑 User navigated during recording - automatically stopping...');
      stopRecording().catchError((e) {
        print('⚠️ Error stopping recording during navigation: $e');
      });
    }

    _currentPage = newPage;
    // ✅ CRITICAL: Reset last loaded ayats page to force reload
    _lastLoadedAyatsPage = null;

    // ✅ SURGICAL FIX: Reset highlight pointers instantly on navigation
    // This prevents "sticky" highlights from ghosting onto the new page
    _currentHighlightKey = null;
    _currentHighlightWordIdx = null;
    _wordStatusRevision++; // Trigger UI update for the lines

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
                _updateSurahNameForPage(newPage, skipNotify: true);
                _loadCurrentPageAyats(skipNotify: true);
                notifyListeners(); // ✅ PERF FIX: Single notification for all state changes
                Future.delayed(
                  const Duration(milliseconds: 500),
                  () => _preloadAdjacentPagesAggressively(),
                );
              })
              .catchError((e) {
                appLogger.log(
                  'NAV_ERROR',
                  'Failed to wait for page $newPage: $e',
                );
                // Fallback to normal load
                _loadSinglePageData(newPage).then((_) {
                  _updateSurahNameForPage(newPage, skipNotify: true);
                  _loadCurrentPageAyats(skipNotify: true);
                  notifyListeners(); // ✅ PERF FIX: Single notification
                  Future.delayed(
                    const Duration(milliseconds: 500),
                    () => _preloadAdjacentPagesAggressively(),
                  );
                });
              });
          return; // Exit early, will update when load completes
        }
      }
    }

    // ✅ Check if target page is already cached
    if (pageCache.containsKey(newPage)) {
      appLogger.log('NAV', '⚡ INSTANT: Page $newPage already in cache');

      // Update surah name immediately from cache — skipNotify since we batch below
      _updateSurahNameForPage(newPage, skipNotify: true);

      // Update current page ayats immediately (no loading) — skipNotify
      _loadCurrentPageAyats(skipNotify: true);

      // ✅ PERF FIX: O(1) ayah index lookup replaces indexWhere
      if (_currentPageAyats.isNotEmpty) {
        final firstAyatOnPage = _currentPageAyats.first;
        final newIndex =
            _ayahIndexMap['${firstAyatOnPage.surah_id}:${firstAyatOnPage.ayah}'] ??
            -1;
        if (newIndex >= 0) {
          _currentAyatIndex = newIndex;
          appLogger.log('NAV', 'Updated ayat index to $_currentAyatIndex');
        }
      }

      notifyListeners(); // ✅ PERF FIX: Single notification for all cached page changes

      // Preload more pages in background
      Future.microtask(() => _preloadAdjacentPagesAggressively());
    } else {
      // ✅ Page not cached - load it + adjacent pages immediately
      appLogger.log('NAV', '🔥 Loading page $newPage + adjacent pages...');

      // Load with parallel fetch (will cache adjacent pages too)
      _loadSinglePageData(newPage)
          .then((_) {
            _updateSurahNameForPage(newPage, skipNotify: true);

            _loadCurrentPageAyats(skipNotify: true);

            // ✅ PERF FIX: O(1) lookup replaces indexWhere
            if (_currentPageAyats.isNotEmpty) {
              final firstAyatOnPage = _currentPageAyats.first;
              final newIndex =
                  _ayahIndexMap['${firstAyatOnPage.surah_id}:${firstAyatOnPage.ayah}'] ??
                  -1;
              if (newIndex >= 0) {
                _currentAyatIndex = newIndex;
              }
            }

            notifyListeners(); // ✅ PERF FIX: Single notification

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

  /// ✅ NEW: Jump to a specific verse, handling both Mushaf and List views
  // ✅ NEW: Jump to a specific verse, handling both Mushaf and List views
  Future<void> jumpToAyah(int surahId, int ayahNumber) async {
    final page = await _sqliteService.getPageForAyah(
      surahId,
      ayahNumber,
      isQuranMode: _isQuranMode,
    );
    final globalId = GlobalAyatService.toGlobalAyat(surahId, ayahNumber);

    appLogger.log(
      'NAV',
      '🎯 Jumping to Ayah $surahId:$ayahNumber (Page $page, GlobalId $globalId)',
    );

    // Set highlight target
    _navigatedAyahId = globalId;

    // Auto-clear highlight after 8 seconds (long enough to see, but not forever)
    Future.delayed(const Duration(seconds: 8), () {
      if (_navigatedAyahId == globalId) {
        clearNavigatedAyah();
      }
    });

    _topVerseId = globalId;
    _topVersePage = page;

    if (_isQuranMode) {
      navigateToPage(page);
    } else {
      // For List View
      _listViewCurrentPage = page;
      // Also update top verse tracking properties so AppBar updates
      _activeSurahId = surahId;
      _activeAyahNumber = ayahNumber;
      _updateSurahNameForPageSync(page);
      notifyListeners();
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
  Future<void> _updateSurahNameForPage(
    int pageNumber, {
    bool skipNotify = false,
  }) async {
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
              // ✅ Update AppBar Notifier
              final juzNum = _sqliteService.calculateJuzAccurate(surahId, 1);
              appBarNotifier.value = PageDisplayData(
                pageNumber: pageNumber,
                surahName: _suratNameSimple,
                juzNumber: juzNum,
              );
              if (!skipNotify)
                notifyListeners(); // ✅ PERF FIX: Skip when caller batches
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
              // ✅ Update AppBar Notifier
              final juzNum = _sqliteService.calculateJuzAccurate(
                surahId,
                firstSegment.ayahNumber,
              );
              appBarNotifier.value = PageDisplayData(
                pageNumber: pageNumber,
                surahName: _suratNameSimple,
                juzNumber: juzNum,
              );
              if (!skipNotify)
                notifyListeners(); // ✅ PERF FIX: Skip when caller batches
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
          // ✅ Update AppBar Notifier
          final juzNum = _sqliteService.calculateJuzAccurate(
            surahId,
            firstAyat.ayah,
          );
          appBarNotifier.value = PageDisplayData(
            pageNumber: pageNumber,
            surahName: _suratNameSimple,
            juzNumber: juzNum,
          );
          if (!skipNotify)
            notifyListeners(); // ✅ PERF FIX: Skip when caller batches
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
          // ✅ Update AppBar Notifier
          final juzNum = _sqliteService.calculateJuzAccurate(
            surahId,
            firstSegment.ayahNumber,
          );
          appBarNotifier.value = PageDisplayData(
            pageNumber: pageNumber,
            surahName: _suratNameSimple,
            juzNumber: juzNum,
          );
          if (!skipNotify)
            notifyListeners(); // ✅ PERF FIX: Skip when caller batches
          return;
        }
      }
    } catch (e) {
      appLogger.log('SURAH_UPDATE_ERROR', 'Failed to update surah name: $e');
    }
  }

  void updatePageCache(int page, List<MushafPageLine> lines) {
    pageCache[page] = lines;

    // ✅ NEW: Precompute geometry immediately so highlights are ready
    _precomputeGeometryForPage(page);

    // ✅ NEW: Prune cache if it grows too large
    _cleanupDistantCache();

    if (page == _currentPage || page == _listViewCurrentPage) {
      notifyListeners();
    }
  }

  // ===== UI TOGGLES & ACTIONS =====
  // ===== UI TOGGLES & ACTIONS =====
  void setIsSwiping(bool value) {
    if (value) {
      // ✅ Start swiping: Immediate transition to static mode
      _settleTimer?.cancel();
      if (!_isSwiping) {
        _isSwiping = true;
        notifyListeners();
      }
    } else {
      // ✅ End swiping: Buffer the transition to interactive mode
      // This prevents "WBW artifacts" while the page is still settling/bouncing
      _settleTimer?.cancel();
      _settleTimer = Timer(const Duration(milliseconds: 300), () {
        if (!_isDisposed && _isSwiping) {
          _isSwiping = false;
          notifyListeners();
        }
      });
    }
  }

  double? _viewportHeight;
  Timer? _viewportDebounce;
  String? _lastGeometryViewportKey;

  /// ✅ VIEWPORT TRACKING: Set the height/width for geometry precomputation with debouncing
  void setViewportHeight(double height) {
    if (_viewportHeight == height) return;
    _viewportHeight = height;
    _triggerGeometryRecompute();
  }

  void setViewportWidth(double width) {
    if (_viewportWidth == width) return;
    _viewportWidth = width;
    _triggerGeometryRecompute();
  }

  void _triggerGeometryRecompute() {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 50), () {
      if (_isDisposed || _viewportWidth == null) return;

      final currentKey = "${_viewportWidth}x${_viewportHeight ?? 0}";
      if (_lastGeometryViewportKey == currentKey) return;

      _lastGeometryViewportKey = currentKey;

      // If viewport changed significantly, recompute all cached pages
      if (pageCache.isNotEmpty) {
        for (final page in pageCache.keys.toList()) {
          _precomputeGeometryForPage(page, force: true);
        }
        notifyListeners();
      }
    });
  }

  /// ✅ PRE-COMPUTATION ENGINE: Build spans and GEOMETRY for a page
  void warmupSpansForPage(int pageNumber, String fontFamily) {
    if (_isDisposed) return;
    final lines = pageCache[pageNumber];
    if (lines == null || lines.isEmpty) return;

    // ✅ Use a default base font size if not available
    const double baseFontSize = 24.0;

    bool anyNew = false;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final key = 'p${pageNumber}_l${line.lineNumber}';
      if (_prebuiltSpans.containsKey(key)) continue;

      _prebuiltSpans[key] = AyahCharMapper.buildStaticLineSpans(
        line,
        fontFamily, // ✅ Use passed fontFamily
        baseFontSize: baseFontSize,
      );
      anyNew = true;
    }

    // ✅ NEW: Trigger geometry precomputation if width is known
    _precomputeGeometryForPage(pageNumber);

    if (anyNew) {
      // print('🔥 Warmed up spans for page $pageNumber');
    }
  }

  void _precomputeGeometryForPage(int pageNumber, {bool force = false}) {
    if (_viewportWidth == null || _isDisposed) return;

    final currentViewportKey = "${_viewportWidth}x${_viewportHeight ?? 0}";

    // ✅ PERF FIX: Skip if geometry exists for THIS viewport
    if (!force &&
        geometryCache.containsKey(pageNumber) &&
        _lastGeometryViewportKey == currentViewportKey) {
      return;
    }

    final lines = pageCache[pageNumber];
    if (lines == null) return;

    final Map<String, List<Rect>> allWordBounds = {};

    for (final line in lines) {
      if (line.lineType != 'ayah' || line.ayahSegments == null) continue;

      // ✅ SYNC WITH UI: Replicate MushafRenderer.calculateLayoutConfig logic
      final screenWidth = _viewportWidth!;
      final screenHeight =
          _viewportHeight ??
          (screenWidth * 2.15); // Fallback if height not set yet

      double horizontalPadding = 0.0;
      double fontSizeMultiplier = 0.055;
      double targetLineHeight =
          screenHeight * 0.05; // Matches MushafRenderer.lineHeight
      bool isIndopak = !_mushafLayout.isGlyphBased;

      if (isIndopak) {
        if (pageNumber == 1 || pageNumber == 2) {
          horizontalPadding = screenWidth * 0.05;
          fontSizeMultiplier = 0.070;
          targetLineHeight = screenHeight * 0.060;
        } else {
          horizontalPadding = 0.0;
          fontSizeMultiplier = 0.0630;
          targetLineHeight = screenHeight * 0.050;
        }
      } else {
        if (pageNumber == 1 || pageNumber == 2) {
          horizontalPadding = screenWidth * 0.05;
          fontSizeMultiplier = 0.062;
          targetLineHeight = screenHeight * 0.060;
        } else {
          horizontalPadding = 0.0;
          fontSizeMultiplier = 0.060;
          targetLineHeight = screenHeight * 0.050;
        }
      }

      final double availableWidth = screenWidth - (horizontalPadding * 2) - 2.0;
      double calculatedFontSize = screenWidth * fontSizeMultiplier;

      // ✅ MATCH UI CAP: MushafRenderer.calculateLayoutConfig caps font at 85% of height
      final maxFontSizeByHeight = targetLineHeight * 0.85;
      if (calculatedFontSize > maxFontSizeByHeight) {
        calculatedFontSize = maxFontSizeByHeight;
      }

      final double lineHForGeometry = targetLineHeight;

      // ⚠️ SYNC WITH UI: Replicate the word-by-word rendering loop
      final renderUnits = <_GeometryRenderUnit>[];
      double sumUnitWidths = 0;
      final fontFamily = _mushafLayout.isGlyphBased
          ? 'p$pageNumber'
          : 'IndoPak-Nastaleeq';

      final sortedGeometrySegments = List<AyahSegment>.from(
        line.ayahSegments ?? [],
      );
      sortedGeometrySegments.sort((a, b) {
        if (a.surahId != b.surahId) return a.surahId.compareTo(b.surahId);
        return a.ayahNumber.compareTo(b.ayahNumber);
      });

      for (final segment in sortedGeometrySegments) {
        for (final word in segment.words) {
          final isLastWord = segment.isEndOfAyah && word == segment.words.last;

          // Standard scale logic from user's current mushaf_view.dart (1.0 default for effectiveFontSize)
          final effectiveFontSize = calculatedFontSize;

          double wWidth = 0;
          if (isLastWord) {
            // Matches UI: effectiveFontSize * 1.1 + 2.0 (margins)
            wWidth = effectiveFontSize * 1.1 + 2.0;
          } else {
            // ✅ PERF FIX: Uses class-level _markerStripper instead of per-word compilation
            final cleanText = word.text.replaceAll(_markerStripper, '');

            final double textHeight = (pageNumber == 1 || pageNumber == 2)
                ? 1.5
                : (isIndopak ? 1.6 : 1.8);

            final tpWord = TextPainter(
              text: TextSpan(
                text: cleanText,
                style: TextStyle(
                  fontSize: effectiveFontSize,
                  fontFamily: fontFamily,
                  height: textHeight,
                  fontWeight: FontWeight.normal,
                ),
              ),
              textDirection: TextDirection.rtl,
              maxLines: 1,
            )..layout();
            wWidth = tpWord.width;
          }

          // ✅ MERGE LOGIC: Mirror the user's "MERGE WITH PREVIOUS WORD" logic
          if (isLastWord) {
            if (renderUnits.isNotEmpty) {
              final lastUnit = renderUnits.removeLast();
              sumUnitWidths -= lastUnit.totalWidth;

              renderUnits.add(
                _GeometryRenderUnit(
                  segment: segment,
                  wordNumbers: [...lastUnit.wordNumbers, word.wordNumber],
                  wordWidth: lastUnit.wordWidth,
                  markerWidth: wWidth,
                ),
              );
              sumUnitWidths += (lastUnit.wordWidth + wWidth);
            } else {
              // One-word Ayah: Marker is the only thing in the unit
              renderUnits.add(
                _GeometryRenderUnit(
                  segment: segment,
                  wordNumbers: [word.wordNumber],
                  wordWidth: 0,
                  markerWidth: wWidth,
                ),
              );
              sumUnitWidths += wWidth;
            }
          } else {
            renderUnits.add(
              _GeometryRenderUnit(
                segment: segment,
                wordNumbers: [word.wordNumber],
                wordWidth: wWidth,
                markerWidth: 0,
              ),
            );
            sumUnitWidths += wWidth;
          }
        }
      }

      if (renderUnits.isNotEmpty) {
        // ✅ UI LOGIC PARITY: Center if isCentered OR only one unit present
        if (line.isCentered || renderUnits.length == 1) {
          double currentX = (availableWidth + sumUnitWidths) / 2;

          for (final unit in renderUnits) {
            // ✅ TIGHT FIT: Match text height (1.5-1.8) to hug font bounds
            final textHeight = (pageNumber == 1 || pageNumber == 2) ? 1.5 : 1.8;
            final hUniform = calculatedFontSize * textHeight;
            // Push down slightly to align with text baseline
            final yUniform =
                (lineHForGeometry - hUniform) / 2 + (calculatedFontSize * 0.1);

            if (unit.markerWidth > 0) {
              final ornamentScale = (pageNumber == 1 || pageNumber == 2)
                  ? 1.6
                  : 1.9;
              final visualMarkerWidth = calculatedFontSize * ornamentScale;
              final centerXMarker =
                  (currentX - unit.wordWidth) - (unit.markerWidth / 2);
              final markerLeft = centerXMarker - (visualMarkerWidth / 2);

              // ✅ FUSED: Word and Marker rects slightly overlap (0.5px) to close tiny white gaps
              final markerRect = Rect.fromLTWH(
                markerLeft - 0.5,
                yUniform,
                visualMarkerWidth + 1.0,
                hUniform,
              );
              final textRect = Rect.fromLTWH(
                currentX - unit.wordWidth - 0.5,
                yUniform,
                unit.wordWidth + 1.0,
                hUniform,
              );

              for (final wordNum in unit.wordNumbers) {
                final key = PageGeometry.getWordKey(
                  line.lineNumber,
                  unit.segment.surahId,
                  unit.segment.ayahNumber,
                  wordNum,
                );
                allWordBounds[key] = [textRect, markerRect];
              }
            } else {
              for (final wordNum in unit.wordNumbers) {
                final key = PageGeometry.getWordKey(
                  line.lineNumber,
                  unit.segment.surahId,
                  unit.segment.ayahNumber,
                  wordNum,
                );
                allWordBounds[key] = [
                  Rect.fromLTWH(
                    currentX - unit.wordWidth - 0.5,
                    yUniform,
                    unit.wordWidth + 1.0,
                    hUniform,
                  ),
                ];
              }
            }
            currentX -= unit.totalWidth;
          }
        } else {
          // Justified: Replicate Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)
          final double gap =
              (availableWidth - sumUnitWidths) / (renderUnits.length - 1);

          double currentX = availableWidth; // RTL
          for (final unit in renderUnits) {
            final textHeight = (pageNumber == 1 || pageNumber == 2) ? 1.5 : 1.8;
            final hUniform = calculatedFontSize * textHeight;
            final yUniform =
                (lineHForGeometry - hUniform) / 2 + (calculatedFontSize * 0.1);

            if (unit.markerWidth > 0) {
              final ornamentScale = (pageNumber == 1 || pageNumber == 2)
                  ? 1.6
                  : 1.9;
              final visualMarkerWidth = calculatedFontSize * ornamentScale;
              final centerXMarker =
                  (currentX - unit.wordWidth) - (unit.markerWidth / 2);
              final markerLeft = centerXMarker - (visualMarkerWidth / 2);

              final markerRect = Rect.fromLTWH(
                markerLeft - 0.5,
                yUniform,
                visualMarkerWidth + 1.0,
                hUniform,
              );
              final textRect = Rect.fromLTWH(
                currentX - unit.wordWidth - 0.5,
                yUniform,
                unit.wordWidth + 1.0,
                hUniform,
              );

              for (final wordNum in unit.wordNumbers) {
                final key = PageGeometry.getWordKey(
                  line.lineNumber,
                  unit.segment.surahId,
                  unit.segment.ayahNumber,
                  wordNum,
                );
                allWordBounds[key] = [textRect, markerRect];
              }
            } else {
              for (final wordNum in unit.wordNumbers) {
                final key = PageGeometry.getWordKey(
                  line.lineNumber,
                  unit.segment.surahId,
                  unit.segment.ayahNumber,
                  wordNum,
                );
                allWordBounds[key] = [
                  Rect.fromLTWH(
                    currentX - unit.wordWidth - 0.5,
                    yUniform,
                    unit.wordWidth + 1.0,
                    hUniform,
                  ),
                ];
              }
            }
            currentX -= (unit.totalWidth + gap);
          }
        }
      }
    }

    final isNewComputation = !_geometryCache.containsKey(pageNumber);
    _geometryCache[pageNumber] = PageGeometry(wordBounds: allWordBounds);

    if (allWordBounds.isNotEmpty && isNewComputation) {
      // print('📍 [GEOMETRY] Computed ${allWordBounds.length} word bounds for Page $pageNumber ($_viewportWidth px)');
    }
  }

  void toggleUIVisibility() {
    _isUIVisible = !_isUIVisible;
    // ✅ UX ENMANCEMENT: Tapping screen clears persistent highlight & selection
    if (_navigatedAyahId != null) clearNavigatedAyah();
    if (_selectedAyahForOptions != null) clearSelectedAyahForOptions();
    notifyListeners();
  }

  void toggleHideUnread() {
    _hideUnreadAyat = !_hideUnreadAyat;
    notifyListeners();
  }

  /// ✅ MUSHAF LONG-PRESS: Map touch coordinate to Ayah and show options
  void handleMushafLongPress(
    BuildContext context,
    int pageNumber,
    MushafPageLine line,
    Offset localPosition,
  ) {
    final geometry = _geometryCache[pageNumber];
    if (geometry == null) return;

    // ✅ LINE-ISOLATED HIT-TEST: Use "line:surah:ayah:word" key format
    final linePrefix = '${line.lineNumber}:';

    // Search for a word at this position
    for (var entry in geometry.wordBounds.entries) {
      final key = entry.key;

      // ✅ Only check words belonging to THIS specific line
      if (!key.startsWith(linePrefix)) continue;

      final boxes = entry.value;

      for (var rect in boxes) {
        // Simple hit test with small buffer
        if (rect.inflate(4.0).contains(localPosition)) {
          final parts = key.split(':');
          final targetSurahId = int.parse(
            parts[1],
          ); // ✅ Corrected for line-aware key
          final targetAyahNum = int.parse(parts[2]); // ✅ Corrected
          final targetWordIdx = int.parse(parts[3]) - 1; // 1-based to 0-based

          // ✅ NEW: Set as current highlight for visual feedback
          _currentHighlightKey = '$targetSurahId:$targetAyahNum';
          _currentHighlightWordIdx = targetWordIdx;
          _wordStatusRevision++;
          notifyListeners();

          // Find the segment for this ayah in the current line
          final segment = line.ayahSegments?.firstWhere(
            (s) => s.surahId == targetSurahId && s.ayahNumber == targetAyahNum,
            orElse: () => line.ayahSegments!.first,
          );

          if (segment != null) {
            final name =
                _metadataCache.getSurah(targetSurahId)?['name_simple'] ??
                'Surah';
            AyahOptionsSheet.show(context, segment, name).then((_) {
              // ✅ Clear highlight when modal closed (unless recording/listening)
              if (!_isRecording && !_isListeningMode) {
                _currentHighlightKey = null;
                _wordStatusRevision++;
                notifyListeners();
              }
            });
          }
          return;
        }
      }
    }
  }

  void handleListViewLongPress(BuildContext context, AyahSegment segment) {
    final surahName =
        _metadataCache.getSurah(segment.surahId)?['name_simple'] ?? 'Surah';

    // ✅ NEW: Highlight this ayah visually for feedback
    _currentHighlightKey = '${segment.surahId}:${segment.ayahNumber}';
    _currentHighlightWordIdx = 0;
    _wordStatusRevision++;
    notifyListeners();

    AyahOptionsSheet.show(context, segment, surahName).then((_) {
      // ✅ Clear highlight when modal closed
      if (!_isRecording && !_isListeningMode) {
        _currentHighlightKey = null;
        _wordStatusRevision++;
        notifyListeners();
      }
    });
  }

  Future<void> toggleQuranMode() async {
    _isTransitioningMode = true; // ✅ Start transition lock

    appLogger.log(
      'MODE_TOGGLE',
      'OPTIMISTIC: Switching from ${_isQuranMode ? "Mushaf" : "List"} to ${!_isQuranMode ? "Mushaf" : "List"}',
    );

    // 1. Capture anchors (Synchronous)
    int targetPage = _isQuranMode ? _currentPage : _listViewCurrentPage;
    int? targetAyahId;

    if (_isQuranMode) {
      // capture from Mushaf -> List
      // ✅ TUNING: Prioritize selected/highlighted Ayah as anchor if available on current page
      if (_selectedAyahForOptions != null) {
        targetAyahId = _selectedAyahForOptions!.id;
      } else if (_currentHighlightKey != null) {
        final parts = _currentHighlightKey!.split(':');
        targetAyahId = int.parse(parts[0]) * 1000 + int.parse(parts[1]);
      } else {
        final pageLines = pageCache[_currentPage];
        if (pageLines != null && pageLines.isNotEmpty) {
          final firstAyahLine = pageLines.firstWhere(
            (l) =>
                l.lineType == 'ayah' &&
                l.ayahSegments != null &&
                l.ayahSegments!.isNotEmpty,
            orElse: () => pageLines.first,
          );
          targetAyahId = firstAyahLine.ayahSegments?.first.id;
        }
      }
    } else {
      // capture from List -> Mushaf
      targetAyahId = _topVerseId;
      if (_topVersePage != null) {
        targetPage = _topVersePage!;
      }
    }

    // ✅ SYNC: Ensure top verse and page are anchored for multi-view consistency
    _topVerseId = targetAyahId;
    _topVersePage = targetPage;

    // 2. OPTIMISTIC STATE FLIP (Instant feedback)
    _isQuranMode = !_isQuranMode;
    _currentPage = targetPage;
    _listViewCurrentPage = targetPage;

    // Sync highlight index optimistically if active
    if (targetAyahId != null && (_isRecording || _isListeningMode)) {
      final index = _ayatList.indexWhere((a) => a.id == targetAyahId);
      if (index >= 0) _currentAyatIndex = index;
    }

    // 3. TRIGGER ANIMATION INSTANTLY
    notifyListeners();

    // 4. DEFER HEAVY HYDRATION (Internal lock handles safety)
    // ignore: unawaited_futures
    _hydrateAfterToggle(targetPage, targetAyahId);
  }

  /// ✅ NEW Phase 3: Deferred Hydration Pipeline
  Future<void> _hydrateAfterToggle(int targetPage, int? targetAyahId) async {
    try {
      appLogger.log(
        'HYDRATION',
        'Starting deferred hydration for page $targetPage',
      );

      // Step 1: Ensure critical page cache
      if (!pageCache.containsKey(targetPage)) {
        final lines = await _sqliteService.getMushafPageLines(targetPage);
        pageCache[targetPage] = lines;
      }

      // Step 2: Hydrate List/Mushaf models
      if (_isQuranMode) {
        // Load full Mushaf context
        await _loadCurrentPageAyats(skipNotify: true);
        _precomputeRenderModel(targetPage);
      } else {
        // Load List context
        if (!_isDataLoaded || _ayatList.isEmpty) {
          await _loadAyatDataOptimized(targetPage);
        } else {
          _updateSurahNameForPageSync(targetPage);
        }
      }

      // Step 3: Resume background preloading after hydration
      unawaited(Future.microtask(() => _preloadAdjacentPagesAggressively()));

      // Step 4: Resume Sync & Clean Lock post-frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isTransitioningMode = false;
        notifyListeners(); // ✅ Phase 3: Final sync to catch any suppressed updates
        appLogger.log(
          'HYDRATION',
          'Transition lock released for page $targetPage',
        );
      });
    } catch (e) {
      _isTransitioningMode = false;
      appLogger.log('HYDRATION_ERROR', e.toString());
    }
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

  String formatSurahHeaderName(int surahId) {
    final base = formatSurahIdForGlyph(surahId);
    return base; // ✅ FIX: Remove '-icon' placeholder for all layouts
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
        // ✅ ANCHOR FIX: Use _recordingSurahId as priority fallback
        final int processingSurah =
            message['surah'] ??
            _recordingSurahId ??
            suratId ??
            _determinedSurahId ??
            1;
        _currentAyatIndex = _ayatList.indexWhere(
          (a) => a.ayah == processingAyah && a.surah_id == processingSurah,
        );
        final processingKey = _wordKey(processingSurah, processingAyah);
        if (!_wordStatusMap.containsKey(processingKey))
          _wordStatusMap[processingKey] = {};
        _wordStatusMap[processingKey]![processingWordIndex] =
            WordStatus.processing;

        // ✅ NEW: Update highlight state for UI pulsing
        _currentHighlightKey = processingKey;
        _currentHighlightWordIdx = processingWordIndex;
        _wordStatusRevision++;

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
        // ✅ ANCHOR FIX: Use _recordingSurahId as priority fallback
        final int feedbackSurah =
            message['surah'] ??
            _recordingSurahId ??
            suratId ??
            _determinedSurahId ??
            1;

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
            _currentHighlightKey = feedbackKey;
            _currentHighlightWordIdx = nextWordIndex;

            _currentWords[nextWordIndex] = WordFeedback(
              text: _currentWords[nextWordIndex].text,
              status: WordStatus.processing,
              wordIndex: nextWordIndex,
              similarity: 0.0,
            );
          }
        }

        _wordStatusRevision++; // ✅ NEW: Trigger rebuild for UI
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

          _currentHighlightKey = nextAyahKey;
          _currentHighlightWordIdx = 0;

          print(
            '🔵 STT: Ayah complete! Set first word of next ayah to processing - $nextAyahKey[0]',
          );
        }

        _wordStatusRevision++; // ✅ NEW: Trigger rebuild
        if (!_isTransitioningMode) notifyListeners();
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
      _wordStatusRevision++; // ✅ NEW: Sync UI
      _recordingSurahId = null; // Clear old anchor before starting new
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

      // ✅ ANCHOR: Lock the surah ID for this session
      _recordingSurahId = recordingSurahId;
      _currentHighlightKey = null;
      _currentHighlightWordIdx = null;

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
      _recordingSurahId = null; // ✅ Release anchor
      _currentHighlightKey = null; // ✅ Reset instantly
      _currentHighlightWordIdx = null;
      _wordStatusRevision++; // ✅ NEW: Force one last clean repaint
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
    final current = appBarNotifier.value;
    String surahName = current.surahName;
    int juzNum = current.juzNumber;

    try {
      // ✅ Granular Optimization: If we already have a topVerseId on this page, prioritize it.
      if (_topVersePage == pageNumber && _activeSurahId != null) {
        final surahMeta = _metadataCache.getSurah(_activeSurahId!);
        if (surahMeta != null) {
          surahName = surahMeta['name_simple'] ?? surahName;
        }
        juzNum = _sqliteService.calculateJuzAccurate(
          _activeSurahId!,
          _activeAyahNumber ?? 1,
        );
      } else {
        // Priority: Metadata Cache (Instant mapping by page)
        final surahIds = _metadataCache.getSurahIdsForPage(pageNumber);
        if (surahIds.isNotEmpty) {
          final surahId = surahIds.first;
          final surahMeta = _metadataCache.getSurah(surahId);
          if (surahMeta != null) {
            surahName = surahMeta['name_simple'] ?? surahName;
          }
          juzNum = _sqliteService.calculateJuzAccurate(surahId, 1);
        }
      }
    } catch (e) {
      // Silent fail, keep previous data
    }

    // 3. Update Notifier (Hanya widget AppBar yang mendengar ini yang akan rebuild)
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
      surahName: 'Surah',
      juzNumber: 1,
    );
  }
}

// ✅ Helper for geometry precomputation (matches UI rendering units)
class _GeometryRenderUnit {
  final AyahSegment segment;
  final List<int> wordNumbers;
  final double wordWidth;
  final double markerWidth;
  double get totalWidth => wordWidth + markerWidth;

  _GeometryRenderUnit({
    required this.segment,
    required this.wordNumbers,
    required this.wordWidth,
    required this.markerWidth,
  });
}
