// lib/services/reciter_manager_service.dart

import 'dart:convert';
import 'package:cuda_qurani/services/global_ayat_services.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReciterInfo {
  final int id;
  final String name;
  final String assetPath;
  final String identifier;

  ReciterInfo({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.identifier,
  });

  factory ReciterInfo.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: Direct mapping, no complex logic
    final id = json['id'] as int? ?? 0;
    final name = json['name'] as String? ?? 'Unknown Reciter';
    final assetPath = json['db_path'] as String? ?? '';
    final identifier = json['identifier'] as String? ?? '';

    // ✅ DEBUG: Log parsing
    print('🔍 Parsing reciter: $name');
    print('   → ID: $id');
    print('   → Path: "$assetPath"');
    print('   → Identifier: "$identifier"');

    if (assetPath.isEmpty) {
      print('⚠️ WARNING: Empty path for reciter: $name');
    }

    return ReciterInfo(
      id: id,
      name: name,
      assetPath: assetPath,
      identifier: identifier,
    );
  }
}

class ReciterManagerService {
  static List<ReciterInfo>? _reciters;
  static final Map<String, Database> _databases = {};

  static Future<List<ReciterInfo>> getAllReciters() async {
    if (_reciters != null) return _reciters!;

    try {
      print('📂 Loading JSON from: assets/reciters/data/reciters_data.json');
      final jsonString = await rootBundle.loadString(
        'assets/reciters/data/reciters_data.json',
      );

      print('📄 JSON loaded, length: ${jsonString.length} chars');
      print(
        '🔍 First 200 chars: ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}',
      );

      final List<dynamic> jsonList = jsonDecode(jsonString);
      print('📋 Decoded ${jsonList.length} items from JSON');

      // ✅ DEBUG: Print raw first item
      if (jsonList.isNotEmpty) {
        print('🔍 First item RAW: ${jsonList[0]}');
      }

      _reciters = jsonList.map((json) => ReciterInfo.fromJson(json)).toList();
      print('✅ Loaded ${_reciters!.length} reciters');

      return _reciters!;
    } catch (e) {
      print('❌ Error loading reciters: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get reciter by identifier
  static Future<ReciterInfo?> getReciterByIdentifier(String identifier) async {
    final reciters = await getAllReciters();
    try {
      return reciters.firstWhere((r) => r.identifier == identifier);
    } catch (e) {
      return null;
    }
  }

  // Initialize reciter database
  static Future<Database> _initReciterDatabase(ReciterInfo reciter) async {
    // Check if already initialized
    if (_databases.containsKey(reciter.identifier)) {
      return _databases[reciter.identifier]!;
    }

    try {
      // ✅ FIX: Validate assetPath BEFORE using it
      if (reciter.assetPath.isEmpty) {
        throw Exception('Asset path is empty for reciter: ${reciter.name}');
      }

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(
        documentsDirectory.path,
        'reciters',
        '${reciter.identifier}.db',
      );

      // Create directory if not exists
      final dbDir = Directory(path.dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      // Check if database exists
      final exists = await databaseExists(dbPath);

      if (!exists) {
        print('📦 Copying reciter database: ${reciter.name}');
        // Copy from assets
        final ByteData data = await rootBundle.load(reciter.assetPath);
        final List<int> bytes = data.buffer.asUint8List();
        await File(dbPath).writeAsBytes(bytes, flush: true);
        print('✅ Database copied: ${reciter.identifier}');
      }

      final db = await openDatabase(dbPath, readOnly: true);
      _databases[reciter.identifier] = db;

      return db;
    } catch (e) {
      print('❌ Error initializing reciter database: $e');
      rethrow;
    }
  }

  // Get audio URLs for specific surah from reciter
static Future<List<Map<String, dynamic>>> getSurahAudioUrls(
  String reciterIdentifier,
  int surahNumber,
) async {
  try {
    final reciter = await getReciterByIdentifier(reciterIdentifier);
    if (reciter == null) {
      throw Exception('Reciter not found: $reciterIdentifier');
    }

    // ✅ Validate assetPath
    if (reciter.assetPath.isEmpty) {
      print('❌ Empty asset path for reciter: ${reciter.name}');
      return [];
    }

    final db = await _initReciterDatabase(reciter);

    // ✅ Convert surah range to GLOBAL AYAT range
    final surahMeta = await _getSurahMetadata(surahNumber);
    final versesCount = surahMeta['verses_count'] as int;

    final startGlobalAyat = GlobalAyatService.toGlobalAyat(surahNumber, 1);
    final endGlobalAyat = GlobalAyatService.toGlobalAyat(surahNumber, versesCount);

    print('🔍 Query reciter DB for surah $surahNumber:');
    print('   → Global ayat range: $startGlobalAyat - $endGlobalAyat');
    print('   → Verses count: $versesCount');

    // ✅ Query with GLOBAL AYAT range (ayah_number column stores GLOBAL index)
    final results = await db.query(
      'verses',
      where: 'ayah_number BETWEEN ? AND ?',  // ← Only GLOBAL range needed
      whereArgs: [startGlobalAyat, endGlobalAyat],
      orderBy: 'ayah_number ASC',
    );

    print('✅ Found ${results.length} verses for surah $surahNumber');

    return results
        .map(
          (row) => {
            'surah_number': surahNumber,  // ← Return original surah
            'ayah_number': row['ayah_number'],  // ← GLOBAL index (for filtering)
            'audio_url': row['audio_url'],
            'duration': row['duration'],
            'segments': row['segments'],
          },
        )
        .toList();
  } catch (e) {
    print('❌ Error getting surah audio URLs: $e');
    print('📍 Stack: ${StackTrace.current}');
    return [];
  }
}

  // ✅ NEW: Helper to get surah metadata
  static Future<Map<String, dynamic>> _getSurahMetadata(int surahNumber) async {
    try {
      // Use MetadataCacheService if available
      final surah = MetadataCacheService().getSurah(surahNumber);
      if (surah != null) {
        return surah;
      }

      // Fallback: Default verse counts (hardcoded for safety)
      final defaultVerseCounts = {
        1: 7,
        2: 286,
        3: 200,
        4: 176,
        5: 120,
        6: 165,
        7: 206,
        8: 75,
        9: 129,
        10: 109,
        11: 123,
        12: 111,
        13: 43,
        14: 52,
        15: 99,
        16: 128,
        17: 111,
        18: 110,
        19: 98,
        20: 135,
        21: 112,
        22: 78,
        23: 118,
        24: 64,
        25: 77,
        26: 227,
        27: 93,
        28: 88,
        29: 69,
        30: 60,
        31: 34,
        32: 30,
        33: 73,
        34: 54,
        35: 45,
        36: 83,
        37: 182,
        38: 88,
        39: 75,
        40: 85,
        41: 54,
        42: 53,
        43: 89,
        44: 59,
        45: 37,
        46: 35,
        47: 38,
        48: 29,
        49: 18,
        50: 45,
        51: 60,
        52: 49,
        53: 62,
        54: 55,
        55: 78,
        56: 96,
        57: 29,
        58: 22,
        59: 24,
        60: 13,
        61: 14,
        62: 11,
        63: 11,
        64: 18,
        65: 12,
        66: 12,
        67: 30,
        68: 52,
        69: 52,
        70: 44,
        71: 28,
        72: 28,
        73: 20,
        74: 56,
        75: 40,
        76: 31,
        77: 50,
        78: 40,
        79: 46,
        80: 42,
        81: 29,
        82: 19,
        83: 36,
        84: 25,
        85: 22,
        86: 17,
        87: 19,
        88: 26,
        89: 30,
        90: 20,
        91: 15,
        92: 21,
        93: 11,
        94: 8,
        95: 8,
        96: 19,
        97: 5,
        98: 8,
        99: 8,
        100: 11,
        101: 11,
        102: 8,
        103: 3,
        104: 9,
        105: 5,
        106: 4,
        107: 7,
        108: 3,
        109: 6,
        110: 3,
        111: 5,
        112: 4,
        113: 5,
        114: 6,
      };

      return {
        'id': surahNumber,
        'verses_count': defaultVerseCounts[surahNumber] ?? 1,
      };
    } catch (e) {
      print('⚠️ Error getting surah metadata: $e');
      return {'id': surahNumber, 'verses_count': 1};
    }
  }

  // Get single verse audio
  static Future<Map<String, dynamic>?> getVerseAudio(
    String reciterIdentifier,
    int surahNumber,
    int ayahNumber,
  ) async {
    try {
      final reciter = await getReciterByIdentifier(reciterIdentifier);
      if (reciter == null) return null;

      final db = await _initReciterDatabase(reciter);

      final results = await db.query(
        'verses',
        where: 'surah_number = ? AND ayah_number = ?',
        whereArgs: [surahNumber, ayahNumber],
      );

      if (results.isEmpty) return null;

      return results.first;
    } catch (e) {
      print('❌ Error getting verse audio: $e');
      return null;
    }
  }

  // Dispose specific reciter database
  static Future<void> disposeReciter(String reciterIdentifier) async {
    if (_databases.containsKey(reciterIdentifier)) {
      await _databases[reciterIdentifier]?.close();
      _databases.remove(reciterIdentifier);
      print('🗑️ Disposed reciter database: $reciterIdentifier');
    }
  }

  // Dispose all databases
  static Future<void> disposeAll() async {
    for (final db in _databases.values) {
      await db.close();
    }
    _databases.clear();
    print('🗑️ All reciter databases disposed');
  }
}



