import 'package:path/path.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'user_bookmarks.db');

    return await openDatabase(
      path,
      version: 2, // ✅ Increment version
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            surah_id INTEGER NOT NULL,
            ayah_number INTEGER NOT NULL,
            surah_name TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            last_visited INTEGER, -- ✅ NEW
            UNIQUE(surah_id, ayah_number)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE bookmarks ADD COLUMN last_visited INTEGER',
          );
        }
      },
    );
  }

  Future<void> addBookmark({
    required int surahId,
    required int ayahNumber,
    required String surahName,
  }) async {
    final db = await database;
    await db.insert('bookmarks', {
      'surah_id': surahId,
      'ayah_number': ayahNumber,
      'surah_name': surahName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeBookmark(int surahId, int ayahNumber) async {
    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'surah_id = ? AND ayah_number = ?',
      whereArgs: [surahId, ayahNumber],
    );
  }

  /// ✅ NEW: Update last visited time for a bookmark
  Future<void> markAsVisited(int surahId, int ayahNumber) async {
    final db = await database;
    await db.update(
      'bookmarks',
      {'last_visited': DateTime.now().millisecondsSinceEpoch},
      where: 'surah_id = ? AND ayah_number = ?',
      whereArgs: [surahId, ayahNumber],
    );
  }

  Future<bool> isBookmarked(int surahId, int ayahNumber) async {
    final db = await database;
    final maps = await db.query(
      'bookmarks',
      where: 'surah_id = ? AND ayah_number = ?',
      whereArgs: [surahId, ayahNumber],
    );
    return maps.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAllBookmarks({
    String sortBy = 'timestamp',
    bool ascending = false,
  }) async {
    final db = await database;
    String orderBy;

    switch (sortBy) {
      case 'quran':
        orderBy =
            'surah_id ${ascending ? 'ASC' : 'DESC'}, ayah_number ${ascending ? 'ASC' : 'DESC'}';
        break;
      case 'visited':
        orderBy = 'last_visited ${ascending ? 'ASC' : 'DESC'}';
        break;
      case 'timestamp':
      default:
        orderBy = 'timestamp ${ascending ? 'ASC' : 'DESC'}';
        break;
    }

    return await db.query('bookmarks', orderBy: orderBy);
  }
}
