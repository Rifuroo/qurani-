// lib\screens\main\home\services\juz_service.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class JuzService {
  static Database? _juzDb;
  
  static Future<void> initialize() async {
    if (_juzDb != null && _juzDb!.isOpen) {
      print('[JuzService] Database already open');
      return;
    }
    
    try {
      final databasesPath = await getDatabasesPath();
      final juzPath = join(databasesPath, 'quran-metadata-juz.sqlite');
      
      // Copy from assets if not exists
      if (!await File(juzPath).exists()) {
        print('[JuzService] Copying quran-metadata-juz.sqlite from assets...');
        final data = await rootBundle.load('assets/data/quran-metadata-juz.sqlite');
        final bytes = data.buffer.asUint8List();
        await File(juzPath).writeAsBytes(bytes, flush: true);
        print('[JuzService] Database copied successfully');
      }
      
      _juzDb = await openDatabase(juzPath, readOnly: true);
      print('[JuzService] Database opened successfully');
    } catch (e, stackTrace) {
      print('[JuzService] Error: $e');
      print('[JuzService] Stack: $stackTrace');
      rethrow;
    }
  }
  
  /// Get all 30 Juz from database
  static Future<List<Map<String, dynamic>>> getAllJuz() async {
    if (_juzDb == null) await initialize();
    
    final result = await _juzDb!.query(
      'juz',
      orderBy: 'juz_number ASC',
    );
    
    print('[JuzService] Loaded ${result.length} juz from database');
    return result;
  }
  
  /// Get specific Juz by number
  static Future<Map<String, dynamic>?> getJuz(int juzNumber) async {
    if (_juzDb == null) await initialize();
    
    final result = await _juzDb!.query(
      'juz',
      where: 'juz_number = ?',
      whereArgs: [juzNumber],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first : null;
  }
  
  /// Parse verse_mapping JSON to get surah-ayah ranges
  /// Example: {"1":"1-7","2":"1-141"} means Surah 1 ayah 1-7, Surah 2 ayah 1-141
  static Map<int, String> parseVerseMapping(String mappingJson) {
    try {
      final decoded = mappingJson.replaceAll('"', '').replaceAll('{', '').replaceAll('}', '');
      final pairs = decoded.split(',');
      Map<int, String> result = {};
      
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final surahNum = int.tryParse(parts[0]);
          if (surahNum != null) {
            result[surahNum] = parts[1];
          }
        }
      }
      
      return result;
    } catch (e) {
      print('[JuzService] Error parsing verse_mapping: $e');
      return {};
    }
  }
  
  static Future<void> close() async {
    await _juzDb?.close();
    _juzDb = null;
  }
}


