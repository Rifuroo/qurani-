// lib\screens\main\stt\services\quran_service.dart

import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';

import '../data/models.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../utils/constants.dart';

class QuranService {
  static final QuranService _instance = QuranService._internal();
  factory QuranService() => _instance;
  QuranService._internal();

  // ❌ REMOVE: Jangan simpan database reference di sini
  // Database? _metadataDB;
  // Database? _qpcV1WBW;
  // etc...

  // ✅ FIX: Selalu ambil dari DBHelper (singleton source of truth)
  // ✅ OPTIMIZED: Increased cache size for faster loading
  final Map<int, List<MushafPageLine>> _pageCache = {};
  final List<int> _cacheAccessOrder = []; // Track access order for LRU eviction

  // ✅ CRITICAL: Prevent duplicate requests for same page
  final Set<int> _loadingPages = {}; // Track pages currently being loaded
  final Map<int, Future<List<MushafPageLine>>> _loadingFutures =
      {}; // Share loading futures

  MushafLayout _currentLayout = MushafLayout.qpc;
  MushafLayout get currentLayout => _currentLayout;

  // ✅ TAMBAHKAN method untuk get database berdasarkan layout
  Future<Database> _getLinesDB() async {
    switch (_currentLayout) {
      case MushafLayout.qpc:
        return await DBHelper.ensureOpen(DBType.qpc_v1_15);
      case MushafLayout.indopak:
        return await DBHelper.ensureOpen(DBType.indopak_15);
    }
  }

  Future<Database> _getWBWDB() async {
    switch (_currentLayout) {
      case MushafLayout.qpc:
        return await DBHelper.ensureOpen(DBType.qpc_v1_wbw);
      case MushafLayout.indopak:
        return await DBHelper.ensureOpen(DBType.indopak_wbw);
    }
  }

  Future<void> setMushafLayout(MushafLayout layout) async {
    if (_currentLayout == layout) return;

    print(
      '[QuranService] Switching layout: ${_currentLayout.displayName} → ${layout.displayName}',
    );
    _currentLayout = layout;

    // Clear cache karena data berbeda
    _pageCache.clear();
    _cacheAccessOrder.clear();
    _pageLayoutCache.clear();
    _wordRangeCache.clear();
    _ayatCache.clear();

    // Save to preferences
    await MushafSettingsService().setMushafLayout(layout);

    print('[QuranService] Layout switched, cache cleared');
  }

  // ✅ Helper method: Always get FRESH database from DBHelper
  Future<Database> _getMetadataDB() async {
    return await DBHelper.ensureOpen(DBType.metadata);
  }

  Future<Database> _getQpcV1WBW() async {
    return await DBHelper.ensureOpen(DBType.qpc_v1_wbw);
  }

  Future<Database> _getUthmaniLinesDB() async {
    return await DBHelper.ensureOpen(DBType.qpc_v1_15);
  }

  Future<Database> _getUthmaniWords() async {
    return await DBHelper.ensureOpen(DBType.uthmani);
  }

  // ✅ FIX: Helper method untuk memilih database berdasarkan mode DAN layout
  Future<Database> _getWordsDatabase(bool isQuranMode) async {
    return isQuranMode ? await _getWBWDB() : await _getUthmaniWords();
  }

  Future<void> initialize() async {
    print('[QuranService] Using DBHelper singleton - no re-init needed');

    // ✅ BARU: Load saved layout preference
    _currentLayout = await MushafSettingsService().getMushafLayout();
    print('[QuranService] Loaded layout: ${_currentLayout.displayName}');
  }

  // ✅ OPTIMIZED: Update cache access order for LRU eviction
  void _updateCacheAccess(int pageNumber) {
    _cacheAccessOrder.remove(pageNumber);
    _cacheAccessOrder.add(pageNumber);
  }

  // ✅ CRITICAL: Public method to check cache without loading (for sync)
  List<MushafPageLine>? getCachedPage(int pageNumber) {
    if (_pageCache.containsKey(pageNumber)) {
      _updateCacheAccess(pageNumber);
      return _pageCache[pageNumber];
    }
    return null;
  }

