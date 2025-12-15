import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/screens/main/stt/data/models.dart';
import 'package:cuda_qurani/screens/main/stt/database/db_helper.dart';
import 'package:sqflite/sqflite.dart';

/// ✅ ULTRA-FAST Preview Service - Load ONLY 1 page, NO overhead
class PreviewService {
  static final PreviewService _instance = PreviewService._internal();
  factory PreviewService() => _instance;
  PreviewService._internal();

  // ✅ Cache preview forever (data never changes)
  final Map<String, List<MushafPageLine>> _previewCache = {};

  /// Load single page for preview - ZERO overhead
  Future<List<MushafPageLine>> getPreviewPage(
    MushafLayout layout,
    int pageNumber,
  ) async {
    final cacheKey = '${layout.toStringValue()}_$pageNumber';

    // ✅ Return cached immediately
    if (_previewCache.containsKey(cacheKey)) {
      print('⚡ Preview cache HIT: $cacheKey');
      return _previewCache[cacheKey]!;
    }

    print('📥 Loading preview: $layout page $pageNumber');

    // ✅ Load ONLY this page (no preloading, no background tasks)
    final linesDB = await _getLinesDB(layout);
    final wordsDB = await _getWordsDB(layout);
    
    final pageLayout = await _getPageLayout(linesDB, pageNumber);
    final pageLines = await _buildPageLines(wordsDB, pageLayout);

    // ✅ Cache forever
    _previewCache[cacheKey] = pageLines;
    print('✅ Preview loaded: ${pageLines.length} lines cached');
    
    return pageLines;
  }

  /// ✅ CRITICAL FIX: Get correct database based on layout
  Future<Database> _getLinesDB(MushafLayout layout) async {
    switch (layout) {
      case MushafLayout.qpc:
        return await DBHelper.ensureOpen(DBType.qpc_v1_15);
      case MushafLayout.indopak:
        return await DBHelper.ensureOpen(DBType.indopak_15);
    }
  }

  /// ✅ CRITICAL FIX: Get WORDS database (separate from lines)
  Future<Database> _getWordsDB(MushafLayout layout) async {
    switch (layout) {
      case MushafLayout.qpc:
        return await DBHelper.ensureOpen(DBType.qpc_v1_wbw);
      case MushafLayout.indopak:
        return await DBHelper.ensureOpen(DBType.indopak_wbw);
    }
  }

  Future<List<PageLayoutData>> _getPageLayout(
    Database db,
    int pageNumber,
  ) async {
    final result = await db.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number ASC',
    );
    return result.map((row) => PageLayoutData.fromSqlite(row)).toList();
  }

  Future<List<MushafPageLine>> _buildPageLines(
    Database wordsDB,
    List<PageLayoutData> pageLayout,
  ) async {
    final List<MushafPageLine> pageLines = [];

    for (final layout in pageLayout) {
      MushafPageLine? line;

      switch (layout.lineType) {
        case 'surah_name':
          if (layout.surahNumber != null) {
            line = MushafPageLine(
              lineNumber: layout.lineNumber,
              lineType: layout.lineType,
              isCentered: layout.isCentered,
              surahNumber: layout.surahNumber,
              surahNameArabic: '', // Not needed for preview
              surahNameSimple: '',
            );
          }
          break;

        case 'basmallah':
          line = MushafPageLine(
            lineNumber: layout.lineNumber,
            lineType: layout.lineType,
            isCentered: layout.isCentered,
            basmallahText: '﷽',
          );
          break;

        case 'ayah':
          if (layout.firstWordId != null && layout.lastWordId != null) {
            try {
              final words = await _getWords(
                wordsDB,
                layout.firstWordId!,
                layout.lastWordId!,
              );
              
              if (words.isNotEmpty) {
                final ayahSegments = _groupWordsByAyah(words);
                line = MushafPageLine(
                  lineNumber: layout.lineNumber,
                  lineType: layout.lineType,
                  isCentered: layout.isCentered,
                  firstWordId: layout.firstWordId,
                  lastWordId: layout.lastWordId,
                  ayahSegments: ayahSegments,
                );
              }
            } catch (e) {
              print('⚠️ Failed to load words $layout.firstWordId-${layout.lastWordId}: $e');
            }
          }
          break;
      }

      if (line != null) pageLines.add(line);
    }

    return pageLines;
  }

  Future<List<WordData>> _getWords(Database db, int startId, int endId) async {
    final result = await db.query(
      'words',
      where: 'id >= ? AND id <= ?',
      whereArgs: [startId, endId],
      orderBy: 'id ASC',
    );
    return result.map((row) => WordData.fromSqlite(row)).toList();
  }

  List<AyahSegment> _groupWordsByAyah(List<WordData> words) {
    final Map<String, List<WordData>> ayahGroups = {};
    for (final word in words) {
      final key = '${word.surah}:${word.ayah}';
      ayahGroups.putIfAbsent(key, () => []).add(word);
    }

    return ayahGroups.entries.map((entry) {
      final parts = entry.key.split(':');
      return AyahSegment(
        surahId: int.parse(parts[0]),
        ayahNumber: int.parse(parts[1]),
        words: entry.value,
        isStartOfAyah: entry.value.first.wordNumber == 1,
        isEndOfAyah: false, // Not needed for preview
      );
    }).toList();
  }

  void clearCache() {
    _previewCache.clear();
  }
}