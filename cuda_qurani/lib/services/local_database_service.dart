// lib/services/local_database_service.dart

import 'dart:io';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/quran_models.dart';

class LocalDatabaseService {
  static Database? _wordsDb;
  static Database? _chaptersDb;

  // ✅ OPTIMIZATION: Cache pagesDb as singleton to avoid open/close per query
  static Database? _pagesDbQpc;
  static Database? _pagesDbIndopak;

  // ✅ OPTIMIZATION: LRU Cache for frequently accessed surah data
  static final Map<int, Surah> _surahCache = {};
  static const int _maxCacheSize = 5; // Keep last 5 surahs in memory

  // ✅ OPTIMIZATION: Cache for surah metadata
  static final Map<int, Map<String, dynamic>> _metadataCache = {};

  // ✅ OPTIMIZATION: Cache for page-surah mapping
  static Map<int, List<int>>? _pageSurahMappingCache;

  /// ✅ Helper to ensure databases are open
  static Future<void> _ensureInitialized() async {
    if (_wordsDb == null || _chaptersDb == null) {
      await initializeDatabases();
    } else {
      // Check if still open
      try {
        await _wordsDb!.rawQuery('SELECT 1');
        await _chaptersDb!.rawQuery('SELECT 1');
      } catch (e) {
        print('[LocalDB] Databases were closed, reinitializing...');
        _wordsDb = null;
        _chaptersDb = null;
        await initializeDatabases();
      }
    }
  }

  /// ✅ OPTIMIZATION: Get cached pagesDb connection
  static Future<Database> _getPagesDb(MushafLayout layout) async {
    // Check if already cached
    if (layout == MushafLayout.qpc && _pagesDbQpc != null) {
      return _pagesDbQpc!;
    }
    if (layout == MushafLayout.indopak && _pagesDbIndopak != null) {
      return _pagesDbIndopak!;
    }

    final databasesPath = await getDatabasesPath();
    final String dbFileName;
    final String assetPath;

    switch (layout) {
      case MushafLayout.qpc:
        dbFileName = 'qpc-v1-15-lines.db';
        assetPath = 'assets/data/qpc-v1-15-lines.db';
        break;
      case MushafLayout.indopak:
        dbFileName = 'qudratullah-indopak-15-lines.db';
        assetPath = 'assets/indopak/qudratullah-indopak-15-lines.db';
        break;
    }

    final pagesPath = join(databasesPath, dbFileName);

    // Copy from assets if not exists
    if (!await File(pagesPath).exists()) {
      print('[LocalDB] Copying $dbFileName from assets...');
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await File(pagesPath).writeAsBytes(bytes, flush: true);
    }

    // Open and cache
    final db = await openDatabase(pagesPath, readOnly: true);

    if (layout == MushafLayout.qpc) {
      _pagesDbQpc = db;
    } else {
      _pagesDbIndopak = db;
    }

    print('[LocalDB] ✅ Cached pagesDb for $layout');
    return db;
  }

