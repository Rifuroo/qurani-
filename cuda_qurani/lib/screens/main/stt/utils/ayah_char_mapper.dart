import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import '../data/models.dart';

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
  /// ✅ CRITICAL: Uses cleanText from ayah-by-ayah database for accurate character mapping
  /// Word order from word-by-word database determines placement, but text comes from cleanText
  /// 
  /// The mapping ensures that:
  /// 1. Word order follows word-by-word database (for placement)
  /// 2. Text content comes from cleanText (ayah-by-ayah glyphs)
  /// 3. Character ranges accurately map word positions in cleanText
  static AyahCharMap buildCharMap({
    required String verseKey,
    required String ayahGlyphText,
    required List<dynamic> words, // List<WordData> - ordered by wordNumber from word-by-word DB
  }) {
    // Step 1: Strip ayah marker from glyph
    final cleanText = ayahGlyphText.replaceAll(ayahMarkerRegex, '').trim();
    
    // ✅ CRITICAL: Normalize whitespaces to match word-by-word database format
    final normalizedCleanText = cleanText.replaceAll('\u00A0', ' ').replaceAll('\u200F', '');
    
    // Step 2: Build word char ranges
    // ✅ Use sequential cursor approach - words are already in correct order from word-by-word DB
    final wordRanges = <WordCharRange>[];
    int cursor = 0;
    
    // ✅ Ensure words are sorted by wordNumber (should already be sorted, but safety check)
    final sortedWords = List.from(words);
    sortedWords.sort((a, b) => (a.wordNumber as int).compareTo(b.wordNumber as int));
    
    for (final word in sortedWords) {
      final wordText = word.text as String;
      final wordNum = word.wordNumber as int;
      
      // ✅ Calculate char range based on cursor position
      // This assumes cleanText matches the word order from word-by-word DB
      final startChar = cursor;
      
      // ✅ Try to find word in cleanText starting from cursor position
      // This handles cases where word.text might match a substring in cleanText
      final wordInCleanText = normalizedCleanText.substring(cursor);
      final wordIndex = wordInCleanText.indexOf(wordText);
      
      if (wordIndex == 0) {
        // ✅ Word found at expected position - use it
        final endChar = cursor + wordText.length;
        cursor = endChar;
        
        // Skip space if exists
        if (cursor < normalizedCleanText.length && normalizedCleanText[cursor] == ' ') {
          cursor++;
        }
        
        wordRanges.add(WordCharRange(
          wordNumber: wordNum,
          startChar: startChar,
          endChar: endChar,
          text: wordText,
        ));
      } else {
        // ✅ FALLBACK: Word not found at expected position - use cursor-based calculation
        // This handles edge cases where format might differ slightly
        final endChar = cursor + wordText.length;
        cursor = endChar;
        
        // Skip space if exists
        if (cursor < normalizedCleanText.length && normalizedCleanText[cursor] == ' ') {
          cursor++;
        }
        
        wordRanges.add(WordCharRange(
          wordNumber: wordNum,
          startChar: startChar,
          endChar: endChar,
          text: wordText,
        ));
      }
    }
    
    // ✅ ASSERT: Verify no marker leakage
    assert(
      !normalizedCleanText.contains('\u06DD'),
      'Ayah marker must be stripped before mapping',
    );
    
    return AyahCharMap(
      verseKey: verseKey,
      cleanText: normalizedCleanText, // ✅ Use normalized text
      wordRanges: wordRanges,
    );
  }

  /// ✅ DUAL-PHASE RENDERING: Build static InlineSpans for an entire line
  /// This bypasses word-by-word loops during swipe for maximum performance.
  static List<InlineSpan> buildStaticLineSpans(
    MushafPageLine line,
    String fontFamily, {
    required double baseFontSize,
    Color textColor = Colors.black,
  }) {
    final spans = <InlineSpan>[];

    if (line.lineType == 'surah_name') {
      spans.add(TextSpan(
        text: line.surahNameArabic ?? '',
        style: TextStyle(
          fontFamily: 'surah-name-v2', // âœ… Clean V2 name
          fontSize: baseFontSize * 1.5,
          color: textColor,
        ),
      ));
    } else if (line.lineType == 'basmallah') {
      spans.add(TextSpan(
        text: '﷽',
        style: TextStyle(
          fontFamily: fontFamily, // âœ… Use passed font (QPC or Indopak)
          fontSize: baseFontSize,
          color: textColor,
          height: 1.0,
        ),
      ));
    } else if (line.ayahSegments != null) {
      for (var segment in line.ayahSegments!) {
        final AyahCharMap? map = segment.charMap as AyahCharMap?;
        
        if (map != null && segment.words.isNotEmpty) {
          // ✅ FIX: Extract ONLY the portion of cleanText for this segment's words
          final firstWordNum = segment.words.first.wordNumber;
          final lastWordNum = segment.words.last.wordNumber;
          
          try {
            final (start, end) = map.getSegmentRange(firstWordNum, lastWordNum);
            final segmentText = map.cleanText.substring(start, end).trim();

            // âœ… Use the specific segment text with proper FONT
            spans.add(TextSpan(
              text: segmentText,
              style: TextStyle(
                fontSize: baseFontSize,
                fontFamily: fontFamily, // âœ… CRITICAL: Apply font for glyphs
                height: 1.0,
                color: textColor,
              ),
            ));
            
            // Add space between segments if not end of ayah
            if (!segment.isEndOfAyah) {
              spans.add(const TextSpan(text: ' '));
            }
          } catch (e) {
             // Fallback to whole text if range fails
             spans.add(TextSpan(
               text: map.cleanText,
               style: TextStyle(
                 fontSize: baseFontSize,
                 fontFamily: fontFamily,
                 height: 1.0,
                 color: textColor,
               ),
             ));
          }
          
          // ✅ IMPROVED: Add Ayah Marker if it's the end of an ayah
          // User requested CUSTOM markers for ALL pages (including QPC).
          if (segment.isEndOfAyah) {
             spans.add(TextSpan(
                text: '\u00A0\u06DD${LanguageHelper.toIndoPakDigits(segment.ayahNumber)}',
                style: TextStyle(
                  fontSize: baseFontSize * 0.9,
                  fontFamily: 'IndoPak-Nastaleeq',
                  height: 1.0,
                  color: textColor,
                ),
              ));
          }
        } else {
          // Fallback to word-by-word
          for (var word in segment.words) {
            spans.add(TextSpan(
              text: '${word.text} ',
              style: TextStyle(
                fontSize: baseFontSize,
                fontFamily: fontFamily,
                height: 1.0,
                color: Colors.black,
              ),
            ));
          }
        }
      }
    }

    return spans;
  }

  /// ✅ UNIFIED JUSTIFICATION: Apply the same hack used in rendering to measurement
  /// This ensures TextPainter sees the same stretching as the UI.
  static List<InlineSpan> applyJustificationHack(
    List<InlineSpan> spans, {
    required double maxWidth,
    required bool isCentered,
  }) {
    if (isCentered || spans.isEmpty) return spans;
    
    return [
      ...spans,
      const TextSpan(text: '\u200B'), // Zero-width space
      WidgetSpan(child: SizedBox(width: maxWidth * 1.1)), // Safely-bounded hack
    ];
  }
}