  // ✅ NEW: Check if page is currently being loaded
  bool isPageLoading(int pageNumber) {
    return _loadingPages.contains(pageNumber);
  }

  // ✅ NEW: Get loading future if page is being loaded
  Future<List<MushafPageLine>>? getLoadingFuture(int pageNumber) {
    return _loadingFutures[pageNumber];
  }

  // ==================== OPTIMIZED BATCH LOADING ====================
  Future<List<AyatData>> getSurahAyatDataOptimized(
    int surahId, {
    bool isQuranMode = true,
  }) async {
    final db = await _getWordsDatabase(isQuranMode);

    final result = await db.query(
      'words',
      where: 'surah = ?',
      whereArgs: [surahId],
      orderBy: 'ayah ASC, word ASC',
    );

    if (result.isEmpty) return [];

    final Map<int, List<WordData>> ayahGroups = {};
    for (final row in result) {
      final word = WordData.fromSqlite(row);
      ayahGroups.putIfAbsent(word.ayah, () => []).add(word);
    }

    final chapter = await getChapterInfo(surahId);

    final List<AyatData> ayatList = [];
    for (int ayahNum = 1; ayahNum <= chapter.versesCount; ayahNum++) {
      final ayahWords = ayahGroups[ayahNum] ?? [];
      if (ayahWords.isEmpty) continue;

      final firstWordId = ayahWords.first.id;
      final uthmaniLinesDB = await _getLinesDB();
      final pageResult = await uthmaniLinesDB.rawQuery(
        'SELECT page_number FROM pages WHERE line_type = ? AND first_word_id <= ? AND last_word_id >= ? LIMIT 1',
        ['ayah', firstWordId, firstWordId],
      );
      final page = pageResult.isNotEmpty
          ? pageResult.first['page_number'] as int
          : 1;
      final juz = calculateJuzAccurate(surahId, ayahNum);

      ayatList.add(
        AyatData(
          surah_id: surahId,
          ayah: ayahNum,
          words: ayahWords,
          page: page,
          juz: juz,
          fullArabicText: ayahWords.map((w) => w.text).join(' '),
        ),
      );
    }

    return ayatList;
  }

  Future<ChapterData> getChapterInfo(int surahId) async {
    final metadataDB = await _getMetadataDB();
    final result = await metadataDB.query(
      'chapters',
      where: 'id = ?',
      whereArgs: [surahId],
      limit: 1,
    );
    if (result.isEmpty) throw Exception('Chapter not found: $surahId');
    return ChapterData.fromSqlite(result.first);
  }

  Future<List<WordData>> getSurahWords(
    int surahId, {
    bool isQuranMode = true,
  }) async {
    final db = await _getWordsDatabase(isQuranMode);
    final result = await db.query(
      'words',
      where: 'surah = ?',
      whereArgs: [surahId],
      orderBy: 'ayah ASC, word ASC',
    );
    return result.map((row) => WordData.fromSqlite(row)).toList();
  }

