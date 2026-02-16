/// AyahContent Entity
///
/// Represents a unit of Quranic content related to a specific Ayah,
/// such as Tafsir, Translation, or Transliteration.
enum AyahContentType {
  tafsir,
  translation,
  transliteration,
  similarity,
  aiExplanation,
}

/// Model class for Ayah-related content.
/// Consolidates data from various resources (Tafsir, Translation, etc.)
class AyahContent {
  final int surahId;
  final int ayahNumber;
  final AyahContentType type;
  final String content;

  /// The specific Arabic text of the verse (used for similarity list previews or transliteration)
  final String? arabicText;

  /// The transliteration of the Arabic text
  final String? transliteration;

  /// The name of the source (e.g., "Sahih International", "Tafsir al-Jalalayn")
  final String? sourceName;

  /// Language code of the content
  final String? language;

  /// Range of verses if the content is grouped (e.g., "1-7")
  final String? groupRange; // e.g. "1-7" for grouped tafsir

  /// Score for similarity-based features
  final double? similarityScore;

  /// List of verse keys (surah:ayah) related to this content (e.g. for similar phrases)
  final List<String>? relatedVerseKeys;

  const AyahContent({
    required this.surahId,
    required this.ayahNumber,
    required this.type,
    required this.content,
    this.arabicText,
    this.transliteration,
    this.sourceName,
    this.language,
    this.groupRange,
    this.similarityScore,
    this.relatedVerseKeys,
  });

  bool get isGrouped => groupRange != null;
}
