// No imports needed for these entities

/// Represents a similar verse result with scoring and metadata.
class SimilarVerse {
  final int surahId;
  final int ayahNumber;
  final String verseText;
  final String? transliteration;
  final String? translation;
  final String? surahName;
  final int score;
  final int coverage;
  final String? matchingPhrase;

  SimilarVerse({
    required this.surahId,
    required this.ayahNumber,
    required this.verseText,
    this.transliteration,
    this.translation,
    this.surahName,
    required this.score,
    required this.coverage,
    this.matchingPhrase,
  });

  String get verseKey => '$surahId:$ayahNumber';
}

/// Represents a similar phrase found in multiple verses.
class SimilarPhrase {
  final String phraseId;
  final String text;
  final int totalOccurrences;
  final int totalChapters;
  final List<String> verseKeys;

  SimilarPhrase({
    required this.phraseId,
    required this.text,
    required this.totalOccurrences,
    required this.totalChapters,
    required this.verseKeys,
  });
}
