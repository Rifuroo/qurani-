// lib\screens\main\home\screens\settings\widgets\preview_service.dart
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
      return _previewCache[cacheKey]!;
    }

    // ✅ Load ONLY this page (no preloading, no background tasks)
    final db = await _getLinesDB(layout);
    final pageLayout = await _getPageLayout(db, pageNumber);
    final pageLines = await _buildPageLines(db, layout, pageLayout);

    // ✅ Cache forever
    _previewCache[cacheKey] = pageLines;
    return pageLines;
  }

  Future<Database> _getLinesDB(MushafLayout layout) async {
    switch (layout) {
      case MushafLayout.qpc:
        return await DBHelper.ensureOpen(DBType.qpc_v1_15);
      case MushafLayout.indopak:
        return await DBHelper.ensureOpen(DBType.indopak_15);
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
    Database db,
    MushafLayout layout,
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
            final words = await _getWords(db, layout.firstWordId!, layout.lastWordId!);
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