// lib\screens\main\stt\services\quran_service.dart

import '../data/models.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';

class QuranService {
  static final QuranService _instance = QuranService._internal();
  factory QuranService() => _instance;
  QuranService._internal();

  // ❌ REMOVE: Jangan simpan database reference di sini
  // Database? _metadataDB;
  // Database? _qpcV1WBW;
  // etc...

  // ✅ FIX: Selalu ambil dari DBHelper (singleton source of truth)
  final Map<int, List<MushafPageLine>> _pageCache = {};

  // ✅ Helper method: Always get FRESH database from DBHelper
  Future<Database> _getMetadataDB() async {
    return await DBHelper.ensureOpen(DBType.metadata);
  }

  Future<Database> _getQpcV1WBW() async {
    return await DBHelper.ensureOpen(DBType.qpc_v1_wbw);
  }

  Future<Database> _getQpcV1ABA() async {
    return await DBHelper.ensureOpen(DBType.qpc_v1_aba);
  }

  Future<Database> _getUthmaniLinesDB() async {
    return await DBHelper.ensureOpen(DBType.qpc_v1_15);
  }

  Future<Database> _getUthmaniWords() async {
    return await DBHelper.ensureOpen(DBType.uthmani);
  }

  // Helper method untuk memilih database berdasarkan mode
  Future<Database> _getWordsDatabase(bool isQuranMode) async {
    return isQuranMode ? await _getQpcV1WBW() : await _getUthmaniWords();
  }

  Future<void> initialize() async {
    // ✅ FIX: Tidak perlu initialize, DBHelper sudah handle semuanya
    print('[QuranService] Using DBHelper singleton - no re-init needed');
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
      final uthmaniLinesDB = await _getUthmaniLinesDB();
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

  Future<List<PageLayoutData>> getPageLayout(int pageNumber) async {
    final uthmaniLinesDB = await _getUthmaniLinesDB();
    final result = await uthmaniLinesDB.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number ASC',
    );
    return result.map((row) => PageLayoutData.fromSqlite(row)).toList();
  }

  Future<List<WordData>> _getWordsByIdRange(
    int startId,
    int endId, {
    bool isQuranMode = true,
  }) async {
    final db = await _getWordsDatabase(isQuranMode);
    final result = await db.query(
      'words',
      where: 'id >= ? AND id <= ?',
      whereArgs: [startId, endId],
      orderBy: 'id ASC',
    );
    return result.map((row) => WordData.fromSqlite(row)).toList();
  }

  Future<List<AyatData>> getCurrentPageAyats(int pageNumber) async {
    print('MUSHAF: Loading page $pageNumber');
    final pageLayout = await getPageLayout(pageNumber);
    if (pageLayout.isEmpty) {
      print('MUSHAF: No layout data for page $pageNumber');
      return [];
    }
    Map<String, AyatData> uniqueAyats = {};
    for (final layout in pageLayout) {
      if (layout.lineType != 'ayah' ||
          layout.firstWordId == null ||
          layout.lastWordId == null)
        continue;
      final lineWords = await _getWordsByIdRange(
        layout.firstWordId!,
        layout.lastWordId!,
        isQuranMode: true,
      );
      if (lineWords.isEmpty) continue;
      for (final word in lineWords) {
        final key = '${word.surah}:${word.ayah}';
        if (!uniqueAyats.containsKey(key)) {
          uniqueAyats[key] = AyatData(
            surah_id: word.surah,
            ayah: word.ayah,
            words: [],
            page: pageNumber,
            juz: calculateJuzAccurate(word.surah, word.ayah),
            fullArabicText: '',
          );
        }
      }
    }
    for (final key in uniqueAyats.keys) {
      final parts = key.split(':');
      final surahId = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);
      final completeWords = await getAyahWords(
        surahId,
        ayahNum,
        isQuranMode: true,
      );
      uniqueAyats[key] = AyatData(
        surah_id: surahId,
        ayah: ayahNum,
        words: completeWords,
        page: pageNumber,
        juz: calculateJuzAccurate(surahId, ayahNum),
        fullArabicText: completeWords.map((w) => w.text).join(' '),
      );
    }
    final ayatList = uniqueAyats.values.toList();
    ayatList.sort((a, b) {
      if (a.surah_id != b.surah_id) return a.surah_id.compareTo(b.surah_id);
      return a.ayah.compareTo(b.ayah);
    });
    print('MUSHAF: Found ${ayatList.length} unique ayats on page $pageNumber');
    return ayatList;
  }

  Future<List<MushafPageLine>> getMushafPageLines(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber]!;
    }
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
    _pageCache[pageNumber] = pageLines;
    if (_pageCache.length > 10) {
      final oldestKey = _pageCache.keys.first;
      _pageCache.remove(oldestKey);
    }
    print('MUSHAF_LINES: Processed ${pageLines.length} lines');
    return pageLines;
  }

  /// Batch load multiple pages in parallel (optimized for navigation)
  Future<Map<int, List<MushafPageLine>>> getMushafPageLinesBatch(
    List<int> pageNumbers,
  ) async {
    final result = <int, List<MushafPageLine>>{};

    // Check cache first
    for (final pageNum in pageNumbers) {
      if (_pageCache.containsKey(pageNum)) {
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
    final uthmaniLinesDB = await _getUthmaniLinesDB();
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
    print('[QuranService] Cache cleared, databases remain open');
  }
}



