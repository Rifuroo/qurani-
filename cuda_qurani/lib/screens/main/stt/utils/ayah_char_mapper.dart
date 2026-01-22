// lib/screens/main/stt/utils/ayah_char_mapper.dart
// ✅ Unified character mapping for ayah-based rendering - PER PAGE SCOPE

/// Character range for a single word within an ayah
class WordCharRange {
  final int wordNumber;
  final int startChar;
  final int endChar;
  final String text;

  WordCharRange({
    required this.wordNumber,
    required this.startChar,
    required this.endChar,
    required this.text,
  });

  int get length => endChar - startChar;
}

/// Complete character mapping for an ayah
class AyahCharMap {
  final String verseKey;
  final String cleanText; // Glyph text WITHOUT ayah marker
  final List<WordCharRange> wordRanges;
  
  AyahCharMap({
    required this.verseKey,
    required this.cleanText,
    required this.wordRanges,
  });

  /// Get character range for a segment (word range)
  (int, int) getSegmentRange(int firstWordNum, int lastWordNum) {
    if (wordRanges.isEmpty) return (0, cleanText.length);
    
    final firstIdx = firstWordNum - 1;
    final lastIdx = lastWordNum - 1;
    
    if (firstIdx < 0 || lastIdx >= wordRanges.length) {
      return (0, cleanText.length);
    }
    
    final startChar = wordRanges[firstIdx].startChar;
    final endChar = wordRanges[lastIdx].endChar;
    
    // ✅ CRITICAL: Validate range doesn't overflow
    if (endChar > cleanText.length) {
      throw Exception(
        'CharMap overflow: endChar=$endChar > cleanText.length=${cleanText.length} for verse $verseKey'
      );
    }
    
    return (startChar, endChar);
  }
}

/// ✅ CRITICAL: Per-page character mapping cache
class PageCharMapCache {
  final Map<String, AyahCharMap> _ayahMaps = {}; // verseKey -> AyahCharMap
  
  void addAyahMap(String verseKey, AyahCharMap map) {
    _ayahMaps[verseKey] = map;
  }
  
  AyahCharMap? getAyahMap(String verseKey) {
    return _ayahMaps[verseKey];
  }
  
  void clear() {
    _ayahMaps.clear();
  }
}

/// Utility to build AyahCharMap from word data
class AyahCharMapper {
  /// QPC V2 ayah marker regex (Arabic number in circle + digits)
  static final RegExp ayahMarkerRegex = RegExp(r'[\u06DD][\u0660-\u0669\u0030-\u0039]*');
  
  /// ✅ Build char map for a SINGLE ayah (called per ayah, but offset is managed externally)
  static AyahCharMap buildCharMap({
    required String verseKey,
    required String ayahGlyphText,
    required List<dynamic> words, // List<WordData>
  }) {
    // Step 1: Strip ayah marker from glyph
    final cleanText = ayahGlyphText.replaceAll(ayahMarkerRegex, '').trim();
    
    // Step 2: Build word char ranges
    final wordRanges = <WordCharRange>[];
    int cursor = 0;
    
    for (final word in words) {
      final wordText = word.text as String;
      final wordNum = word.wordNumber as int;
      
      // Calculate char range for this word
      final startChar = cursor;
      final endChar = cursor + wordText.length;
      
      wordRanges.add(WordCharRange(
        wordNumber: wordNum,
        startChar: startChar,
        endChar: endChar,
        text: wordText,
      ));
      
      // Move cursor (word length + space if not last word)
      cursor = endChar;
      if (cursor < cleanText.length && cleanText[cursor] == ' ') {
        cursor++; // Skip space
      }
    }
    
    // ✅ ASSERT: Verify no marker leakage
    assert(
      !cleanText.contains('\u06DD'),
      'Ayah marker must be stripped before mapping',
    );
    
    return AyahCharMap(
      verseKey: verseKey,
      cleanText: cleanText,
      wordRanges: wordRanges,
    );
  }
}
