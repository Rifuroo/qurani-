// lib/screens/main/home/screens/settings/widgets/audio_manager.dart

import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/services/audio_download_services.dart';
import 'package:cuda_qurani/services/reciter_manager_services.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';

class AudioManagerPage extends StatefulWidget {
  final String reciterName;
  final String reciterIdentifier;

  const AudioManagerPage({
    Key? key,
    required this.reciterName,
    required this.reciterIdentifier,
  }) : super(key: key);

  @override
  State<AudioManagerPage> createState() => _AudioManagerPageState();
}

class _AudioManagerPageState extends State<AudioManagerPage> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/downloads');
    setState(() {
      _translations = trans;
    });
  }

  // Download state
  final Map<int, double> _downloadProgress = {};
  final Map<int, bool> _downloadedStatus = {};
  final Set<int> _downloadingIds = {};

  // Storage info
  Map<String, dynamic> _storageInfo = {
    'totalBytes': 0,
    'fileCount': 0,
    'formattedSize': '0 KB',
  };

  // Download speed tracking
  final Map<int, String> _downloadSpeeds = {};

  List<Map<String, dynamic>> _allSurahs = [];
  bool _isLoading = true;
  bool _isDownloadingAll = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadTranslations();
  }

  Future<void> _initialize() async {
    await _loadSurahs();
    await _loadStorageInfo();
    await _checkDownloadedStatus();
  }

  Future<void> _loadSurahs() async {
    try {
      await MetadataCacheService().initialize();
      _allSurahs = MetadataCacheService().allSurahs;

      // Initialize progress
      for (var surah in _allSurahs) {
        final surahId = surah['id'] as int;
        _downloadProgress[surahId] = 0.0;
        _downloadedStatus[surahId] = false;
      }
    } catch (e) {}
  }

  Future<void> _loadStorageInfo() async {
    final info = await AudioDownloadService.getReciterStorageInfo(
      widget.reciterIdentifier,
    );

    if (mounted) {
      setState(() {
        _storageInfo = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkDownloadedStatus() async {
    // ✅ STEP 1: Scan ALL cached files ONCE (super fast)
    final cachedFiles = await AudioDownloadService.getAllCachedFiles(
      widget.reciterIdentifier,
    );

    // ✅ STEP 2: Check each surah against cached files (in-memory lookup)
    for (var surah in _allSurahs) {
      final surahId = surah['id'] as int;
      final audioUrls = await ReciterManagerService.getSurahAudioUrls(
        widget.reciterIdentifier,
        surahId,
      );

      if (audioUrls.isEmpty) continue;

      // ✅ FAST: O(1) lookup from Set
      int downloadedCount = 0;
      for (var verse in audioUrls) {
        final fileName = AudioDownloadService.getCacheFileNameFromUrl(
          verse['audio_url'],
        );
        if (cachedFiles.contains(fileName)) {
          downloadedCount++;
        }
      }

      if (mounted) {
        setState(() {
          final percentage = audioUrls.isEmpty
              ? 0.0
              : (downloadedCount / audioUrls.length);
          _downloadProgress[surahId] = percentage;
          _downloadedStatus[surahId] = percentage >= 1.0;
        });
      }
    }
  }

  Future<void> _downloadSurah(int surahId) async {
    if (_downloadingIds.contains(surahId)) return;

    setState(() {
      _downloadingIds.add(surahId);
      _downloadProgress[surahId] = 0.0;
    });

    AppHaptics.selection();

    try {
      // Get all audio URLs for this surah
      final audioUrls = await ReciterManagerService.getSurahAudioUrls(
        widget.reciterIdentifier,
        surahId,
      );

      if (audioUrls.isEmpty) {
        throw Exception('No audio URLs found for surah $surahId');
      }

      print('📥 Downloading ${audioUrls.length} verses for surah $surahId');

      int completed = 0;

      for (var verse in audioUrls) {
        if (!_downloadingIds.contains(surahId)) break; // Cancelled

        final audioUrl = verse['audio_url'] as String;

        await AudioDownloadService.downloadAudio(
          widget.reciterIdentifier,
          audioUrl,
          onProgress: (progress) {
            if (mounted && _downloadingIds.contains(surahId)) {
              setState(() {
                _downloadSpeeds[surahId] = progress.speedFormatted;
              });
            }
          },
        );

        completed++;

        if (mounted && _downloadingIds.contains(surahId)) {
          setState(() {
            _downloadProgress[surahId] = completed / audioUrls.length;
          });
        }
      }

      if (mounted) {
        setState(() {
          _downloadProgress[surahId] = 1.0;
          _downloadedStatus[surahId] = true;
          _downloadingIds.remove(surahId);
          _downloadSpeeds.remove(surahId);
        });

        await _loadStorageInfo();
      }

      print('✅ Surah $surahId downloaded successfully');
    } catch (e) {
      print('❌ Error downloading surah $surahId: $e');

      if (mounted) {
        setState(() {
          _downloadingIds.remove(surahId);
          _downloadSpeeds.remove(surahId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAll() async {
    if (_isDownloadingAll) return;

    setState(() {
      _isDownloadingAll = true;
    });

    AppHaptics.selection();

    for (var surah in _allSurahs) {
      final surahId = surah['id'] as int;

      // Skip if already downloaded
      if (_downloadedStatus[surahId] == true) continue;

      await _downloadSurah(surahId);

      // Small delay between surahs
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() {
        _isDownloadingAll = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(
                  _translations,
                  'reciters.audio_manager.clear_cache_text',
                )
              : 'Clear Cache',
        ),
        content: Text(
          '${LanguageHelper.tr(_translations, "reciters.audio_manager.clear_cache_desc")} '
          '${widget.reciterName}?\n\n'
          '${LanguageHelper.tr(_translations, "reciters.audio_manager.using_text")} '
          '${context.formatNumber(_storageInfo['formattedSize'])}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(
                      _translations,
                      'reciters.audio_manager.cancel_text',
                    )
                  : 'Cancel',
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(
                      _translations,
                      'reciters.audio_manager.clear_cache_text',
                    )
                  : 'Delete',
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AudioDownloadService.clearReciterCache(widget.reciterIdentifier);

      // Reset state
      for (var surah in _allSurahs) {
        final surahId = surah['id'] as int;
        setState(() {
          _downloadProgress[surahId] = 0.0;
          _downloadedStatus[surahId] = false;
        });
      }

      await _loadStorageInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _getSurahDisplayName(Map<String, dynamic> surah) {
    final nameSimple = surah['name_simple'] as String?;
    final transliteration = surah['name_transliterated'] as String?;
    return transliteration ?? nameSimple ?? 'Surah ${surah['id']}';
  }

  Widget _buildSurahItem({
    required int surahId,
    required String surahName,
    required double progress,
    required bool isDownloading,
    required bool isDownloaded,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    final downloadSpeed = _downloadSpeeds[surahId];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space12 * s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 1.0 * s),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surahName,
                  style: TextStyle(
                    fontSize: 16 * s,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isDownloading && downloadSpeed != null) ...[
                  SizedBox(height: 4 * s),
                  Text(
                    downloadSpeed,
                    style: TextStyle(
                      fontSize: 12 * s,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: AppDesignSystem.space12 * s),

          // Progress indicator
          if (isDownloading) ...[
            SizedBox(
              width: 40 * s,
              child: Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12 * s,
                  fontWeight: AppTypography.medium,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ] else ...[
            SizedBox(
              width: 40 * s,
              child: Text(
                isDownloaded ? '100%' : '0%',
                style: TextStyle(
                  fontSize: 12 * s,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],

          SizedBox(width: AppDesignSystem.space8 * s),

          // Download button
          InkWell(
            onTap: isDownloaded || isDownloading
                ? null
                : () => _downloadSurah(surahId),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 32 * s,
              height: 32 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDownloaded
                    ? const Color(0xFF4CAF50)
                    : AppColors.borderLight,
              ),
              child: Center(
                child: isDownloading
                    ? SizedBox(
                        width: 16 * s,
                        height: 16 * s,
                        child: CircularProgressIndicator(
                          strokeWidth: 2 * s,
                          color: Colors.white,
                          value: progress,
                        ),
                      )
                    : Icon(
                        isDownloaded ? Icons.check : Icons.arrow_downward,
                        size: 16 * s,
                        color: isDownloaded
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(
                _translations,
                'reciters.audio_manager.audio_manager_text',
              )
            : 'Audio Manager',
        actions: [
          if (_storageInfo['totalBytes'] > 0)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 24 * s),
              onPressed: _clearCache,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with storage info
                  Padding(
                    padding: EdgeInsets.all(AppDesignSystem.space20 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.reciterName,
                          style: TextStyle(
                            fontSize: 18 * s,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppDesignSystem.space8 * s),
                        Row(
                          children: [
                            Icon(
                              Icons.storage,
                              size: 16 * s,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: AppDesignSystem.space8 * s),
                            Text(
                              '${LanguageHelper.tr(_translations, "reciters.audio_manager.using_text")} '
                              '${context.formatNumber(_storageInfo['formattedSize'])} '
                              '(${context.formatNumber(_storageInfo['fileCount'])} ${LanguageHelper.tr(_translations, "reciters.files_text")})',
                              style: TextStyle(
                                fontSize: 14 * s,
                                fontWeight: AppTypography.regular,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Download all button
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.space20 * s,
                    ),
                    child: InkWell(
                      onTap: _isDownloadingAll ? null : _downloadAll,
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusRound * s,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: AppDesignSystem.space12 * s,
                        ),
                        decoration: BoxDecoration(
                          color: _isDownloadingAll
                              ? AppColors.borderLight
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppDesignSystem.radiusRound * s,
                          ),
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1.0 * s,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isDownloadingAll)
                              SizedBox(
                                width: 16 * s,
                                height: 16 * s,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2 * s,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            else
                              Icon(
                                Icons.download,
                                size: 20 * s,
                                color: AppColors.textSecondary,
                              ),
                            SizedBox(width: AppDesignSystem.space8 * s),
                            Text(
                              _isDownloadingAll
                                  ? _translations.isNotEmpty
                                        ? LanguageHelper.tr(
                                            _translations,
                                            'reciters.audio_manager.downloading_all_text',
                                          )
                                        : 'Downloading All'
                                  : _translations.isNotEmpty
                                  ? LanguageHelper.tr(
                                      _translations,
                                      'reciters.audio_manager.download_all_text',
                                    )
                                  : 'Download All',
                              style: TextStyle(
                                fontSize: 16 * s,
                                fontWeight: AppTypography.regular,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: AppDesignSystem.space20 * s),

                  // List of surahs
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(
                            color: AppColors.borderLight,
                            width: 1.0 * s,
                          ),
                        ),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _allSurahs.length,
                        itemBuilder: (context, index) {
                          final surah = _allSurahs[index];
                          final surahId = surah['id'] as int;
                          final surahName = _getSurahDisplayName(surah);
                          final progress = _downloadProgress[surahId] ?? 0.0;
                          final isDownloading = _downloadingIds.contains(
                            surahId,
                          );
                          final isDownloaded =
                              _downloadedStatus[surahId] ?? false;

                          return _buildSurahItem(
                            surahId: surahId,
                            surahName: surahName,
                            progress: progress,
                            isDownloading: isDownloading,
                            isDownloaded: isDownloaded,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    // Cancel any ongoing downloads
    for (final surahId in _downloadingIds) {
      // Downloads will be automatically cancelled by service
    }
    super.dispose();
  }
}