  /// ✅ NEW: Get first and last ayah in a page using word_id mapping
  static Future<Map<String, dynamic>> getAyahRangeInPage(
    int pageNumber,
    MushafLayout layout, // ✅ ADD: Pass layout as parameter
  ) async {
    await _ensureInitialized();

    try {
      final databasesPath = await getDatabasesPath();

      // ✅ Use passed layout parameter instead of controller
      final String dbFileName;
      switch (layout) {
        case MushafLayout.qpc:
          dbFileName = 'qpc-v1-15-lines.db';
          break;
        case MushafLayout.indopak:
          dbFileName = 'qudratullah-indopak-15-lines.db';
          break;
      }

      final pagesPath = join(databasesPath, dbFileName);

      // 1. Open pages database
      final pagesDb = await openDatabase(pagesPath, readOnly: true);

      // 2. Get all ayah lines on this page
      final pageLines = await pagesDb.query(
        'pages',
        where: 'page_number = ? AND line_type = ?',
        whereArgs: [pageNumber, 'ayah'],
        orderBy: 'line_number ASC',
      );

      await pagesDb.close();

      if (pageLines.isEmpty) {
        print('[LocalDB] No ayah lines found on page $pageNumber');
        return {'firstSurah': 1, 'firstAyah': 1, 'lastSurah': 1, 'lastAyah': 7};
      }

      // 3. Get first_word_id and last_word_id
      final firstLine = pageLines.first;
      final lastLine = pageLines.last;

      final firstWordId = firstLine['first_word_id'];
      final lastWordId = lastLine['last_word_id'];

      if (firstWordId == null ||
          firstWordId == '' ||
          lastWordId == null ||
          lastWordId == '') {
        print('[LocalDB] Invalid word_id on page $pageNumber');
        return {'firstSurah': 1, 'firstAyah': 1, 'lastSurah': 1, 'lastAyah': 7};
      }

      // 4. Query first word to get starting verse
      final firstWord = await _wordsDb!.query(
        'words',
        where: 'id = ?',
        whereArgs: [int.parse(firstWordId.toString())],
        limit: 1,
      );

      // 5. Query last word to get ending verse
      final lastWord = await _wordsDb!.query(
        'words',
        where: 'id = ?',
        whereArgs: [int.parse(lastWordId.toString())],
        limit: 1,
      );

      if (firstWord.isEmpty || lastWord.isEmpty) {
        print('[LocalDB] Word not found for page $pageNumber');
        return {'firstSurah': 1, 'firstAyah': 1, 'lastSurah': 1, 'lastAyah': 7};
      }

      final result = {
        'firstSurah': firstWord.first['surah'] as int,
        'firstAyah': firstWord.first['ayah'] as int,
        'lastSurah': lastWord.first['surah'] as int,
        'lastAyah': lastWord.first['ayah'] as int,
      };

      print(
        '[LocalDB] Page $pageNumber range: ${result['firstSurah']}:${result['firstAyah']} → ${result['lastSurah']}:${result['lastAyah']}',
      );

      return result;
    } catch (e, stackTrace) {
      print('[LocalDB] Error getting ayah range for page $pageNumber: $e');
      print('[LocalDB] Stack trace: $stackTrace');
      return {'firstSurah': 1, 'firstAyah': 1, 'lastSurah': 1, 'lastAyah': 7};
    }
  }