  Future<List<WordData>> getAyahWords(
    int surahId,
    int ayahNumber, {
    bool isQuranMode = true,
  }) async {
    final db = await _getWordsDatabase(isQuranMode);
    final result = await db.query(
      'words',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surahId, ayahNumber],
      orderBy: 'word ASC',
    );
    return result.map((row) => WordData.fromSqlite(row)).toList();
  }

  Future<List<AyatData>> getSurahAyatData(
    int surahId, {
    bool isQuranMode = true,
  }) async {
    final words = await getSurahWords(surahId, isQuranMode: isQuranMode);
    final chapter = await getChapterInfo(surahId);
    Map<int, List<WordData>> ayahGroups = {};
    for (final word in words) {
      if (!ayahGroups.containsKey(word.ayah)) {
        ayahGroups[word.ayah] = [];
      }
      ayahGroups[word.ayah]!.add(word);
    }
    List<AyatData> ayatList = [];
    for (int ayahNum = 1; ayahNum <= chapter.versesCount; ayahNum++) {
      final ayahWords = ayahGroups[ayahNum] ?? [];
      final page = await _getPageForAyah(
        surahId,
        ayahNum,
        isQuranMode: isQuranMode,
      );
      final juz = calculateJuzAccurate(surahId, ayahNum);
      ayatList.add(
        AyatData.fromWordsAndPage(
          surahId: surahId,
          ayahNumber: ayahNum,
          words: ayahWords,
          page: page,
          juz: juz,
        ),
      );
    }
    return ayatList;
  }

  /// ✅ NEW: Clear page cache when switching layout
  void clearPageCache() {
    _pageCache.clear();
    print(
      '[QuranService] ✅ Page cache cleared (${_pageCache.length} pages removed)',
    );
  }

  // ✅ OPTIMIZED: Cache for page layouts to avoid repeated queries
  final Map<int, List<PageLayoutData>> _pageLayoutCache = {};

  Future<List<PageLayoutData>> getPageLayout(int pageNumber) async {
    // ✅ OPTIMIZED: Check cache first
    if (_pageLayoutCache.containsKey(pageNumber)) {
      return _pageLayoutCache[pageNumber]!;
    }

    final uthmaniLinesDB = await _getLinesDB();
    final result = await uthmaniLinesDB.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number ASC',
    );
    final layouts = result
        .map((row) => PageLayoutData.fromSqlite(row))
        .toList();

    // ✅ OPTIMIZED: Cache layout data (persistent across page loads)
    _pageLayoutCache[pageNumber] = layouts;

    // ✅ OPTIMIZED: Limit cache size to prevent memory issues
    if (_pageLayoutCache.length > 100) {
      final oldestKey = _pageLayoutCache.keys.first;
      _pageLayoutCache.remove(oldestKey);
    }

    return layouts;
  }

  /// ✅ OPTIMIZED: Batch load multiple page layouts in parallel
  Future<Map<int, List<PageLayoutData>>> getPageLayoutsBatch(
    List<int> pageNumbers,
  ) async {
    final result = <int, List<PageLayoutData>>{};

    // Check cache first
    final pagesToLoad = <int>[];
    for (final pageNum in pageNumbers) {
      if (_pageLayoutCache.containsKey(pageNum)) {
        result[pageNum] = _pageLayoutCache[pageNum]!;
      } else {
        pagesToLoad.add(pageNum);
      }
    }

    if (pagesToLoad.isEmpty) {
      return result;
    }

    // Load missing pages in parallel
    final uthmaniLinesDB = await _getLinesDB();
    final loadFutures = pagesToLoad.map((pageNum) async {
      try {
        final queryResult = await uthmaniLinesDB.query(
          'pages',
          where: 'page_number = ?',
          whereArgs: [pageNum],
          orderBy: 'line_number ASC',
        );
        final layouts = queryResult
            .map((row) => PageLayoutData.fromSqlite(row))
            .toList();
        _pageLayoutCache[pageNum] = layouts;
        return MapEntry(pageNum, layouts);
      } catch (e) {
        print('BATCH_LAYOUT_ERROR: Failed to load page $pageNum: $e');
        return null;
      }
    });

    final loadedLayouts = await Future.wait(loadFutures, eagerError: false);
    for (final entry in loadedLayouts) {
      if (entry != null) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  // ✅ OPTIMIZED: Batch loading cache for word ranges
  final Map<String, List<WordData>> _wordRangeCache = {};

  Future<List<WordData>> _getWordsByIdRange(
    int startId,
    int endId, {
    bool isQuranMode = true,
  }) async {
    // ✅ OPTIMIZED: Check cache first using range key
    final cacheKey = '${isQuranMode ? 'wbw' : 'uth'}_$startId-$endId';
    if (_wordRangeCache.containsKey(cacheKey)) {
      return _wordRangeCache[cacheKey]!;
    }

    final db = await _getWordsDatabase(isQuranMode);
    final result = await db.query(
      'words',
      where: 'id >= ? AND id <= ?',
      whereArgs: [startId, endId],
      orderBy: 'id ASC',
    );
    final words = result.map((row) => WordData.fromSqlite(row)).toList();

    // ✅ OPTIMIZED: Cache word ranges (limit cache size)
    _wordRangeCache[cacheKey] = words;
    if (_wordRangeCache.length > 200) {
      final oldestKey = _wordRangeCache.keys.first;
      _wordRangeCache.remove(oldestKey);
    }

    return words;
  }

  // ✅ OPTIMIZED: Cache ayat data for pages to avoid repeated queries
  final Map<int, List<AyatData>> _ayatCache = {};

  Future<List<AyatData>> getCurrentPageAyats(int pageNumber) async {
    // ✅ CRITICAL: Check cache first (instant return)
    if (_ayatCache.containsKey(pageNumber)) {
      return _ayatCache[pageNumber]!;
    }

    final pageLayout = await getPageLayout(pageNumber);
    if (pageLayout.isEmpty) {
      return [];
    }

    // ✅ STEP 1: Build Set of valid word IDs from layout ranges (O(1) lookup)
    final Set<int> validWordIds = {};
    int? minId;
    int? maxId;

    for (final layout in pageLayout) {
      if (layout.lineType != 'ayah' ||
          layout.firstWordId == null ||
          layout.lastWordId == null)
        continue;

      // Add all word IDs in range to set
      for (
        int wordId = layout.firstWordId!;
        wordId <= layout.lastWordId!;
        wordId++
      ) {
        validWordIds.add(wordId);
      }

      // Track min/max for efficient range query
      if (minId == null || layout.firstWordId! < minId) {
        minId = layout.firstWordId!;
      }
      if (maxId == null || layout.lastWordId! > maxId) {
        maxId = layout.lastWordId!;
      }
    }

    if (minId == null || maxId == null || validWordIds.isEmpty) {
      _ayatCache[pageNumber] = [];
      return [];
    }

    // ✅ STEP 2: Batch load ALL words in ONE query (much faster than multiple queries)
    final db = await _getWordsDatabase(true);
    final result = await db.query(
      'words',
      where: 'id >= ? AND id <= ?',
      whereArgs: [minId, maxId],
      orderBy: 'id ASC',
    );

    // ✅ STEP 3: Group words by ayat (O(1) lookup with Set)
    final Map<String, List<WordData>> ayatWordsMap = {};
    for (final row in result) {
      final word = WordData.fromSqlite(row);

      // ✅ OPTIMIZED: O(1) lookup instead of nested loop
      if (!validWordIds.contains(word.id)) continue;

      final key = '${word.surah}:${word.ayah}';
      ayatWordsMap.putIfAbsent(key, () => []).add(word);
    }

    // ✅ STEP 4: Build AyatData list (already have all words, no more queries needed)
    final List<AyatData> ayatList = [];
    for (final entry in ayatWordsMap.entries) {
      final parts = entry.key.split(':');
      final surahId = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);

      // Sort words by word number
      entry.value.sort((a, b) => a.wordNumber.compareTo(b.wordNumber));

      ayatList.add(
        AyatData(
          surah_id: surahId,
          ayah: ayahNum,
          words: entry.value,
          page: pageNumber,
          juz: calculateJuzAccurate(surahId, ayahNum),
          fullArabicText: entry.value.map((w) => w.text).join(' '),
        ),
      );
    }

    ayatList.sort((a, b) {
      if (a.surah_id != b.surah_id) return a.surah_id.compareTo(b.surah_id);
      return a.ayah.compareTo(b.ayah);
    });

    // ✅ Cache result for instant future access
    _ayatCache[pageNumber] = ayatList;

    // ✅ OPTIMIZED: Larger cache to prevent re-loading (sync with page cache)
    if (_ayatCache.length > 500) {
      final oldestKey = _ayatCache.keys.first;
      _ayatCache.remove(oldestKey);
    }

    // ✅ Reduce log spam - only log for first 20 pages or every 50th page
    if (pageNumber <= 20 || pageNumber % 50 == 0) {
      print(
        'MUSHAF: Found ${ayatList.length} unique ayats on page $pageNumber',
      );
    }
    return ayatList;
  }

  Future<List<MushafPageLine>> getMushafPageLines(int pageNumber) async {
    // ✅ OPTIMIZED: Check cache first and update access order
    if (_pageCache.containsKey(pageNumber)) {
      _updateCacheAccess(pageNumber);
      return _pageCache[pageNumber]!;
    }

    // ✅ CRITICAL: Prevent duplicate requests - if already loading, wait for existing future
    if (_loadingPages.contains(pageNumber) &&
        _loadingFutures.containsKey(pageNumber)) {
      print(
        'MUSHAF_LINES: Page $pageNumber already loading, waiting for existing request...',
      );
      return await _loadingFutures[pageNumber]!;
    }

    // ✅ Mark as loading and create future
    _loadingPages.add(pageNumber);
    final loadingFuture = _loadMushafPageLinesInternal(pageNumber);
    _loadingFutures[pageNumber] = loadingFuture;

    try {
      final result = await loadingFuture;
      return result;
    } finally {
      // ✅ Clean up loading state
      _loadingPages.remove(pageNumber);
      _loadingFutures.remove(pageNumber);
    }
  }

  // ✅ Internal method to actually load page lines
  Future<List<MushafPageLine>> _loadMushafPageLinesInternal(
    int pageNumber,
  ) async {
    print('MUSHAF_LINES: Getting lines for page $pageNumber');
    final pageLayout = await getPageLayout(pageNumber);
    final List<MushafPageLine> pageLines = [];
    for (final layout in pageLayout) {
      MushafPageLine line;
      switch (layout.lineType) {
        case 'surah_name':
          if (layout.surahNumber != null) {
            final chapter = await getChapterInfo(layout.surahNumber!);
            line = MushafPageLine(
              lineNumber: layout.lineNumber,
              lineType: layout.lineType,
              isCentered: layout.isCentered,
              surahNumber: layout.surahNumber,
              surahNameArabic: chapter.nameArabic,
              surahNameSimple: chapter.nameSimple,
            );
          } else {
            continue;
          }
          break;
        case 'basmallah':
          line = MushafPageLine(
            lineNumber: layout.lineNumber,
            lineType: layout.lineType,
            isCentered: layout.isCentered,
            basmallahText: 'ï·½',
          );
          break;
        case 'ayah':
          if (layout.firstWordId == null || layout.lastWordId == null) continue;
          final lineWords = await _getWordsByIdRange(
            layout.firstWordId!,
            layout.lastWordId!,
            isQuranMode: true,
          );
          if (lineWords.isEmpty) continue;
          Map<String, List<WordData>> ayahSegments = {};
          for (final word in lineWords) {
            final key = '${word.surah}:${word.ayah}';
            if (!ayahSegments.containsKey(key)) {
              ayahSegments[key] = [];
            }
            ayahSegments[key]!.add(word);
          }
          line = MushafPageLine(
            lineNumber: layout.lineNumber,
            lineType: layout.lineType,
            isCentered: layout.isCentered,
            firstWordId: layout.firstWordId,
            lastWordId: layout.lastWordId,
            ayahSegments: ayahSegments.entries.map((entry) {
              final parts = entry.key.split(':');
              return AyahSegment(
                surahId: int.parse(parts[0]),
                ayahNumber: int.parse(parts[1]),
                words: entry.value,
                isStartOfAyah: entry.value.first.wordNumber == 1,
                isEndOfAyah: false,
              );
            }).toList(),
          );
          break;
        default:
          continue;
      }
      pageLines.add(line);
    }
    for (final line in pageLines) {
      if (line.ayahSegments != null) {
        for (final segment in line.ayahSegments!) {
          final totalWordsInAyah = await _getTotalWordsInAyah(
            segment.surahId,
            segment.ayahNumber,
            isQuranMode: true,
          );
          if (segment.words.isNotEmpty &&
              segment.words.last.wordNumber == totalWordsInAyah) {
            segment.isEndOfAyah = true;
          }
        }
      }
    }
    // ✅ OPTIMIZED: LRU cache implementation
    _updateCacheAccess(pageNumber);
    _pageCache[pageNumber] = pageLines;

    // ✅ OPTIMIZED: Only evict when cache is VERY large (prevent re-loading)
    // Use cacheEvictionThreshold instead of quranServiceCacheSize to keep more pages
    if (_pageCache.length > cacheEvictionThreshold) {
      // Remove least recently used page (only when cache is very full)
      if (_cacheAccessOrder.isNotEmpty) {
        final lruPage = _cacheAccessOrder.removeAt(0);
        _pageCache.remove(lruPage);
        // ✅ Reduce log spam
        if (_pageCache.length % 50 == 0) {
          print(
            'MUSHAF_CACHE: Evicted LRU page $lruPage (cache size: ${_pageCache.length})',
          );
        }
      }
    }
    // ✅ Reduce log spam - only log every 10th page or first 20 pages
    if (pageNumber <= 20 ||
        pageNumber % 10 == 0 ||
        _pageCache.length % 10 == 0) {
      print(
        'MUSHAF_LINES: Processed ${pageLines.length} lines (cache: ${_pageCache.length}/$quranServiceCacheSize)',
      );
    }

    // ✅ CRITICAL: Return cached data (already in cache now)
    return pageLines;
  }

  /// Batch load multiple pages in parallel (optimized for navigation)
  Future<Map<int, List<MushafPageLine>>> getMushafPageLinesBatch(
    List<int> pageNumbers,
  ) async {
    final result = <int, List<MushafPageLine>>{};

    // ✅ OPTIMIZED: Check cache first and update access order
    for (final pageNum in pageNumbers) {
      if (_pageCache.containsKey(pageNum)) {
        _updateCacheAccess(pageNum);
        result[pageNum] = _pageCache[pageNum]!;
      }
    }

    // Determine pages that need loading
    final pagesToLoad = pageNumbers
        .where((page) => !result.containsKey(page))
        .toList();

    if (pagesToLoad.isEmpty) {
      print('BATCH_LOAD: All ${pageNumbers.length} pages already cached');
      return result;
    }

    print(
      'BATCH_LOAD: Loading ${pagesToLoad.length} pages in parallel: $pagesToLoad',
    );

    // Load all pages in parallel
    final loadFutures = pagesToLoad.map((pageNum) async {
      try {
        final lines = await getMushafPageLines(pageNum);
        return MapEntry(pageNum, lines);
      } catch (e) {
        print('BATCH_LOAD_ERROR: Failed to load page $pageNum - $e');
        return null;
      }
    });

    final loadedPages = await Future.wait(loadFutures, eagerError: false);

    // Add successfully loaded pages to result
    for (final entry in loadedPages) {
      if (entry != null) {
        result[entry.key] = entry.value;
      }
    }

    print(
      'BATCH_LOAD: Successfully loaded ${result.length}/${pageNumbers.length} pages',
    );
    return result;
  }

  Future<int> _getTotalWordsInAyah(
    int surahId,
    int ayahNumber, {
    bool isQuranMode = true,
  }) async {
    final words = await getAyahWords(
      surahId,
      ayahNumber,
      isQuranMode: isQuranMode,
    );
    return words.length;
  }

  Future<MushafPageData> getMushafPageData(int pageNumber) async {
    print('MUSHAF_DEBUG: Getting mushaf page data for page $pageNumber');
    final pageLayout = await getPageLayout(pageNumber);
    final List<MushafLine> lines = [];
    for (final layout in pageLayout) {
      MushafLine line;
      switch (layout.lineType) {
        case 'surah_name':
          if (layout.surahNumber != null) {
            final chapter = await getChapterInfo(layout.surahNumber!);
            line = MushafLine(
              lineNumber: layout.lineNumber,
              lineType: MushafLineType.surahName,
              isCentered: layout.isCentered,
              content: chapter.nameArabic,
              surahNumber: layout.surahNumber,
            );
          } else {
            continue;
          }
          break;
        case 'basmallah':
          line = MushafLine(
            lineNumber: layout.lineNumber,
            lineType: MushafLineType.basmallah,
            isCentered: layout.isCentered,
            content: 'ï·½',
          );
          break;
        case 'ayah':
          if (layout.firstWordId != null && layout.lastWordId != null) {
            final words = await _getWordsByIdRange(
              layout.firstWordId!,
              layout.lastWordId!,
              isQuranMode: true,
            );
            line = MushafLine(
              lineNumber: layout.lineNumber,
              lineType: MushafLineType.ayah,
              isCentered: layout.isCentered,
              content: words.map((w) => w.text).join(' '),
              words: words,
              firstWordId: layout.firstWordId,
              lastWordId: layout.lastWordId,
            );
          } else {
            continue;
          }
          break;
        default:
          continue;
      }
      lines.add(line);
    }
    return MushafPageData(pageNumber: pageNumber, lines: lines);
  }

  Future<int> _getPageForAyah(
    int surahId,
    int ayahNumber, {
    bool isQuranMode = true,
  }) async {
    final ayahWords = await getAyahWords(
      surahId,
      ayahNumber,
      isQuranMode: isQuranMode,
    );
    if (ayahWords.isEmpty) return 1;
    final firstWordId = ayahWords.first.id;
    final uthmaniLinesDB = await _getLinesDB();
    final result = await uthmaniLinesDB.rawQuery(
      '''SELECT page_number FROM pages WHERE line_type = 'ayah' AND first_word_id <= ? AND last_word_id >= ? LIMIT 1''',
      [firstWordId, firstWordId],
    );
    if (result.isNotEmpty) {
      return result.first['page_number'] as int;
    }
    return 1;
  }

  int calculateJuzAccurate(int surahId, int ayahNumber) {
    const List<Map<String, dynamic>> juzBoundaries = [
      {'juz': 1, 'surah': 1, 'ayah': 1},
      {'juz': 2, 'surah': 2, 'ayah': 142},
      {'juz': 3, 'surah': 2, 'ayah': 253},
      {'juz': 4, 'surah': 3, 'ayah': 93},
      {'juz': 5, 'surah': 4, 'ayah': 24},
      {'juz': 6, 'surah': 4, 'ayah': 148},
      {'juz': 7, 'surah': 5, 'ayah': 82},
      {'juz': 8, 'surah': 6, 'ayah': 111},
      {'juz': 9, 'surah': 7, 'ayah': 88},
      {'juz': 10, 'surah': 8, 'ayah': 41},
      {'juz': 11, 'surah': 9, 'ayah': 93},
      {'juz': 12, 'surah': 11, 'ayah': 6},
      {'juz': 13, 'surah': 12, 'ayah': 53},
      {'juz': 14, 'surah': 15, 'ayah': 1},
      {'juz': 15, 'surah': 17, 'ayah': 1},
      {'juz': 16, 'surah': 18, 'ayah': 75},
      {'juz': 17, 'surah': 21, 'ayah': 1},
      {'juz': 18, 'surah': 23, 'ayah': 1},
      {'juz': 19, 'surah': 25, 'ayah': 21},
      {'juz': 20, 'surah': 27, 'ayah': 56},
      {'juz': 21, 'surah': 29, 'ayah': 46},
      {'juz': 22, 'surah': 33, 'ayah': 31},
      {'juz': 23, 'surah': 36, 'ayah': 28},
      {'juz': 24, 'surah': 39, 'ayah': 32},
      {'juz': 25, 'surah': 41, 'ayah': 47},
      {'juz': 26, 'surah': 46, 'ayah': 1},
      {'juz': 27, 'surah': 51, 'ayah': 31},
      {'juz': 28, 'surah': 58, 'ayah': 1},
      {'juz': 29, 'surah': 67, 'ayah': 1},
      {'juz': 30, 'surah': 78, 'ayah': 1},
    ];
    for (int i = juzBoundaries.length - 1; i >= 0; i--) {
      final boundary = juzBoundaries[i];
      final juzSurah = boundary['surah'] as int;
      final juzAyah = boundary['ayah'] as int;
      if (surahId > juzSurah ||
          (surahId == juzSurah && ayahNumber >= juzAyah)) {
        return boundary['juz'] as int;
      }
    }
    return 1;
  }

  void dispose() {
    // ✅ ONLY clear cache, databases remain open (managed by DBHelper)
    _pageCache.clear();
    _cacheAccessOrder.clear();
    _pageLayoutCache.clear();
    _wordRangeCache.clear();
    _loadingPages.clear();
    _loadingFutures.clear();
    print('[QuranService] All caches cleared, databases remain open');
  }
}
