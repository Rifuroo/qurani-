// lib\screens\main\stt\database\db_helper.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

enum DBType {
  metadata,
  qpc_v4_15,
  qpc_v4_wbw,
  qpc_v1_aba,
  uthmani,
  indopak_15,
  indopak_wbw,
}

class DBHelper {
  static final Map<DBType, Database> _dbInstances = {};

  static Future<Database> openDB(DBType type) async {
    // ✅ Check if already open
    if (_dbInstances.containsKey(type)) {
      final db = _dbInstances[type]!;
      if (db.isOpen) {
        return db;
      } else {
        print('[DBHelper] Database $type was closed, removing from cache...');
        _dbInstances.remove(type);
      }
    }

    // mapping lokasi assets + nama database
    final dbConfig = {
      DBType.metadata: {
        "asset": "assets/data/quran-metadata-surah-name.sqlite",
        "name": "quran-metadata-surah-name.sqlite",
      },
      DBType.qpc_v4_15: {
        "asset": "assets/kfgqpc/qpc-v4-tajweed-15-lines.db",
        "name": "qpc-v4-tajweed-15-lines.db",
      },
      DBType.qpc_v4_wbw: {
        "asset": "assets/kfgqpc/qpc-v4.db",
        "name": "qpc-v4.db",
      },
      DBType.uthmani: {"asset": "assets/data/uthmani.db", "name": "uthmani.db"},
      DBType.indopak_15: {
        "asset": "assets/indopak/qudratullah-indopak-15-lines.db",
        "name": "qudratullah-indopak-15-lines.db",
      },
      DBType.indopak_wbw: {
        "asset": "assets/indopak/indopak-nastaleeq-word-by-word.db",
        "name": "indopak-nastaleeq-word-by-word.db",
      },
    };

    final assetPath = dbConfig[type]!["asset"]!;
    final dbName = dbConfig[type]!["name"]!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    // cek kalau belum ada → copy dari assets
    if (!await databaseExists(path)) {
      await Directory(dirname(path)).create(recursive: true);
      ByteData data = await rootBundle.load(assetPath);
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(path).writeAsBytes(bytes, flush: true);
      print('[DBHelper] Copied $dbName from assets');
    }

    final db = await openDatabase(path, readOnly: true);
    _dbInstances[type] = db;
    print('[DBHelper] Opened $dbName successfully');
    return db;
  }

  // ✅ IMPROVED: Close all databases with proper error handling
  static Future<void> closeAllDatabases() async {
    print('[DBHelper] 🔒 Closing ${_dbInstances.length} database instances...');

    for (final entry in _dbInstances.entries) {
      try {
        if (entry.value.isOpen) {
          await entry.value.close();
          print('[DBHelper] ✅ Closed ${entry.key}');
        }
      } catch (e) {
        print('[DBHelper] ⚠️ Error closing ${entry.key}: $e');
        // Continue closing others
      }
    }

    _dbInstances.clear();
    print('[DBHelper] ✅ All databases closed and cache cleared');
  }

  static Future<void> preInitializeAll() async {
    print('[DBHelper] Pre-initializing all databases...');

    // Open semua database parallel
    await Future.wait([
      ensureOpen(DBType.metadata),
      ensureOpen(DBType.qpc_v4_15),
      ensureOpen(DBType.qpc_v4_wbw),
      ensureOpen(DBType.uthmani),
      ensureOpen(DBType.indopak_15),
      ensureOpen(DBType.indopak_wbw),
    ]);

    print(
      '[DBHelper] All databases pre-initialized (${_dbInstances.length} instances)',
    );
  }

  static Future<Database> ensureOpen(DBType type) async {
    if (_dbInstances.containsKey(type)) {
      final db = _dbInstances[type]!;
      if (db.isOpen) {
        return db;
      } else {
        print('[DBHelper] Database $type was closed, reopening...');
        _dbInstances.remove(type);
      }
    }

    return await openDB(type);
  }

  // TAMBAHAN: Method untuk reset database (jika diperlukan)
  static Future<void> resetDatabase(DBType type) async {
    if (_dbInstances.containsKey(type)) {
      await _dbInstances[type]!.close();
      _dbInstances.remove(type);
    }

    final dbConfig = {
      DBType.metadata: "quran-metadata-surah-name.sqlite",
      DBType.qpc_v4_15: "qpc-v4-tajweed-15-lines.db",
      DBType.qpc_v4_wbw: "qpc-v4.db",
      DBType.uthmani: "uthmani.db",
    };

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbConfig[type]!);

    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }
  }
}
