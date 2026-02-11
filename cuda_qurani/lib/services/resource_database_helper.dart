
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ResourceDatabaseHelper {
  static final ResourceDatabaseHelper _instance = ResourceDatabaseHelper._internal();
  factory ResourceDatabaseHelper() => _instance;
  ResourceDatabaseHelper._internal();

  Database? _db;
  String? _currentDbPath;

  Future<Database> getDatabase(String dbName, {String? category}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'resources', '$dbName.db');
    
    if (_db != null && _currentDbPath == path) {
      return _db!;
    }

    if (_db != null) {
      await _db!.close();
    }

    // Ensure directory exists
    await Directory(dirname(path)).create(recursive: true);

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Use Tarteel-compatible table names by default if category is known
        if (category == 'tafsir') {
          await db.execute('''
            CREATE TABLE tafsir (
              ayah_key TEXT PRIMARY KEY,
              group_ayah_key TEXT,
              text TEXT,
              from_ayah TEXT,
              to_ayah TEXT,
              ayah_keys TEXT
            )
          ''');
          await db.execute('CREATE INDEX idx_tafsir_ayah ON tafsir(ayah_key)');
        } else if (category == 'translation') {
          await db.execute('''
            CREATE TABLE translation (
              ayah_key TEXT PRIMARY KEY,
              sura INTEGER,
              ayah INTEGER,
              text TEXT
            )
          ''');
          await db.execute('CREATE INDEX idx_translation_ayah ON translation(ayah_key)');
        } else {
          // Fallback legacy schema
          await db.execute('''
            CREATE TABLE resources (
              id TEXT PRIMARY KEY,
              text TEXT NOT NULL,
              metadata TEXT
            )
          ''');
          await db.execute('CREATE INDEX idx_resource_ayah ON resources(id)');
        }
      },
    );
    _currentDbPath = path;
    return _db!;
  }

  Future<void> insertBatch(String dbName, Map<String, dynamic> data, String category) async {
    final db = await getDatabase(dbName, category: category);
    final String tableName = category == 'tafsir' ? 'tafsir' : (category == 'translation' ? 'translation' : 'resources');
    final String idCol = tableName == 'resources' ? 'id' : 'ayah_key';

    await db.transaction((txn) async {
      final batch = txn.batch();
      data.forEach((key, value) {
        String? text;
        String? groupKey;

        if (value is String) {
          text = value;
        } else if (value is Map) {
          // Handle various JSON formats found in assets
          text = value['text'] ?? value['t']?.toString();
          
          // If the JSON itself contains a pointer (e.g. "1:1"), we set it as groupKey
          if (text != null && text.contains(':') && text.length < 10) {
             groupKey = text;
             text = null; // Mark as empty to trigger pointer resolution later
          }
        }

        if (text != null || groupKey != null) {
          final Map<String, dynamic> row = {
            idCol: key,
            'text': text,
          };
          if (tableName == 'tafsir') {
            row['group_ayah_key'] = groupKey ?? key;
          }
          if (tableName == 'translation') {
            final parts = key.split(':');
            if (parts.length == 2) {
              row['sura'] = int.tryParse(parts[0]);
              row['ayah'] = int.tryParse(parts[1]);
            }
          }
          
          batch.insert(
            tableName,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      await batch.commit(noResult: true);
    });
  }

  Future<String?> getText(String dbName, String key, {bool isTafsir = false}) async {
    final db = await getDatabase(dbName);
    
    // 1. Determine table name and ID column
    String tableName = 'resources';
    String idCol = 'id';
    
    // Probe for table existence
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tables.map((t) => t['name'] as String).toList();
    
    if (isTafsir && tableNames.contains('tafsir')) {
      tableName = 'tafsir';
      idCol = 'ayah_key';
    } else if (!isTafsir && tableNames.contains('translation')) {
      tableName = 'translation';
      idCol = 'ayah_key';
    } else if (tableNames.contains('resources')) {
      tableName = 'resources';
      idCol = 'id';
    } else if (tableNames.isNotEmpty) {
      tableName = tableNames.first;
    }

    // 2. Query for the specific key
    final results = await db.query(
      tableName,
      where: '$idCol = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final entry = results.first;
    String? text = entry['text'] as String?;
    
    // 3. Handle Tafsir group_ayah_key logic (Pointer resolution)
    if (isTafsir && tableName == 'tafsir' && (text == null || text.trim().isEmpty)) {
      final groupKey = entry['group_ayah_key'] as String?;
      if (groupKey != null && groupKey != key) {
        return await getText(dbName, groupKey, isTafsir: true);
      }
    }

    return text;
  }

  Future<bool> dbExists(String dbName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'resources', '$dbName.db');
    return File(path).exists();
  }

  /// Copy a pre-migrated database from assets to local storage
  Future<void> copyFromAssets(String assetPath, String dbName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'resources', '$dbName.db');
    
    // Ensure directory exists
    await Directory(dirname(path)).create(recursive: true);
    
    // Load asset and write to file
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);
    debugPrint('Successfully copied $assetPath to $path');
  }
}
