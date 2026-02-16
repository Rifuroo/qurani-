import '../entities/ayah_content.dart';

abstract class IAyahContentRepository {
  Future<AyahContent?> getAyahContent({
    required int surahId,
    required int ayahNumber,
    required AyahContentType type,
    String? sourceId,
  });

  Future<List<AyahContent>> getSimilarVerses({
    required int surahId,
    required int ayahNumber,
  });

  Future<List<String>> getAvailableSources(AyahContentType type);
}
