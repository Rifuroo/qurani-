import '../entities/similarity_result.dart';

/// Interface for Similarity related data operations.
abstract class ISimilarityRepository {
  /// Fetches verses similar to the given Ayah.
  Future<List<SimilarVerse>> getSimilarVerses(int surahId, int ayahNumber);

  /// Fetches phrases present in the given Ayah that have similarities elsewhere.
  Future<List<SimilarPhrase>> getSimilarPhrases(int surahId, int ayahNumber);

  /// Fetches full verse details for a list of verse keys ("surah:ayah").
  Future<List<SimilarVerse>> getVersesByKeys(
    List<String> verseKeys,
    String matchingPhrase,
  );

  /// Fetches the Arabic text for a specific Ayah (utility for similarity context).
  Future<String> getVerseText(int surahId, int ayahNumber);

  /// Fetches the translation for a specific Ayah.
  Future<String?> getTranslationText(int surahId, int ayahNumber);

  /// Checks if a verse is considered unique (no recorded similarities).
  Future<bool> isUnique(int surahId, int ayahNumber);

  /// Optimised batch fetch for transliterations with caching.
  Future<Map<String, String?>> getBatchTransliterations(List<String> verseKeys);

  /// Fetches the name of a Surah by its ID.
  Future<String> getSurahName(int surahId);

  /// Clears in-memory caches to reclaim memory.
  void clearCache();
}
