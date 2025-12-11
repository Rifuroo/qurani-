// lib/services/reciter_database_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:cuda_qurani/services/global_ayat_services.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class ReciterAudioData {
  final int surahNumber;
  final int ayahNumber;
  final String audioUrl;
  final int? duration; // in milliseconds
  final List<WordSegment> segments;

  ReciterAudioData({
    required this.surahNumber,
    required this.ayahNumber,
    required this.audioUrl,
    this.duration,
    required this.segments,
  });

  String get cacheFileName => '${surahNumber.toString().padLeft(3, '0')}${ayahNumber.toString().padLeft(3, '0')}.mp3';
}

class WordSegment {
  final int wordIndex;
  final int startMs;
  final int endMs;

  WordSegment({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });

  factory WordSegment.fromJson(List<dynamic> json) {
    // Format: [word_index, ?, start_ms, end_ms]
    return WordSegment(
      wordIndex: json[0] as int,
      startMs: json[2] as int,
      endMs: json[3] as int,
    );
  }
}

class ReciterDatabaseService {
  static Database? _database;
  static const String _dbAssetPath = 'assets/reciters/ayah-recitation-abdul-basit-abdul-samad-murattal-hafs-950.db';

  // Initialize database
  static Future<void> initialize() async {
    if (_database != null) return;

    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(documentsDirectory.path, 'reciter_audio.db');

      // Check if database exists
      final exists = await databaseExists(dbPath);

      if (!exists) {
        print('📦 Copying reciter database from assets...');
        // Copy from assets
        final ByteData data = await rootBundle.load(_dbAssetPath);
        final List<int> bytes = data.buffer.asUint8List();
        await File(dbPath).writeAsBytes(bytes, flush: true);
        print('✅ Reciter database copied successfully');
      }

      _database = await openDatabase(dbPath, readOnly: true);
      print('✅ Reciter database initialized');
    } catch (e) {
      print('❌ Error initializing reciter database: $e');
      rethrow;
    }
  }

  // Get audio data for specific verse using GLOBAL AYAT INDEX
  static Future<ReciterAudioData?> getVerseAudio(int surahNumber, int ayahNumber) async {
    if (_database == null) {
      await initialize();
    }

    try {
      // ✅ CRITICAL FIX: Convert (surah, ayah) → global ayat index
      final globalAyat = GlobalAyatService.toGlobalAyat(surahNumber, ayahNumber);
      
      print('🔍 Fetching audio: Surah $surahNumber Ayah $ayahNumber → Global Ayat #$globalAyat');

      // ✅ Query database using ayah_number = GLOBAL INDEX
      final List<Map<String, dynamic>> results = await _database!.query(
        'verses',
        where: 'ayah_number = ?',  // ✅ ayah_number = global index (1-6236)
        whereArgs: [globalAyat],
      );

      if (results.isEmpty) {
        print('⚠️ No audio found for Global Ayat #$globalAyat (Surah $surahNumber:$ayahNumber)');
        return null;
      }

      final row = results.first;
      
      // Parse segments JSON
      final segmentsJson = row['segments'] as String?;
      final List<WordSegment> segments = [];
      
      if (segmentsJson != null && segmentsJson.isNotEmpty) {
        try {
          final List<dynamic> segmentsList = jsonDecode(segmentsJson);
          segments.addAll(segmentsList.map((s) => WordSegment.fromJson(s)));
        } catch (e) {
          print('⚠️ Error parsing segments: $e');
        }
      }

      print('✅ Audio found: ${row['audio_url']}');

      return ReciterAudioData(
        surahNumber: surahNumber,  // ✅ Return original surah number
        ayahNumber: ayahNumber,    // ✅ Return original ayah number
        audioUrl: row['audio_url'] as String,
        duration: row['duration'] as int?,
        segments: segments,
      );
    } catch (e) {
      print('❌ Error fetching verse audio: $e');
      return null;
    }
  }

  // Get multiple verses (batch)
  static Future<List<ReciterAudioData>> getVersesAudio(List<Map<String, int>> verses) async {
    if (_database == null) {
      await initialize();
    }

    final List<ReciterAudioData> results = [];

    for (final verse in verses) {
      final audio = await getVerseAudio(verse['surah']!, verse['ayah']!);
      if (audio != null) {
        results.add(audio);
      }
    }

    return results;
  }

  static Future<void> dispose() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🗑️ Reciter database disposed');
    }
  }
}


