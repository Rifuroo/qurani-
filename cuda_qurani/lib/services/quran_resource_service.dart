import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'resource_database_helper.dart';

class QuranResourceService extends ChangeNotifier {
  static final QuranResourceService _instance =
      QuranResourceService._internal();
  factory QuranResourceService() => _instance;
  QuranResourceService._internal();

  final ResourceDatabaseHelper _dbHelper = ResourceDatabaseHelper();

  // We no longer keep the full Map in memory to save RAM.
  // Instead, we just track the active DB name (identifier).
  String? _activeTafsirDbName;
  String? _activeTranslationDbName;

  String? _selectedTafsirId;
  String? _selectedTranslationId;
  String? _selectedTafsirName;
  String? _selectedTranslationName;
  String? _selectedTafsirLanguage;
  String? _selectedTranslationLanguage;

  String? get selectedTafsirId => _selectedTafsirId;
  String? get selectedTranslationId => _selectedTranslationId;

  String? get selectedTafsirName => _selectedTafsirName;
  String? get selectedTranslationName => _selectedTranslationName;

  String? get selectedTafsirLanguage => _selectedTafsirLanguage;
  String? get selectedTranslationLanguage => _selectedTranslationLanguage;

  static const Map<String, String> _langMap = {
    'العربية': 'Arabic',
    'বাংলা': 'Bengali',
    'اردو': 'Urdu',
    'Türkçe': 'Turkish',
    'فارسی': 'Persian',
    'Français': 'French',
    'Русский': 'Russian',
    'Español': 'Spanish',
    'Italiano': 'Italian',
    'മലയാളം': 'Malayalam',
    '日本語': 'Japanese',
    'অসমীয়া': 'Assamese',
    'Tagalog': 'Tagalog',
    'Tiếng Việt': 'Vietnamese',
    'Khmer': 'Khmer',
    'Kurdî': 'Kurdish',
    'Uzbek': 'Uzbek',
    'Swahili': 'Swahili',
    'Pashto': 'Pashto',
    'Bosanski': 'Bosanski',
  };

  String _sanitize(String s) => s
      .replaceAll(' ', '_')
      .replaceAll('/', '_')
      .replaceAll("'", "")
      .replaceAll('"', '')
      .replaceAll(':', '');

  String _getNameLang(String name, String lang, {bool useNative = true}) {
    final sName = _sanitize(name);
    final sLang = useNative
        ? _sanitize(lang)
        : (_langMap[lang] ?? _sanitize(lang));
    return '${sName}_$sLang';
  }

  /// Initialize and restore last selected resources
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTranslationId = prefs.getString('selected_translation_id');
      final savedTranslationNameLang = prefs.getString(
        'selected_translation_name_lang',
      );

      final savedTafsirId = prefs.getString('selected_tafsir_id');
      final savedTafsirNameLang = prefs.getString('selected_tafsir_name_lang');

      debugPrint(
        '[QuranResourceService] Initializing with: Translation=$savedTranslationId, Tafsir=$savedTafsirId',
      );

      if (savedTranslationId != null && savedTranslationNameLang != null) {
        await loadTranslation(
          savedTranslationId,
          savedTranslationNameLang,
          persist: false,
        );
      } else {
        // Load default translation (Sahih International)
        await loadTranslation(
          '193',
          'Sahih_International_English',
          persist: false,
        );
      }

      if (savedTafsirId != null && savedTafsirNameLang != null) {
        await loadTafsir(savedTafsirId, savedTafsirNameLang, persist: false);
      } else {
        // Load default tafsir (Tafsir Muyassar)
        await loadTafsir('38', 'Tafsir_Al-Muyassar_العربية', persist: false);
      }

