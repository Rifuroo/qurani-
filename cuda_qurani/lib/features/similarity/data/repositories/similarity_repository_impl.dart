import 'dart:collection';
import '../../domain/entities/similarity_result.dart';
import '../../domain/repositories/similarity_repository.dart';
import 'package:cuda_qurani/screens/main/stt/services/mutashabihat_service.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';

class SimilarityRepositoryImpl implements ISimilarityRepository {
  final MutashabihatService _mutashabihatService;
  final QuranResourceService _resourceService;
  final QuranService _quranService;

  // In-memory LRU cache for transliterations
  // Key: "surah:ayah", Value: Transliteration Text
  static const int _maxCacheSize = 500;
  final LinkedHashMap<String, String?> _transliterationCache =
      LinkedHashMap<String, String?>();

  SimilarityRepositoryImpl({
    MutashabihatService? mutashabihatService,
    QuranResourceService? resourceService,
    QuranService? quranService,
  }) : _mutashabihatService = mutashabihatService ?? MutashabihatService(),
       _resourceService = resourceService ?? QuranResourceService(),
       _quranService = quranService ?? QuranService();

  @override
  Future<List<SimilarVerse>> getSimilarVerses(
    int surahId,
    int ayahNumber,
  ) async {
    final results = await _mutashabihatService.getSimilarVerses(
      surahId,
      ayahNumber,
    );

    // Convert to domain entities with additional metadata
    final List<SimilarVerse> mappedResults = [];
    for (final v in results) {
      final transliteration =
          v.transliteration ??
          await _resourceService.getTransliterationText(v.surah, v.ayah);
      final translation = await _resourceService.getTranslationText(
        v.surah,
        v.ayah,
      );
      final chapter = await _quranService.getChapterInfo(v.surah);

      mappedResults.add(
        SimilarVerse(
          surahId: v.surah,
          ayahNumber: v.ayah,
          verseText: v.verseText,
          transliteration: transliteration,
          translation: translation,
          surahName: chapter.nameSimple,
          score: v.score ?? 0,
          coverage: v.coverage ?? 0,
          matchingPhrase: v.matchingPhrase,
        ),
      );
    }
    return mappedResults;
  }

  @override
  Future<List<SimilarVerse>> getVersesByKeys(
    List<String> verseKeys,
    String matchingPhrase,
  ) async {
    final List<SimilarVerse> mappedResults = [];

    for (final key in verseKeys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;

      final s = int.parse(parts[0]);
      final a = int.parse(parts[1]);

      final verseText = await _mutashabihatService.getVerseText(s, a);
      final transliteration = await _resourceService.getTransliterationText(
        s,
        a,
      );
      final translation = await _resourceService.getTranslationText(s, a);
      final chapter = await _quranService.getChapterInfo(s);

      mappedResults.add(
        SimilarVerse(
          surahId: s,
          ayahNumber: a,
          verseText: verseText,
          transliteration: transliteration,
          translation: translation,
          surahName: chapter.nameSimple,
          score: 100, // Direct match
          coverage: 100,
          matchingPhrase: matchingPhrase,
        ),
      );
    }
    return mappedResults;
  }

  @override
  Future<List<SimilarPhrase>> getSimilarPhrases(
    int surahId,
    int ayahNumber,
  ) async {
    final results = await _mutashabihatService.getPhrasesForVerse(
      surahId,
      ayahNumber,
    );

    return results
        .map(
          (p) => SimilarPhrase(
            phraseId: p.phraseId,
            text: p.text,
            totalOccurrences: p.totalOccurrences,
            totalChapters: p.totalChapters,
            verseKeys: p.verseKeys,
          ),
        )
        .toList();
  }

  @override
  Future<String> getVerseText(int surahId, int ayahNumber) async {
    return await _mutashabihatService.getVerseText(surahId, ayahNumber);
  }

  @override
  Future<String?> getTranslationText(int surahId, int ayahNumber) async {
    return await _resourceService.getTranslationText(surahId, ayahNumber);
  }

  @override
  Future<bool> isUnique(int surahId, int ayahNumber) async {
    return await _mutashabihatService.isUnique(surahId, ayahNumber);
  }

  /// Optimized batch fetch for transliterations of multiple verses.
  /// Uses an in-memory LRU cache to minimize database hits.
  @override
  Future<Map<String, String?>> getBatchTransliterations(
    List<String> verseKeys,
  ) async {
    final Map<String, String?> results = {};
    final List<String> missingKeys = [];

    // 1. Check cache first
    for (final key in verseKeys) {
      if (_transliterationCache.containsKey(key)) {
        // Refresh position in LinkedHashMap (LRU)
        final val = _transliterationCache.remove(key);
        _transliterationCache[key] = val;
        results[key] = val;
      } else {
        missingKeys.add(key);
      }
    }

    // 2. Fetch missing from database
    if (missingKeys.isNotEmpty) {
      for (final key in missingKeys) {
        final parts = key.split(':');
        if (parts.length == 2) {
          final s = int.parse(parts[0]);
          final a = int.parse(parts[1]);
          final text = await _resourceService.getTransliterationText(s, a);

          // Update cache with LRU eviction
          if (_transliterationCache.length >= _maxCacheSize) {
            _transliterationCache.remove(_transliterationCache.keys.first);
          }
          _transliterationCache[key] = text;
          results[key] = text;
        }
      }
    }

    return results;
  }

  @override
  Future<String> getSurahName(int surahId) async {
    final chapter = await _quranService.getChapterInfo(surahId);
    return chapter.nameSimple;
  }

  @override
  void clearCache() {
    _transliterationCache.clear();
  }
}
