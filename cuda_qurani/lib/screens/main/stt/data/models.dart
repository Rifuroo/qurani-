// lib\screens\main\stt\data\models.dart

import 'package:flutter/material.dart';

enum ReadingStatus { notRead, correct, error, skipped }

enum MushafLineType { surahName, basmallah, ayah }

enum TartibStatus {
  unread,
  correct, 
  skipped, 
}

class AyatData {
  final int surah_id;
  final int ayah;
  final List<WordData> words;
  final int page;
  final int juz;
  final String fullArabicText;

  AyatData({
    required this.surah_id,
    required this.ayah,
    required this.words,
    required this.page,
    required this.juz,
    required this.fullArabicText,
  });

  int get id => surah_id * 1000 + ayah;

  String get arabic => words.map((w) => w.text).join(' ');
  String get noTashkeel => words.map((w) => w.text).join(' ');
  String get transliteration => '';
  List<String> get wordsArrayNt => words.map((w) => w.text).toList();
  double get quarterHizb => 0.0;

  factory AyatData.fromWordsAndPage({
    required int surahId,
    required int ayahNumber,
    required List<WordData> words,
    required int page,
    required int juz,
  }) {
    return AyatData(
      surah_id: surahId,
      ayah: ayahNumber,
      words: words,
      page: page,
      juz: juz,
      fullArabicText: words.map((w) => w.text).join(' '),
    );
  }
}

class WordData {
  final int id;
  final String location;
  final int surah;
  final int ayah;
  final int wordNumber;
  final String text;

  WordData({
    required this.id,
    required this.location,
    required this.surah,
    required this.ayah,
    required this.wordNumber,
    required this.text,
  });

  factory WordData.fromSqlite(Map<String, dynamic> row) {
    return WordData(
      id: row['id'] as int,
      location: row['location'] as String,
      surah: row['surah'] as int,
      ayah: row['ayah'] as int,
      wordNumber: row['word'] as int,
      text: row['text'] as String,
    );
  }
}

class ChapterData {
  final int id;
  final String name;
  final String nameSimple;
  final String nameArabic;
  final int revelationOrder;
  final String revelationPlace;
  final int versesCount;
  final int bismillahPre;

  ChapterData({
    required this.id,
    required this.name,
    required this.nameSimple,
    required this.nameArabic,
    required this.revelationOrder,
    required this.revelationPlace,
    required this.versesCount,
    required this.bismillahPre,
  });

  String get namalatin => nameSimple;
  String get arti => '';
  String get tempatturun => revelationPlace;
  String get deskripsi => '';
  int get jumlahayat => versesCount;

  factory ChapterData.fromSqlite(Map<String, dynamic> row) {
    return ChapterData(
      id: row['id'] as int,
      name: row['name'] as String,
      nameSimple: row['name_simple'] as String,
      nameArabic: row['name_arabic'] as String,
      revelationOrder: row['revelation_order'] as int,
      revelationPlace: row['revelation_place'] as String,
      versesCount: row['verses_count'] as int,
      bismillahPre: row['bismillah_pre'] as int,
    );
  }
}

class PageLayoutData {
  final int pageNumber;
  final int lineNumber;
  final String lineType;
  final bool isCentered;
  final int? firstWordId;
  final int? lastWordId;
  final int? surahNumber;

  PageLayoutData({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    this.firstWordId,
    this.lastWordId,
    this.surahNumber,
  });

  factory PageLayoutData.fromSqlite(Map<String, dynamic> row) {
    return PageLayoutData(
      pageNumber: row['page_number'] as int,
      lineNumber: row['line_number'] as int,
      lineType: row['line_type'] as String,
      isCentered: (row['is_centered'] as int) == 1,
      firstWordId: _parseIntSafely(row['first_word_id']),
      lastWordId: _parseIntSafely(row['last_word_id']),
      surahNumber: _parseIntSafely(row['surah_number']),
    );
  }

  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return int.tryParse(value);
    }
    return null;
  }
}

class MushafPageData {
  final int pageNumber;
  final List<MushafLine> lines;
  MushafPageData({required this.pageNumber, required this.lines});
}

class MushafLine {
  final int lineNumber;
  final MushafLineType lineType;
  final bool isCentered;
  final String content;
  final List<WordData>? words;
  final int? firstWordId;
  final int? lastWordId;
  final int? surahNumber;

  MushafLine({
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    required this.content,
    this.words,
    this.firstWordId,
    this.lastWordId,
    this.surahNumber,
  });
}

class MushafPageLine {
  final int lineNumber;
  final String lineType; // 'surah_name', 'basmallah', 'ayah'
  final bool isCentered;
  final int? firstWordId;
  final int? lastWordId;
  final int? surahNumber;
  final String? surahNameArabic;
  final String? surahNameSimple;
  final String? basmallahText;
  final List<AyahSegment>? ayahSegments;

  MushafPageLine({
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    this.firstWordId,
    this.lastWordId,
    this.surahNumber,
    this.surahNameArabic,
    this.surahNameSimple,
    this.basmallahText,
    this.ayahSegments,
  });
}

class AyahSegment {
  final int surahId;
  final int ayahNumber;
  final List<WordData> words;
  bool isStartOfAyah;
  bool isEndOfAyah;
  final String? ayahGlyphText; // NEW: Concatenated glyphs from ABA database
  final dynamic charMap; // NEW: AyahCharMap for this ayah (if available)

  AyahSegment({
    required this.surahId,
    required this.ayahNumber,
    required this.words,
    required this.isStartOfAyah,
    required this.isEndOfAyah,
    this.ayahGlyphText, // Optional for backward compatibility
    this.charMap, // Optional char mapping
  });

  int get id => surahId * 1000 + ayahNumber;
  String get verseKey => '$surahId:$ayahNumber';
}

class TextSegment {
  final String text;
  final bool isArabicNumber;
  TextSegment({required this.text, required this.isArabicNumber});
}

class AyatProgress {
  final int ayatIndex;
  final int totalWords;
  final int correctWords;
  final int errorWords;
  final int skippedWords;
  final double completionPercentage;
  final bool isCompleted;

  AyatProgress({
    required this.ayatIndex,
    required this.totalWords,
    required this.correctWords,
    required this.errorWords,
    required this.skippedWords,
    required this.completionPercentage,
    required this.isCompleted,
  });
}

class PageGeometry {
  /// Map of word coordinates for a single page.
  /// Key: "surahId:ayahNumber:wordNumber"
  /// Value: List of Rects (to support multi-line wrap if it ever happens at word level, but usually one rect)
  final Map<String, List<Rect>> wordBounds;
  
  PageGeometry({required this.wordBounds});

  static String getWordKey(int surah, int ayah, int word) => '$surah:$ayah:$word';
}