      await ensureTransliterationLoaded();
    } catch (e) {
      debugPrint('[QuranResourceService] Initialization error: $e');
    }
  }

  /// Load a tafsir by its ID and Name_Language string
  Future<void> loadTafsir(
    String id,
    String nameLang, {
    bool persist = true,
  }) async {
    try {
      // 1. Try to find the DB (local or asset)
      String dbName = 'tafsir_$nameLang';
      bool exists = await _dbHelper.dbExists(dbName);

      if (!exists) {
        // Try multiple naming patterns for assets
        final nameOnly = nameLang.contains('_')
            ? nameLang.split('_').first
            : nameLang;
        final langOnly = nameLang.contains('_') ? nameLang.split('_').last : '';

        final possibleAssetPaths = [
          'assets/data/tafsir/$nameLang.db',
          'assets/data/tafsir/${nameOnly}_${_langMap[langOnly] ?? langOnly}.db',
          'assets/data/tafsir/$nameOnly.db',
          'assets/data/tafsir/$nameLang.json',
        ];

        bool copied = false;
        for (final path in possibleAssetPaths) {
          try {
            await _dbHelper.copyFromAssets(path, dbName);
            debugPrint('Successfully loaded tafsir from asset: $path');
            copied = true;
            break;
          } catch (_) {}
        }

        if (!copied) {
          debugPrint('Could not find tafsir asset for $nameLang');
          // If we can't find it, we can't load it
          return;
        }
      }

      _activeTafsirDbName = dbName;
      _selectedTafsirId = id;
      _selectedTafsirName = nameLang.contains('_')
          ? nameLang.split('_').first.replaceAll('_', ' ')
          : nameLang;
      _selectedTafsirLanguage = nameLang.contains('_')
          ? nameLang.split('_').last
          : 'English';

      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_tafsir_id', id);
        await prefs.setString('selected_tafsir_name_lang', nameLang);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tafsir $id ($nameLang): $e');
    }
  }

  /// Download a resource from the Tarteel or Quran.com servers
  Future<void> downloadResource(
    String category,
    String id,
    String name,
    String lang,
  ) async {
    final key = '${id}_$name';
    if (_downloadProgress.containsKey(key)) return;

    final sanitizedName = _sanitize(name);
    final sanitizedLang = _sanitize(lang);
    final remoteFileName = '$id.db'; // Tarteel uses ID.db often

    // Attempt multiple possible URL patterns if one fails
    final urls = [
      'https://tarteel.fra1.digitaloceanspaces.com/quran/translations/$id.db',
      'https://tarteel.fra1.digitaloceanspaces.com/quran/tafsir/$id.db',
      'https://api.quran.com/api/v4/resources/translations/$id/download',
    ];

    String? successUrl;
    final dbName = '${category}_${sanitizedName}_$sanitizedLang';
    final docsDir = await getApplicationDocumentsDirectory();
    final savePath = p.join(docsDir.path, 'resources', '$dbName.db');

    _downloadProgress[key] = 0.0;
    notifyListeners();

    final dio = Dio();
    bool downloaded = false;

    for (final url in urls) {
      if (downloaded) break;
      try {
        debugPrint('Attempting download from: $url');
        await dio.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              _downloadProgress[key] = received / total;
              notifyListeners();
            }
          },
        );
        downloaded = true;
        successUrl = url;
      } catch (e) {
        debugPrint('Failed to download from $url: $e');
      }
    }

    if (!downloaded) {
      // If all remote downloads fail, check if we can at least find it in assets
      // but if we are here, it means isDownloaded returned false or user explicitly wanted to download.
      debugPrint('All remote download attempts failed for $name');
    }

    _downloadProgress.remove(key);
    notifyListeners();
  }

  Map<String, double> _downloadProgress = {};
  Map<String, double> get downloadProgress => _downloadProgress;

  /// Check if a resource is downloaded/available (either in assets or already migrated to local DB)
  Future<bool> isDownloaded(String category, String name, String lang) async {
    final nameLangNative = _getNameLang(name, lang, useNative: true);
    final nameLangEnglish = _getNameLang(name, lang, useNative: false);

    // 1. Check local DB
    if (await _dbHelper.dbExists('${category}_$nameLangNative')) return true;
    if (await _dbHelper.dbExists('${category}_$nameLangEnglish')) return true;

    // 2. Check assets (.db or .json)
    final nameOnly = nameLangNative.contains('_')
        ? nameLangNative.split('_').first
        : nameLangNative;
    final paths = [
      'assets/data/$category/$nameLangNative.db',
      'assets/data/$category/$nameLangNative.json',
      'assets/data/$category/$nameLangEnglish.db',
      'assets/data/$category/$nameLangEnglish.json',
      'assets/data/$category/$nameOnly.db',
    ];

    for (final path in paths) {
      try {
        await rootBundle.load(path);
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// Load a translation by its ID and Name_Language string
  Future<void> loadTranslation(
    String id,
    String nameLang, {
    bool persist = true,
  }) async {
    try {
      String dbName = 'translation_$nameLang';
      bool exists = await _dbHelper.dbExists(dbName);

      if (!exists) {
        final nameOnly = nameLang.contains('_')
            ? nameLang.split('_').first
            : nameLang;
        final langOnly = nameLang.contains('_') ? nameLang.split('_').last : '';

        final possibleAssetPaths = [
          'assets/data/translation/$nameLang.db',
          'assets/data/translation/${nameOnly}_${_langMap[langOnly] ?? langOnly}.db',
          'assets/data/translation/$nameOnly.db',
          'assets/data/translation/${nameLang.replaceAll('_', ' ')}.db',
          'assets/data/translation/$nameLang.json',
        ];

        bool copied = false;
        for (final path in possibleAssetPaths) {
          try {
            await _dbHelper.copyFromAssets(path, dbName);
            debugPrint('Successfully loaded translation from asset: $path');
            copied = true;
            break;
          } catch (_) {}
        }

        if (!copied) {
          debugPrint('Could not find translation asset for $nameLang');
          return;
        }
      }

      _activeTranslationDbName = dbName;
      _selectedTranslationId = id;
      _selectedTranslationName = nameLang.contains('_')
          ? nameLang.split('_').first.replaceAll('_', ' ')
          : nameLang;
      _selectedTranslationLanguage = nameLang.contains('_')
          ? nameLang.split('_').last
          : 'English';

      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_translation_id', id);
        await prefs.setString('selected_translation_name_lang', nameLang);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading translation $id ($nameLang): $e');
    }
  }

  /// Get tafsir text for a specific ayah (format "surah:ayah")
  /// Support grouped tafsirs by probing for the correct table and group_ayah_key column
  Future<String?> getTafsirText(int surah, int ayah) async {
    if (_activeTafsirDbName == null) return null;

    String key = '$surah:$ayah';
    final db = await _dbHelper.getDatabase(_activeTafsirDbName!);

    // 1. Probe for table name
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final tableNames = tables.map((t) => t['name'] as String).toList();

    String tableName = 'tafsir';
    String idCol = 'ayah_key';

    if (tableNames.contains('tafsir')) {
      tableName = 'tafsir';
    } else if (tableNames.contains('resources')) {
      tableName = 'resources';
      idCol = 'id';
    } else if (tableNames.isNotEmpty) {
      tableName = tableNames.first;
    }

    // 2. Probe for group_ayah_key column
    final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    final columnNames = tableInfo.map((c) => c['name'] as String).toList();
    final hasGroupKey = columnNames.contains('group_ayah_key');

    // 3. Query for the entry
    final result = await db.query(
      tableName,
      columns: ['text', if (hasGroupKey) 'group_ayah_key'],
      where: '$idCol = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) return null;

    String? text = result.first['text'] as String?;
    String? groupKey = hasGroupKey
        ? result.first['group_ayah_key'] as String?
        : null;

    // 4. Resolve pointers if text is secondary (pointer resolution)
    if ((text == null ||
            text.trim().isEmpty ||
            (text.contains(':') && text.length < 10)) &&
        groupKey != null &&
        groupKey != key) {
      text = await _dbHelper.getText(
        _activeTafsirDbName!,
        groupKey,
        isTafsir: true,
      );
    }

    if (text == null) return null;

    // 5. Detect Real Range
    if (hasGroupKey && groupKey != null) {
      final allVerses = await db.query(
        tableName,
        columns: [idCol],
        where: 'group_ayah_key = ?',
        whereArgs: [groupKey],
        orderBy: '$idCol ASC',
      );

      if (allVerses.length > 1) {
        final first = allVerses.first[idCol] as String;
        final last = allVerses.last[idCol] as String;

        final lang = _selectedTafsirLanguage?.toLowerCase() ?? '';
        if (lang == 'bahasa indonesia' ||
            lang == 'indonesian' ||
            lang == 'indonesia') {
          text = 'GROUP_INFO|Ayat $first sampai $last|$text';
        } else {
          text = 'GROUP_INFO|verses from $first to $last|$text';
        }
      }
    }

    return text;
  }

  // / Get translation text for a specific ayah (format "surah:ayah")
  Future<String?> getTranslationText(int surah, int ayah) async {
    return _getResourceText(surah, ayah, _activeTranslationDbName);
  }

  Future<String?> getTransliterationText(int surah, int ayah) async {
    await ensureTransliterationLoaded();
    return _getResourceText(surah, ayah, 'transliteration');
  }

  Future<void> ensureTransliterationLoaded() async {
    const String dbName = 'transliteration';
    bool needsCopy = false;

    if (!await _dbHelper.dbExists(dbName)) {
      needsCopy = true;
    } else {
      // Check if the table exists. If not, it's likely a dummy DB created by onCreate
      try {
        final db = await _dbHelper.getDatabase(dbName);
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='transliteration'",
        );
        if (tables.isEmpty) {
          debugPrint(
            'Transliteration DB exists but is empty/invalid. Re-staging.',
          );
          needsCopy = true;
        }
      } catch (e) {
        debugPrint('Error checking transliteration DB: $e');
        needsCopy = true;
      }
    }

    if (needsCopy) {
      try {
        await _dbHelper.copyFromAssets(
          'assets/data/transliteration/transliteration.db',
          dbName,
        );
        debugPrint('Successfully staged transliteration.db');
      } catch (e) {
        debugPrint('Error staging transliteration.db: $e');
      }
    }
  }

  Future<String?> _getResourceText(int surah, int ayah, String? dbName) async {
    if (dbName == null) {
      debugPrint('getTranslationText: No active translation DB');
      return null;
    }

    String key = '$surah:$ayah';
    final db = await _dbHelper.getDatabase(dbName);
    debugPrint('getTranslationText: Querying $key in $dbName');

    // 1. Probe for table name
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final tableNames = tables.map((t) => t['name'] as String).toList();

    String tableName = 'translation';
    String idCol = 'ayah_key';

    if (tableNames.contains('transliteration')) {
      tableName = 'transliteration';
      idCol = 'ayah_key';
    } else if (tableNames.contains('translation')) {
      tableName = 'translation';
      idCol = 'ayah_key';
    } else if (tableNames.contains('resources')) {
      tableName = 'resources';
      // Check if 'id' or 'ayah_key' exists
      final tableInfo = await db.rawQuery('PRAGMA table_info(resources)');
      final cols = tableInfo.map((c) => c['name'] as String).toList();
      idCol = cols.contains('ayah_key') ? 'ayah_key' : 'id';
    } else if (tableNames.isNotEmpty) {
      tableName = tableNames.first;
      // Probe for id column
      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
      final cols = tableInfo.map((c) => c['name'] as String).toList();
      if (cols.contains('ayah_key')) {
        idCol = 'ayah_key';
      } else if (cols.contains('id')) {
        idCol = 'id';
      }
    }
    debugPrint('getTranslationText: Using table $tableName, idCol $idCol');

    // 2. Probe for group_ayah_key column
    final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    final columnNames = tableInfo.map((c) => c['name'] as String).toList();
    final hasGroupKey = columnNames.contains('group_ayah_key');

    // 3. Query for the entry and its metadata
    final result = await db.query(
      tableName,
      columns: ['text', if (hasGroupKey) 'group_ayah_key'],
      where: '$idCol = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) {
      debugPrint('getTranslationText: No result found for $key');
      return null;
    }

    String? text = result.first['text'] as String?;
    String? groupKey = hasGroupKey
        ? result.first['group_ayah_key'] as String?
        : null;

    if (text == null) {
      debugPrint('getTranslationText: Text is null for $key');
      return null;
    }
    debugPrint(
      'getTranslationText: Found text for $key (length: ${text.length})',
    );

    // 4. Detect Real Range
    if (hasGroupKey && groupKey != null) {
      final allVerses = await db.query(
        tableName,
        columns: [idCol],
        where: 'group_ayah_key = ?',
        whereArgs: [groupKey],
        orderBy: '$idCol ASC',
      );

      if (allVerses.length > 1) {
        final first = allVerses.first[idCol] as String;
        final last = allVerses.last[idCol] as String;

        final lang = _selectedTranslationLanguage?.toLowerCase() ?? '';
        if (lang == 'bahasa indonesia' ||
            lang == 'indonesian' ||
            lang == 'indonesia') {
          text = 'GROUP_INFO|Ayat $first sampai $last|$text';
        } else {
          text = 'GROUP_INFO|verses from $first to $last|$text';
        }
      }
    }

    return text;
  }
}
