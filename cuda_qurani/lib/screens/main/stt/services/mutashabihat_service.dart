// lib\screens\main\stt\services\mutashabihat_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';

class SimilarVerseReference {
  final int surah;
  final int ayah;
  final String verseText;
  final String? matchingPhrase;
  final String? difference;
  final int? score;
  final int? coverage;

  SimilarVerseReference({
    required this.surah,
    required this.ayah,
    required this.verseText,
    this.matchingPhrase,
    this.difference,
    this.score,
    this.coverage,
  });

  String get verseKey => '$surah:$ayah';
}

class MutashabihatPhrase {
  final String phraseId;
  final String text;
  final int totalOccurrences;
  final int totalChapters;
  final List<String> verseKeys;

  MutashabihatPhrase({
    required this.phraseId,
    required this.text,
    required this.totalOccurrences,
    required this.totalChapters,
    required this.verseKeys,
  });
}

class MutashabihatService {
  static final MutashabihatService _instance = MutashabihatService._internal();
  factory MutashabihatService() => _instance;
  MutashabihatService._internal();

  bool _isInitialized = false;
  Map<String, dynamic> _phraseVerses = {};
  Map<String, dynamic> _phrases = {};

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // Load JSON mappings for phrase-level details
      final phraseVersesString = await rootBundle.loadString('assets/data/phrase_verses.json');
      _phraseVerses = json.decode(phraseVersesString);

      final phrasesString = await rootBundle.loadString('assets/data/phrases.json');
      _phrases = json.decode(phrasesString);

      // Ensure databases are open
      await DBHelper.ensureOpen(DBType.uthmani);
      await DBHelper.ensureOpen(DBType.mutashabihat);

      _isInitialized = true;
      debugPrint('MutashabihatService: Initialized with ${_phraseVerses.length} verses having similar phrases');
    } catch (e) {
      debugPrint('MutashabihatService: Failed to initialize: $e');
    }
  }

  Future<List<SimilarVerseReference>> getSimilarPhrases(int surah, int ayah) async {
    if (!_isInitialized) await initialize();

    try {
      final String key = '$surah:$ayah';
      final db = await DBHelper.ensureOpen(DBType.mutashabihat);
      
      // Query direct matches from SQLite
      final List<Map<String, dynamic>> maps = await db.query(
        'similar_ayahs',
        where: 'verse_key = ?',
        whereArgs: [key],
        orderBy: 'score DESC',
      );

      if (maps.isEmpty) return [];

      final uthmaniDb = await DBHelper.ensureOpen(DBType.uthmani);
      List<SimilarVerseReference> results = [];

      for (var map in maps) {
        final matchedKey = map['matched_ayah_key'] as String;
        final parts = matchedKey.split(':');
        if (parts.length != 2) continue;

        final mSurah = int.parse(parts[0]);
        final mAyah = int.parse(parts[1]);

        // Get verse text from 'words' table in uthmani.db and join them
        final List<Map<String, dynamic>> verseResult = await uthmaniDb.query(
          'words',
          columns: ['text'],
          where: 'surah = ? AND ayah = ?',
          whereArgs: [mSurah, mAyah],
          orderBy: 'word ASC',
        );

        String text = '';
        if (verseResult.isNotEmpty) {
          text = verseResult.map((w) => w['text'] as String).join(' ');
        }

        results.add(SimilarVerseReference(
          surah: mSurah,
          ayah: mAyah,
          verseText: text,
          score: map['score'],
          coverage: map['coverage'],
          difference: 'Coverage: ${map['coverage']}%, Words: ${map['matched_words_count']}',
        ));
      }

      return results;
    } catch (e) {
      debugPrint('MutashabihatService: Error getting similar phrases: $e');
      return [];
    }
  }

  /// Checks if a verse is "Unique" (Mufarradat) based on scholarly data.
  Future<bool> isUnique(int surah, int ayah) async {
    if (!_isInitialized) await initialize();
    final String key = '$surah:$ayah';
    
    // If it's not in the phrase_verses map, it has no major scholarly similarity mappings
    bool hasPhrases = _phraseVerses.containsKey(key);
    
    // Also check if it has entries in the similarity DB
    final similarityDb = await DBHelper.ensureOpen(DBType.mutashabihat);
    final List<Map<String, dynamic>> simResult = await similarityDb.query(
      'similar_ayahs',
      columns: ['verse_key'],
      where: 'verse_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return !hasPhrases && simResult.isEmpty;
  }

  Future<List<MutashabihatPhrase>> getPhrasesForVerse(int surah, int ayah) async {
    if (!_isInitialized) await initialize();
    final String key = '$surah:$ayah';
    
    if (!_phraseVerses.containsKey(key)) return [];
    
    final List<dynamic> phraseIds = _phraseVerses[key];
    List<MutashabihatPhrase> results = [];
    
    for (var id in phraseIds) {
      final String phraseId = id.toString();
      if (_phrases.containsKey(phraseId)) {
        final data = _phrases[phraseId];
        final List<dynamic> verseKeysList = data['verses'] ?? [];
        final List<String> verseKeys = verseKeysList.map((e) => e.toString()).toList();
        
        // Count unique chapters (surahs)
        final Set<int> chapters = verseKeys.map((k) => int.parse(k.split(':')[0])).toSet();
        
        results.add(MutashabihatPhrase(
          phraseId: phraseId,
          text: data['text'] ?? '',
          totalOccurrences: verseKeys.length,
          totalChapters: chapters.length,
          verseKeys: verseKeys,
        ));
      }
    }
    
    return results;
  }

  Future<String> getVerseText(int surah, int ayah) async {
    if (!_isInitialized) await initialize();
    final uthmaniDb = await DBHelper.ensureOpen(DBType.uthmani);
    
    final List<Map<String, dynamic>> verseResult = await uthmaniDb.query(
      'words',
      columns: ['text'],
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      orderBy: 'word ASC',
    );

    if (verseResult.isNotEmpty) {
      return verseResult.map((w) => w['text'] as String).join(' ');
    }
    return '';
  }
}
