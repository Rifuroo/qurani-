// lib\screens\main\stt\services\mutashabihat_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
import '../database/db_helper.dart';

class SimilarVerseReference {
  final int surah;
  final int ayah;
  final String verseText;
  final String? matchingPhrase;
  final String? difference;
  final String? transliteration;
  final int? score;
  final int? coverage;

  SimilarVerseReference({
    required this.surah,
    required this.ayah,
    required this.verseText,
    this.matchingPhrase,
    this.difference,
    this.transliteration,
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
      final phraseVersesString = await rootBundle.loadString(
        'assets/data/phrase_verses.json',
      );
      _phraseVerses = json.decode(phraseVersesString);

      final phrasesString = await rootBundle.loadString(
        'assets/data/phrases.json',
      );
      _phrases = json.decode(phrasesString);

      // Ensure databases are open
      await DBHelper.ensureOpen(DBType.uthmani);
      await DBHelper.ensureOpen(DBType.mutashabihat);

      _isInitialized = true;
      debugPrint(
        'MutashabihatService: Initialized with ${_phraseVerses.length} verses having similar phrases',
      );
    } catch (e) {
      debugPrint('MutashabihatService: Failed to initialize: $e');
    }
  }

  Future<List<SimilarVerseReference>> getSimilarVerses(
    int surah,
    int ayah,
  ) async {
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

        results.add(
          SimilarVerseReference(
            surah: mSurah,
            ayah: mAyah,
            verseText: text,
            score: map['score'],
            coverage: map['coverage'],
            difference:
                'Coverage: ${map['coverage']}%, Words: ${map['matched_words_count']}',
          ),
        );
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

  Future<List<MutashabihatPhrase>> getPhrasesForVerse(
    int surah,
    int ayah,
  ) async {
    if (!_isInitialized) await initialize();
    final String key = '$surah:$ayah';

    debugPrint('MutashabihatService: getPhrasesForVerse for $key');
    if (!_phraseVerses.containsKey(key)) {
      debugPrint('MutashabihatService: No phrases found for $key');
      return [];
    }

    final List<dynamic> phraseIds = _phraseVerses[key];
    debugPrint(
      'MutashabihatService: Found ${phraseIds.length} phrase IDs for $key',
    );
    List<MutashabihatPhrase> results = [];

    for (var id in phraseIds) {
      final String phraseId = id.toString();
      if (_phrases.containsKey(phraseId)) {
        final data = _phrases[phraseId];
        final Map<String, dynamic> ayahMap = data['ayah'] ?? {};
        final List<String> verseKeys = ayahMap.keys.toList();

        // Count unique chapters (surahs)
        final Set<int> chapters = verseKeys
            .map((k) => int.parse(k.split(':')[0]))
            .toSet();

        debugPrint(
          'MutashabihatService: Phrase $phraseId has ${verseKeys.length} occurrences',
        );
        final String resolvedText = await _resolvePhraseText(data);

        results.add(
          MutashabihatPhrase(
            phraseId: phraseId,
            text: resolvedText,
            totalOccurrences: data['count'] ?? verseKeys.length,
            totalChapters: data['surahs'] ?? chapters.length,
            verseKeys: verseKeys,
          ),
        );
      } else {
        debugPrint(
          'MutashabihatService: Phrase $phraseId details not found in _phrases',
        );
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

  Future<String> _resolvePhraseText(Map<String, dynamic> data) async {
    if (data.containsKey('text')) return data['text'] as String;

    if (data.containsKey('source')) {
      try {
        final source = data['source'];
        final key = source['key'] as String;
        final parts = key.split(':');
        if (parts.length != 2) return '';

        final surah = int.parse(parts[0]);
        final ayah = int.parse(parts[1]);
        final from = source['from'] as int;
        final to = source['to'] as int;

        final uthmaniDb = await DBHelper.ensureOpen(DBType.uthmani);
        final List<Map<String, dynamic>> wordsResult = await uthmaniDb.query(
          'words',
          columns: ['text'],
          where: 'surah = ? AND ayah = ? AND word >= ? AND word <= ?',
          whereArgs: [surah, ayah, from, to],
          orderBy: 'word ASC',
        );

        return wordsResult.map((w) => w['text'] as String).join(' ');
      } catch (e) {
        debugPrint('MutashabihatService: Error resolving phrase text: $e');
        return '';
      }
    }

    return '';
  }

  Future<String?> getTransliteration(int surah, int ayah) async {
    // This will be called for each similar verse.
    // We should ideally use a cached service or a batch query for performance.
    // For now, we'll delegate to the resource service.
    try {
      final resourceService = QuranResourceService();
      return await resourceService.getTransliterationText(surah, ayah);
    } catch (e) {
      return null;
    }
  }
}