  /// Initialize all databases from assets
  static Future<void> initializeDatabases() async {
    if (_wordsDb != null && _chaptersDb != null) {
      print('[DB] Databases already initialized');
      return;
    }

    try {
      final databasesPath = await getDatabasesPath();
      print('[DB] Database path: $databasesPath');

      // Copy words database
      final wordsPath = join(databasesPath, 'uthmani.db');
      if (!await File(wordsPath).exists()) {
        print('[DB] Copying uthmani.db from assets...');
        final data = await rootBundle.load('assets/data/uthmani.db');
        final bytes = data.buffer.asUint8List();
        await File(wordsPath).writeAsBytes(bytes, flush: true);
        print('[DB] uthmani.db copied successfully');
      }
      _wordsDb = await openDatabase(wordsPath, readOnly: true);
      print('[DB] uthmani.db opened');

      // Copy chapters database
      final chaptersPath = join(
        databasesPath,
        'quran-metadata-surah-name.sqlite',
      );
      if (!await File(chaptersPath).exists()) {
        print('[DB] Copying quran-metadata-surah-name.sqlite from assets...');
        final data = await rootBundle.load(
          'assets/data/quran-metadata-surah-name.sqlite',
        );
        final bytes = data.buffer.asUint8List();
        await File(chaptersPath).writeAsBytes(bytes, flush: true);
        print('[DB] quran-metadata-surah-name.sqlite copied successfully');
      }
      _chaptersDb = await openDatabase(chaptersPath, readOnly: true);
      print('[DB] quran-metadata-surah-name.sqlite opened');

      print('[DB] All databases initialized successfully');
    } catch (e, stackTrace) {
      print('[DB] Error initializing databases: $e');
      print('[DB] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get list of all surahs (chapters)
  static Future<List<Map<String, dynamic>>> getSurahs() async {
    await _ensureInitialized();

    final result = await _chaptersDb!.query('chapters', orderBy: 'id ASC');

    return result;
  }

  /// Get surah metadata by ID - ✅ OPTIMIZED with cache
  static Future<Map<String, dynamic>?> getSurahMetadata(int surahId) async {
    // ✅ Check cache first
    if (_metadataCache.containsKey(surahId)) {
      return _metadataCache[surahId];
    }

    await _ensureInitialized();

    final result = await _chaptersDb!.query(
      'chapters',
      where: 'id = ?',
      whereArgs: [surahId],
      limit: 1,
    );

    final metadata = result.isNotEmpty ? result.first : null;

    // ✅ Store in cache
    if (metadata != null) {
      _metadataCache[surahId] = metadata;
    }

    return metadata;
  }

  /// Get complete Surah with verses - ✅ OPTIMIZED with LRU cache
  static Future<Surah> getSurah(int surahId) async {
    // ✅ Check LRU cache first
    if (_surahCache.containsKey(surahId)) {
      print('[DB] ✅ Surah $surahId loaded from CACHE');
      return _surahCache[surahId]!;
    }

    await _ensureInitialized();

    print('[DB] Loading surah $surahId from database...');

    // Get metadata
    final metadata = await getSurahMetadata(surahId);
    if (metadata == null) {
      throw Exception('Surah $surahId not found in database');
    }

    // Get all words for this surah
    final words = await _wordsDb!.query(
      'words',
      where: 'surah = ?',
      whereArgs: [surahId],
      orderBy: 'ayah ASC, word ASC',
    );

    if (words.isEmpty) {
      throw Exception('No words found for surah $surahId');
    }

    // Group words by ayah (keep ALL words including numbers for display)
    Map<int, List<String>> ayahWordsMap = {};
    for (var word in words) {
      int ayahNum = word['ayah'] as int;
      String wordText = word['text'] as String;

      if (!ayahWordsMap.containsKey(ayahNum)) {
        ayahWordsMap[ayahNum] = [];
      }
      ayahWordsMap[ayahNum]!.add(wordText);
    }

    // Convert to Verse objects
    List<Verse> verses = ayahWordsMap.entries.map((entry) {
      int ayahNum = entry.key;
      List<String> words = entry.value;
      String fullText = words.join(' ');

      return Verse(number: ayahNum, text: fullText, words: words);
    }).toList();

    // Sort verses by number
    verses.sort((a, b) => a.number.compareTo(b.number));

    final surah = Surah(
      number: surahId,
      name: metadata['name_simple'] ?? metadata['name'] ?? 'Unknown',
      nameArabic: metadata['name_arabic'] ?? 'سورة',
      verses: verses,
    );

    // ✅ Store in LRU cache with eviction
    if (_surahCache.length >= _maxCacheSize) {
      // Remove oldest entry (first key)
      _surahCache.remove(_surahCache.keys.first);
    }
    _surahCache[surahId] = surah;

    print('[DB] Surah $surahId loaded and cached: ${verses.length} verses');

    return surah;
  }

  /// Search verses by Arabic text OR surah name (Latin/Arabic)
  static Future<List<Map<String, dynamic>>> searchVerses(String query) async {
    await _ensureInitialized();

    if (query.trim().isEmpty) {
      return [];
    }

    print('[DB] Searching for: "$query"');

    List<Map<String, dynamic>> results = [];

    // 1. Search by SURAH NAME (Latin or Arabic)
    // Use case-insensitive search with LOWER()
    String queryLower = query.toLowerCase();

    // Try multiple variations for better matching
    // Remove spaces, hyphens, and normalize
    String queryNorm = queryLower.replaceAll(' ', '').replaceAll('-', '');

    final surahMatches = await _chaptersDb!.rawQuery(
      '''
      SELECT * FROM chapters 
      WHERE LOWER(name) LIKE ? 
         OR LOWER(name_simple) LIKE ? 
         OR LOWER(name_arabic) LIKE ?
         OR REPLACE(REPLACE(LOWER(name), ' ', ''), '-', '') LIKE ?
         OR REPLACE(REPLACE(LOWER(name_simple), ' ', ''), '-', '') LIKE ?
    ''',
      [
        '%$queryLower%',
        '%$queryLower%',
        '%$queryLower%',
        '%$queryNorm%',
        '%$queryNorm%',
      ],
    );

    if (surahMatches.isNotEmpty) {
      print('[DB] Found ${surahMatches.length} matching surahs by name');

      // Return all verses from matching surahs (first 10 verses only)
      for (var surahMeta in surahMatches) {
        int surahNum = surahMeta['id'] as int;

        // Get first 10 verses of this surah
        final versesInSurah = await _wordsDb!.query(
          'words',
          where: 'surah = ?',
          whereArgs: [surahNum],
          orderBy: 'ayah ASC, word ASC',
          limit: 100, // Get words for ~10 verses
        );

        // Group by ayah
        Map<int, List<String>> ayahWordsMap = {};
        for (var word in versesInSurah) {
          int ayahNum = word['ayah'] as int;
          String wordText = word['text'] as String;

          if (!ayahWordsMap.containsKey(ayahNum)) {
            ayahWordsMap[ayahNum] = [];
          }
          ayahWordsMap[ayahNum]!.add(wordText);

          // Limit to 10 verses
          if (ayahWordsMap.length > 10) break;
        }

        // Build results
        for (var entry in ayahWordsMap.entries) {
          results.add({
            'surah_number': surahNum,
            'ayah_number': entry.key,
            'text': entry.value.join(' '),
            'surah_name': surahMeta['name_simple'] ?? 'Surah $surahNum',
            'surah_name_arabic': surahMeta['name_arabic'] ?? '',
            'match_type': 'surah_name', // Indicate this matched by surah name
          });
        }
      }

      // 🔒 IMPORTANT: If surah name matched, SKIP verse text search
      // This prevents "al baqarah" from returning random verses with "al" (which is very common)
      print('[DB] Surah name matched, skipping verse text search');
      print('[DB] Found ${results.length} total results (surah name only)');
      return results;
    }

    // 2. Search by VERSE TEXT (Arabic) - ONLY if no surah name match
    // Skip if query is too short (common words like "al" would match too many)
    if (query.length < 3) {
      print('[DB] Query too short for verse text search (min 3 characters)');
      return results;
    }

    final words = await _wordsDb!.query(
      'words',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'surah ASC, ayah ASC, word ASC',
      limit: 100, // Limit results
    );

    if (words.isNotEmpty) {
      print('[DB] Found ${words.length} matching words by text');

      // Group by surah and ayah
      Map<String, List<String>> ayahWordsMap = {};
      for (var word in words) {
        int surahNum = word['surah'] as int;
        int ayahNum = word['ayah'] as int;
        String wordText = word['text'] as String;

        String key = '$surahNum:$ayahNum';
        if (!ayahWordsMap.containsKey(key)) {
          ayahWordsMap[key] = [];
        }
        ayahWordsMap[key]!.add(wordText);
      }

      // Build result list
      for (var entry in ayahWordsMap.entries) {
        final parts = entry.key.split(':');
        final surahNum = int.parse(parts[0]);
        final ayahNum = int.parse(parts[1]);
        final fullText = entry.value.join(' ');

        // Get surah metadata
        final metadata = await getSurahMetadata(surahNum);

        results.add({
          'surah_number': surahNum,
          'ayah_number': ayahNum,
          'text': fullText,
          'surah_name': metadata?['name_simple'] ?? 'Surah $surahNum',
          'surah_name_arabic': metadata?['name_arabic'] ?? '',
          'match_type': 'verse_text', // Indicate this matched by verse text
        });
      }
    }

    if (results.isEmpty) {
      print('[DB] No results found');
    } else {
      print('[DB] Found ${results.length} total results');
    }

    return results;
  }

  static Future<int> getPageNumber(int surahId, int ayahNumber) async {
    await _ensureInitialized();

    try {
      // Get first word of this ayah
      final wordResult = await _wordsDb!.query(
        'words',
        where: 'surah = ? AND ayah = ?',
        whereArgs: [surahId, ayahNumber],
        orderBy: 'word ASC',
        limit: 1,
      );

      if (wordResult.isEmpty) return 1;

      final firstWordId = wordResult.first['id'] as int;

      // ✅ OPTIMIZED: Use cached pagesDb connection
      final currentLayout = await MushafSettingsService().getMushafLayout();
      final pagesDb = await _getPagesDb(currentLayout);

      final pageResult = await pagesDb.rawQuery(
        '''
        SELECT page_number FROM pages 
        WHERE line_type = 'ayah' 
        AND first_word_id <= ? 
        AND last_word_id >= ? 
        LIMIT 1
      ''',
        [firstWordId, firstWordId],
      );

      // ✅ No close() - connection stays cached!

      if (pageResult.isNotEmpty) {
        return pageResult.first['page_number'] as int;
      }

      return 1;
    } catch (e) {
      print('[DB] Error getting page number: $e');
      return 1;
    }
  }

  /// Get first surah and ayah in a page
  static Future<Map<String, int>> getFirstAyahInPage(int pageNumber) async {
    await _ensureInitialized();

    try {
      final databasesPath = await getDatabasesPath();
      final pagesPath = join(databasesPath, 'qpc-v1-15-lines.db');

      final pagesDb = await openDatabase(pagesPath, readOnly: true);

      final pageResult = await pagesDb.query(
        'pages',
        where: 'page_number = ? AND line_type = ?',
        whereArgs: [pageNumber, 'ayah'],
        orderBy: 'line_number ASC',
        limit: 1,
      );

      if (pageResult.isEmpty) {
        await pagesDb.close();
        return {'surah': 1, 'ayah': 1};
      }

      final firstWordId = pageResult.first['first_word_id'];
      await pagesDb.close();

      if (firstWordId == null || firstWordId == '') {
        return {'surah': 1, 'ayah': 1};
      }

      final wordResult = await _wordsDb!.query(
        'words',
        where: 'id = ?',
        whereArgs: [int.parse(firstWordId.toString())],
        limit: 1,
      );

      if (wordResult.isEmpty) {
        return {'surah': 1, 'ayah': 1};
      }

      return {
        'surah': wordResult.first['surah'] as int,
        'ayah': wordResult.first['ayah'] as int,
      };
    } catch (e) {
      print('[DB] Error getting first ayah in page: $e');
      return {'surah': 1, 'ayah': 1};
    }
  }

  /// Pre-initialize all databases on app startup (call from main.dart)
  static Future<void> preInitialize() async {
    if (_wordsDb != null && _chaptersDb != null) {
      print('[LocalDB] Already initialized');
      return;
    }

    print('[LocalDB] Pre-initializing databases for app lifecycle...');
    await initializeDatabases();
    print('[LocalDB] Pre-initialization complete');
  }

  /// Close all databases and clear caches
  static Future<void> close() async {
    await _wordsDb?.close();
    await _chaptersDb?.close();
    await _pagesDbQpc?.close();
    await _pagesDbIndopak?.close();

    _wordsDb = null;
    _chaptersDb = null;
    _pagesDbQpc = null;
    _pagesDbIndopak = null;

    // ✅ Clear all caches
    _surahCache.clear();
    _metadataCache.clear();
    _pageSurahMappingCache = null;

    print('[LocalDB] All databases closed and caches cleared');
  }

  /// ✅ NEW: Close pages database connection
  static Future<void> closePageDatabase() async {
    try {
      // Close pages database yang mungkin masih open
      final databasesPath = await getDatabasesPath();
      final qpcPath = join(databasesPath, 'qpc-v1-15-lines.db');
      final indopakPath = join(
        databasesPath,
        'qudratullah-indopak-15-lines.db',
      );

      // Close via sqflite
      if (await databaseExists(qpcPath)) {
        await databaseFactory.deleteDatabase(qpcPath);
      }
      if (await databaseExists(indopakPath)) {
        await databaseFactory.deleteDatabase(indopakPath);
      }

      print('[LocalDB] ✅ Page databases closed');
    } catch (e) {
      print('[LocalDB] Error closing page databases: $e');
    }
  }

  static Future<Map<int, List<int>>> buildPageSurahMapping({
    required MushafLayout layout,
  }) async {
    await _ensureInitialized();

    try {
      final databasesPath = await getDatabasesPath();

      // ✅ DYNAMIC: Choose database based on layout
      final String dbFileName;
      switch (layout) {
        case MushafLayout.qpc:
          dbFileName = 'qpc-v1-15-lines.db';
          break;
        case MushafLayout.indopak:
          dbFileName = 'qudratullah-indopak-15-lines.db';
          break;
      }

      final pagesPath = join(databasesPath, dbFileName);

      if (!await File(pagesPath).exists()) {
        print('[LocalDB] Pages database not found, copying $dbFileName...');

        final String assetPath;
        switch (layout) {
          case MushafLayout.qpc:
            assetPath = 'assets/data/qpc-v1-15-lines.db';
            break;
          case MushafLayout.indopak:
            assetPath = 'assets/indopak/qudratullah-indopak-15-lines.db';
            break;
        }

        print('[LocalDB] Copying from: $assetPath');
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        await File(pagesPath).writeAsBytes(bytes, flush: true);
        print('[LocalDB] ✅ Copied $dbFileName successfully');
      }

      final pagesDb = await openDatabase(pagesPath, readOnly: true);

      // ✅ STEP 1: Get all page lines with word IDs
      final pageLines = await pagesDb.query(
        'pages',
        columns: ['page_number', 'first_word_id'],
        where:
            'line_type = ? AND first_word_id IS NOT NULL AND first_word_id != ?',
        whereArgs: ['ayah', ''],
        orderBy: 'page_number ASC, line_number ASC',
      );

      await pagesDb.close();

      if (pageLines.isEmpty) {
        print('[LocalDB] No page data found');
        return {};
      }

      // ✅ STEP 2: Collect all unique word IDs for batch query
      final Set<int> wordIds = {};
      final Map<int, List<int>> pageToWordIds = {};

      for (final line in pageLines) {
        final pageNum = line['page_number'] as int;
        final firstWordId = line['first_word_id'];

        if (firstWordId == null || firstWordId == '') continue;

        final wordId = int.parse(firstWordId.toString());
        wordIds.add(wordId);

        if (!pageToWordIds.containsKey(pageNum)) {
          pageToWordIds[pageNum] = [];
        }
        pageToWordIds[pageNum]!.add(wordId);
      }

      // ✅ STEP 3: Batch query all words at once
      final wordIdsList = wordIds.toList();
      final Map<int, int> wordToSurah = {};

      // Query in batches of 500 to avoid SQL limits
      for (int i = 0; i < wordIdsList.length; i += 500) {
        final batch = wordIdsList.skip(i).take(500).toList();
        final placeholders = List.filled(batch.length, '?').join(',');

        final wordResults = await _wordsDb!.rawQuery(
          'SELECT id, surah FROM words WHERE id IN ($placeholders)',
          batch,
        );

        for (final word in wordResults) {
          wordToSurah[word['id'] as int] = word['surah'] as int;
        }
      }

      // ✅ STEP 4: Build page-surah mapping
      final Map<int, Set<int>> tempMapping = {};

      pageToWordIds.forEach((pageNum, wordIds) {
        for (final wordId in wordIds) {
          final surahId = wordToSurah[wordId];
          if (surahId != null) {
            if (!tempMapping.containsKey(pageNum)) {
              tempMapping[pageNum] = {};
            }
            tempMapping[pageNum]!.add(surahId);
          }
        }
      });

      // Convert Set to List
      final Map<int, List<int>> mapping = {};
      tempMapping.forEach((page, surahs) {
        mapping[page] = surahs.toList()..sort();
      });

      print('[LocalDB] ✅ Built page-surah mapping: ${mapping.length} pages');

      // Debug: Print sample
      if (mapping.isNotEmpty) {
        print('[LocalDB] Sample mapping:');
        print('  Page 1: ${mapping[1]}');
        print('  Page 2: ${mapping[2]}');
        final lastPage = mapping.keys.reduce((a, b) => a > b ? a : b);
        print('  Page $lastPage: ${mapping[lastPage]}');
      }

      return mapping;
    } catch (e, stackTrace) {
      print('[LocalDB] Error building page-surah mapping: $e');
      print('[LocalDB] Stack trace: $stackTrace');
      return {};
    }
  }
}
