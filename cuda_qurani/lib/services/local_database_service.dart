// lib/services/local_database_service.dart

import 'dart:io';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:path_provider/path_provider.dart';
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
        dbFileName = 'qpc-v2-15-lines.db';
        assetPath = 'assets/QPCv2/qpc-v2-15-lines.db';
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
          dbFileName = 'qpc-v2-15-lines.db';
          break;
        case MushafLayout.indopak:
          dbFileName = 'qudratullah-indopak-15-lines.db';
          break;
      }

      final pagesPath = join(databasesPath, dbFileName);

      // 1. Get cached pages database connection
      final pagesDb = await _getPagesDb(layout);

      // 2. Get all ayah lines on this page
      final pageLines = await pagesDb.query(
        'pages',
        where: 'page_number = ? AND line_type = ?',
        whereArgs: [pageNumber, 'ayah'],
        orderBy: 'line_number ASC',
      );

      // ✅ DO NOT close() here, connection is cached in _getPagesDb

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

  /// ✅ NEW: Fetch simple Arabic text (clean words) for an Ayah
  static Future<String?> getSimpleArabicText(
    int surahId,
    int ayahNumber,
  ) async {
    await _ensureInitialized();
    try {
      final results = await _wordsDb!.query(
        'words',
        columns: ['text'],
        where: 'surah = ? AND ayah = ?',
        whereArgs: [surahId, ayahNumber],
        orderBy: 'word ASC',
      );

      if (results.isEmpty) return null;

      // Join words into a space-separated string
      return results.map((row) => row['text'] as String).join(' ');
    } catch (e) {
      print('[DB] Error fetching simple Arabic: $e');
      return null;
    }
  }

  /// Search verses by Arabic text OR surah name (Latin/Arabic) OR Translation text
  /// Returns a Map with 'results' (List) and 'totalCount' (int)
  static Future<Map<String, dynamic>> searchVerses(
    String query, {
    String? translationDbName,
    int offset = 0,
    int limit = 50,
  }) async {
    await _ensureInitialized();

    if (query.trim().isEmpty) {
      return {'results': [], 'totalCount': 0};
    }

    print('[DB] Searching for: "$query" (offset: $offset, limit: $limit)');

    List<Map<String, dynamic>> results = [];
    int totalCount = 0;

    // 0. CHECK FOR DIRECT VERSE REFERENCE (e.g. "36:1", "1 1", "36 : 1", or just "36")
    final trimQuery = query.trim();

    // Pattern for "surah:ayah"
    final verseRefMatch = RegExp(
      r'^(\d+)\s*[:\s-]\s*(\d+)$',
    ).firstMatch(trimQuery);

    // Pattern for just "surah" (digits only)
    final surahOnlyMatch = RegExp(r'^(\d+)$').firstMatch(trimQuery);

    if (verseRefMatch != null) {
      final surahNum = int.parse(verseRefMatch.group(1)!);
      final ayahNum = int.parse(verseRefMatch.group(2)!);

      print('[DB] Direct verse reference detected: $surahNum:$ayahNum');

      if (surahNum >= 1 && surahNum <= 114) {
        final metadata = await getSurahMetadata(surahNum);
        final ayahWords = await _wordsDb!.query(
          'words',
          where: 'surah = ? AND ayah = ?',
          whereArgs: [surahNum, ayahNum],
          orderBy: 'word ASC',
        );

        if (ayahWords.isNotEmpty) {
          totalCount = 1;
          if (offset == 0) {
            results = [
              {
                'surah_number': surahNum,
                'ayah_number': ayahNum,
                'text': ayahWords.map((w) => w['text'] as String).join(' '),
                'surah_name': metadata?['name_simple'] ?? 'Surah $surahNum',
                'surah_name_arabic': metadata?['name_arabic'] ?? '',
                'match_type': 'verse_reference',
              },
            ];
          }
          return {'results': results, 'totalCount': totalCount};
        }
      }
    } else if (surahOnlyMatch != null) {
      final surahNum = int.parse(surahOnlyMatch.group(1)!);
      print('[DB] Surah only reference detected: $surahNum');

      if (surahNum >= 1 && surahNum <= 114) {
        final metadata = await getSurahMetadata(surahNum);
        // Get total count of verses in this surah
        final countResult = await _wordsDb!.rawQuery(
          'SELECT COUNT(DISTINCT ayah) as count FROM words WHERE surah = ?',
          [surahNum],
        );
        totalCount = Sqflite.firstIntValue(countResult) ?? 0;

        // Fetch paginated words
        // We need to fetch enough words to cover the requested verses.
        // This is a bit tricky with words table where we group by ayah.
        // Better: first find which ayah numbers fit the pagination.
        final ayahBatch = await _wordsDb!.rawQuery(
          'SELECT DISTINCT ayah FROM words WHERE surah = ? ORDER BY ayah ASC LIMIT ? OFFSET ?',
          [surahNum, limit, offset],
        );

        if (ayahBatch.isNotEmpty) {
          final startAyah = ayahBatch.first['ayah'] as int;
          final endAyah = ayahBatch.last['ayah'] as int;

          final versesInSurah = await _wordsDb!.query(
            'words',
            where: 'surah = ? AND ayah >= ? AND ayah <= ?',
            whereArgs: [surahNum, startAyah, endAyah],
            orderBy: 'ayah ASC, word ASC',
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
          }

          for (var entry in ayahWordsMap.entries) {
            results.add({
              'surah_number': surahNum,
              'ayah_number': entry.key,
              'text': entry.value.join(' '),
              'surah_name': metadata?['name_simple'] ?? 'Surah $surahNum',
              'surah_name_arabic': metadata?['name_arabic'] ?? '',
              'match_type': 'surah_number',
            });
          }
        }
        return {'results': results, 'totalCount': totalCount};
      }
    }

    // 1. Search by SURAH NAME (Latin or Arabic)
    String queryLower = query.toLowerCase().trim();
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

      // For surah name search, we usually return verses from ALL matching surahs.
      // We need to calculate total verses across all matching surahs.
      final List<int> surahIds = surahMatches
          .map((s) => s['id'] as int)
          .toList();
      final placeholders = List.filled(surahIds.length, '?').join(',');

      final countResult = await _wordsDb!.rawQuery(
        'SELECT COUNT(DISTINCT surah || ":" || ayah) as count FROM words WHERE surah IN ($placeholders)',
        surahIds,
      );
      totalCount = Sqflite.firstIntValue(countResult) ?? 0;

      // Find which (surah, ayah) pairs fit the pagination
      final ayahPairs = await _wordsDb!.rawQuery(
        '''
        SELECT DISTINCT surah, ayah FROM words 
        WHERE surah IN ($placeholders) 
        ORDER BY surah ASC, ayah ASC 
        LIMIT ? OFFSET ?
        ''',
        [...surahIds, limit, offset],
      );

      if (ayahPairs.isNotEmpty) {
        // Fetch words for these pairs
        for (var pair in ayahPairs) {
          final sNum = pair['surah'] as int;
          final aNum = pair['ayah'] as int;
          final metadata = surahMatches.firstWhere((m) => m['id'] == sNum);

          final ayahWords = await _wordsDb!.query(
            'words',
            where: 'surah = ? AND ayah = ?',
            whereArgs: [sNum, aNum],
            orderBy: 'word ASC',
          );

          results.add({
            'surah_number': sNum,
            'ayah_number': aNum,
            'text': ayahWords.map((w) => w['text'] as String).join(' '),
            'surah_name': metadata['name_simple'] ?? 'Surah $sNum',
            'surah_name_arabic': metadata['name_arabic'] ?? '',
            'match_type': 'surah_name',
          });
        }
      }
      return {'results': results, 'totalCount': totalCount};
    }

    // 2. Search by VERSE TEXT (Arabic)
    if (query.length < 2) {
      return {'results': [], 'totalCount': 0};
    }

    String normalizedQuery = _normalizeArabic(query.trim());
    final List<String> searchWords = normalizedQuery.split(RegExp(r'\s+'));

    if (searchWords.length > 1) {
      // Multi-word search
      final StringBuffer intersectQuery = StringBuffer();
      for (int i = 0; i < searchWords.length; i++) {
        intersectQuery.write('SELECT surah, ayah FROM words WHERE text GLOB ?');
        if (i < searchWords.length - 1) {
          intersectQuery.write(' INTERSECT ');
        }
      }

      final intersectArgs = searchWords
          .map((w) => _generateSearchPatternGlob(w))
          .toList();
      final List<Map<String, dynamic>> allAyahPairs = await _wordsDb!.rawQuery(
        intersectQuery.toString(),
        intersectArgs,
      );

      totalCount = allAyahPairs.length;
      final paginatedPairs = allAyahPairs.skip(offset).take(limit).toList();

      for (final pair in paginatedPairs) {
        final surah = pair['surah'] as int;
        final ayah = pair['ayah'] as int;
        final metadata = await getSurahMetadata(surah);
        final ayahWords = await _wordsDb!.query(
          'words',
          where: 'surah = ? AND ayah = ?',
          whereArgs: [surah, ayah],
          orderBy: 'word ASC',
        );

        results.add({
          'surah_number': surah,
          'ayah_number': ayah,
          'text': ayahWords.map((w) => w['text'] as String).join(' '),
          'surah_name': metadata?['name_simple'] ?? 'Surah $surah',
          'surah_name_arabic': metadata?['name_arabic'] ?? '',
          'match_type': 'verse_text',
        });
      }
    } else {
      // Single word search
      // Get total count first
      final countResult = await _wordsDb!.rawQuery(
        'SELECT COUNT(DISTINCT surah || ":" || ayah) as count FROM words WHERE text GLOB ?',
        [_generateSearchPatternGlob(normalizedQuery)],
      );
      totalCount = Sqflite.firstIntValue(countResult) ?? 0;

      final ayahPairs = await _wordsDb!.rawQuery(
        'SELECT DISTINCT surah, ayah FROM words WHERE text GLOB ? ORDER BY surah ASC, ayah ASC LIMIT ? OFFSET ?',
        [_generateSearchPatternGlob(normalizedQuery), limit, offset],
      );

      for (var pair in ayahPairs) {
        final surah = pair['surah'] as int;
        final ayah = pair['ayah'] as int;
        final metadata = await getSurahMetadata(surah);
        final ayahWords = await _wordsDb!.query(
          'words',
          where: 'surah = ? AND ayah = ?',
          whereArgs: [surah, ayah],
          orderBy: 'word ASC',
        );

        results.add({
          'surah_number': surah,
          'ayah_number': ayah,
          'text': ayahWords.map((w) => w['text'] as String).join(' '),
          'surah_name': metadata?['name_simple'] ?? 'Surah $surah',
          'surah_name_arabic': metadata?['name_arabic'] ?? '',
          'match_type': 'verse_text',
        });
      }
    }

    // 3. Search by TRANSLATION TEXT
    if (results.isEmpty && translationDbName != null && query.length >= 2) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final path = join(docsDir.path, 'resources', '$translationDbName.db');

        if (await File(path).exists()) {
          final transDb = await openDatabase(path, readOnly: true);
          final tables = await transDb.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          );
          final tableNames = tables.map((t) => t['name'] as String).toList();
          String tableName = tableNames.contains('translation')
              ? 'translation'
              : (tableNames.contains('resources') ? 'resources' : '');

          if (tableName.isNotEmpty) {
            final countResult = await transDb.rawQuery(
              'SELECT COUNT(*) as count FROM $tableName WHERE text LIKE ?',
              ['%$query%'],
            );
            totalCount = Sqflite.firstIntValue(countResult) ?? 0;

            final transMatches = await transDb.query(
              tableName,
              where: 'text LIKE ?',
              whereArgs: ['%$query%'],
              limit: limit,
              offset: offset,
            );

            for (var match in transMatches) {
              final ayahKey = (match['ayah_key'] ?? match['id']) as String;
              final parts = ayahKey.split(':');
              if (parts.length == 2) {
                final surahNum = int.parse(parts[0]);
                final ayahNum = int.parse(parts[1]);
                final metadata = await getSurahMetadata(surahNum);

                results.add({
                  'surah_number': surahNum,
                  'ayah_number': ayahNum,
                  'text': '',
                  'translation_text': stripHtml(match['text'] as String),
                  'surah_name': metadata?['name_simple'] ?? 'Surah $surahNum',
                  'surah_name_arabic': metadata?['name_arabic'] ?? '',
                  'match_type': 'translation',
                });
              }
            }
          }
          await transDb.close();
        }
      } catch (e) {
        print('[DB] Error searching translation: $e');
      }
    }

    return {'results': results, 'totalCount': totalCount};
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
      // ✅ Use cached pages database connection
      final currentLayout = await MushafSettingsService().getMushafLayout();
      final pagesDb = await _getPagesDb(currentLayout);

      final pageResult = await pagesDb.query(
        'pages',
        where: 'page_number = ? AND line_type = ?',
        whereArgs: [pageNumber, 'ayah'],
        orderBy: 'line_number ASC',
        limit: 1,
      );

      if (pageResult.isEmpty) {
        return {'surah': 1, 'ayah': 1};
      }

      final firstWordId = pageResult.first['first_word_id'];
      // ✅ DO NOT close() here

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
      final qpcPath = join(databasesPath, 'qpc-v4-tajweed-15-lines.db');
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
          dbFileName = 'qpc-v2-15-lines.db';
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
            assetPath = 'assets/QPCv2/qpc-v2-15-lines.db';
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

  /// ✅ Simple Arabic Normalizer to strip diacritics
  static String _normalizeArabic(String text) {
    if (text.isEmpty) return text;

    // 1. Strip all diacritics (Harakat)
    // Range: 064B (Fathatan) to 065F, 0670 (Alif Khanjariya)
    final diacritics = RegExp('[\u064B-\u065F\u0670]');
    String result = text.replaceAll(diacritics, '');

    // 2. Normalize Alifs (Including Alif Wasla ٱ)
    // \u0671 is Alif Wasla
    result = result.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // 3. Normalize Hamzas (Yaa with Hamza, Waw with Hamza)
    result = result.replaceAll(RegExp(r'[ؤئ]'), 'ء');

    // 4. Normalize Teh Marbuta to Heh (optional, but good for searching)
    // result = result.replaceAll('ة', 'ه');

    return result;
  }

  /// ✅ NEW: Strip HTML tags and artifacts for clean UI display
  static String stripHtml(String text) {
    if (text.isEmpty) return text;

    String cleaned = text;

    // 1. Remove <sup>...</sup> and its content (footnotes)
    cleaned = cleaned.replaceAll(
      RegExp(r'<sup[^>]*>.*?</sup>', caseSensitive: false),
      '',
    );

    // 2. Remove other bracketed footnote patterns: [1], (1), [a]
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\d+[\)\]]'), '');

    // 3. Remove standalone superscript-style numbers attached to punctuation: ,1 .1 ;1
    cleaned = cleaned.replaceAll(RegExp(r'([,\.;:])\d+(?=\s|$)'), r'\1');

    // 4. Remove any remaining HTML tags but keep their content
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');

    // 5. HTML entity decoding (basic)
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'");

    // 6. Clean up extra spaces and trim
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// ✅ Generate a wildcard pattern for GLOB (SQLite) - supports character classes
  /// Example: "الحمد" -> "*[اأإآٱ]لحلمد*"
  static String _generateSearchPatternGlob(String word) {
    if (word.isEmpty) return '**';

    final StringBuffer pattern = StringBuffer('*');
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      if (RegExp(r'[اأإآٱ\u0670]').hasMatch(char)) {
        // Match ANY Alif variant including Alif Khanjariya
        pattern.write('[اأإآٱ\u0670]');
      } else if (char == 'و' || char == 'ؤ') {
        pattern.write('[وؤ]');
      } else if (char == 'ي' || char == 'ئ' || char == 'ى') {
        pattern.write('[يئى]');
      } else {
        pattern.write(char);
      }
      // Add wildcard between characters to bypass diacritics
      pattern.write('*');
    }
    return pattern.toString();
  }
}
