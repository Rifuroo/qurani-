// lib/screens/main/home/screens/settings/widgets/mushaf_layout_font.dart
import 'dart:io';

import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/stt/database/db_helper.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:path/path.dart' as path_helper;
import 'package:sqflite/sqflite.dart';
import 'package:cuda_qurani/core/services/language_service.dart';

class MushafLayoutFontPage extends StatefulWidget {
  const MushafLayoutFontPage({Key? key}) : super(key: key);

  @override
  State<MushafLayoutFontPage> createState() => _MushafLayoutFontPageState();
}

class _MushafLayoutFontPageState extends State<MushafLayoutFontPage> {
  Map<String, dynamic> _translations = {};
  MushafLayout _selectedLayout = MushafLayout.qpc; // Default
  bool _isLoading = true;
  bool _isSaving = false;

  // ✅ Service instances
  final _settingsService = MushafSettingsService();
  final _metadataCache = MetadataCacheService();

  // Mushaf types data with preview pages
  final List<Map<String, dynamic>> _mushafTypes = [
    {
      'layout': MushafLayout.indopak,
      'title': 'Indopak Mushaf (Naskh)',
      'description':
          'Designed specifically for non-Arabic speakers, this layout is widely used in South Asia for its readability.',
      'lines': '15 Lines',
      'pages': '610 pages',
      'previewPage': 440,
    },
    {
      'layout': MushafLayout.qpc,
      'title': 'Madani Mushaf (1405)',
      'description':
          'The original layout, widely used in many parts of the world. This edition maintains the classic ayah placements.',
      'lines': '15 Lines',
      'pages': '604 pages',
      'previewPage': 440,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadTranslations();
    await _loadCurrentLayout();
  }

  Future<void> _loadTranslations() async {
    try {
      // ✅ FIX: Use LanguageService directly (no context needed in initState)
      final languageService = LanguageService();
      final trans = await languageService.loadTranslation(
        'settings/mushaf_layout_font',
      );
      if (mounted) {
        setState(() {
          _translations = trans;
        });
      }
    } catch (e) {
      print('⚠️ Failed to load translations: $e');
      // Continue with empty translations
    }
  }

  Future<void> _loadCurrentLayout() async {
    try {
      final currentLayout = await _settingsService.getMushafLayout();
      if (mounted) {
        setState(() {
          _selectedLayout = currentLayout;
          _isLoading = false;
        });
      }
      print('✅ Loaded current layout: ${currentLayout.displayName}');
    } catch (e) {
      print('❌ Failed to load layout: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveLayout(MushafLayout newLayout) async {
    if (_isSaving || newLayout == _selectedLayout) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // ✅ STEP 1: Show loading dialog FIRST (user feedback)
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AbsorbPointer(
            absorbing: true,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Switching layout...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // ✅ STEP 2: Wait for UI to render loading dialog
      await Future.delayed(const Duration(milliseconds: 100));

      // ✅ STEP 3: Close ALL databases FIRST (prevent lock)
      print('🔒 Closing all databases before layout switch...');
      await DBHelper.closeAllDatabases();
      await LocalDatabaseService.closePageDatabase();
      print('✅ All databases closed');

      // ✅ STEP 4: Wait for file system to release locks
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ STEP 5: Delete old database files
      print('🗑️ Deleting old layout database files...');
      try {
        final databasesPath = await getDatabasesPath();
        final qpcPath = path_helper.join(databasesPath, 'qpc-v1-15-lines.db');
        final indopakPath = path_helper.join(
          databasesPath,
          'qudratullah-indopak-15-lines.db',
        );

        if (await File(qpcPath).exists()) {
          await File(qpcPath).delete();
          print('   Deleted: qpc-v1-15-lines.db');
        }

        if (await File(indopakPath).exists()) {
          await File(indopakPath).delete();
          print('   Deleted: qudratullah-indopak-15-lines.db');
        }
      } catch (e) {
        print('⚠️ Error deleting databases: $e');
        // Continue anyway
      }

      // ✅ STEP 6: Save to SharedPreferences
      await _settingsService.setMushafLayout(newLayout);

      // ✅ STEP 7: Rebuild metadata cache for new layout (ONLY ONCE HERE)
      print('🔄 Rebuilding metadata cache for ${newLayout.displayName}...');
      await _metadataCache.rebuildForLayout(newLayout);

      // ✅ STEP 8: Update UI state
      if (mounted) {
        setState(() {
          _selectedLayout = newLayout;
          _isSaving = false;
        });
      }

      // ✅ STEP 9: Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      print('✅ Layout saved: ${newLayout.displayName}');
    } catch (e) {
      print('❌ Failed to save layout: $e');

      // Close loading dialog if open
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might not be open
        }
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change layout: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: SettingsAppBar(
          title: _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'mushaf_type.title')
              : 'Mushaf Type',
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'mushaf_type.title')
            : 'Mushaf Type',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDesignSystem.space20 * s,
              vertical: AppDesignSystem.space16 * s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Settings Header with Info Icon
                Row(
                  children: [
                    Text(
                      _translations.isNotEmpty
                          ? LanguageHelper.tr(
                              _translations,
                              'mushaf_type.book_settings',
                            ).toUpperCase()
                          : 'BOOK SETTINGS',
                      style: TextStyle(
                        fontSize: 13 * s,
                        fontWeight: AppTypography.bold,
                        color: AppColors.getTextPrimary(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppDesignSystem.space12 * s),

                // Description
                Text(
                  _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'mushaf_type.description',
                        )
                      : 'Please select the Mushaf that best matches your recitation and memorization preferences.',
                  style: TextStyle(
                    fontSize: 14 * s,
                    fontWeight: AppTypography.regular,
                    color: AppColors.getTextSecondary(context),
                    height: 1.4,
                  ),
                ),

                SizedBox(height: AppDesignSystem.space24 * s),

                // Horizontal Scrollable Mushaf Cards
                SizedBox(
                  height: screenHeight * 0.65,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mushafTypes.length,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.space4 * s,
                    ),
                    itemBuilder: (context, index) {
                      final mushaf = _mushafTypes[index];
                      final layout = mushaf['layout'] as MushafLayout;
                      final isSelected = _selectedLayout == layout;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: AppDesignSystem.space16 * s,
                        ),
                        child: _buildMushafCard(
                          context: context,
                          mushaf: mushaf,
                          isSelected: isSelected,
                          screenHeight: screenHeight,
                          screenWidth: screenWidth,
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: AppDesignSystem.space32 * s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMushafCard({
    required BuildContext context,
    required Map<String, dynamic> mushaf,
    required bool isSelected,
    required double screenHeight,
    required double screenWidth,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    final cardWidth = screenWidth * 0.85;
    final layout = mushaf['layout'] as MushafLayout;

    return GestureDetector(
      onTap: _isSaving ? null : () => _saveLayout(layout),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cardWidth,
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.getBorderLight(context),
            width: isSelected ? 2.5 * s : 1.0 * s,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and checkmark
            Padding(
              padding: EdgeInsets.all(AppDesignSystem.space16 * s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Expanded(
                    child: Text(
                      mushaf['title'],
                      style: TextStyle(
                        fontSize: 18 * s,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),

                  // Checkmark or Loading
                  if (_isSaving && isSelected)
                    SizedBox(
                      width: 24 * s,
                      height: 24 * s,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  else if (isSelected)
                    Container(
                      width: 28 * s,
                      height: 28 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 18 * s,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),

            // Subtitle if exists
            if (mushaf.containsKey('subtitle') &&
                mushaf['subtitle'] != null &&
                mushaf['subtitle'].toString().isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space16 * s,
                ),
                child: Text(
                  mushaf['subtitle'],
                  style: TextStyle(
                    fontSize: 16 * s,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),

            SizedBox(height: AppDesignSystem.space12 * s),

            // Mushaf Preview
            Container(
              height: screenHeight * 0.38, // ✅ Already optimal
              margin: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.space16 * s,
              ),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceContainerLowest(context),
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusSmall * s,
                ),
                border: Border.all(
                  color: AppColors.getBorderLight(context),
                  width: 1.0 * s,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusSmall * s,
                ),
                child: _OptimizedMushafPreview(
                  layout: layout,
                  previewPage: mushaf['previewPage'],
                ),
              ),
            ),

            SizedBox(height: AppDesignSystem.space16 * s),

            // Description
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.space16 * s,
              ),
              child: Text(
                mushaf['description'],
                style: TextStyle(
                  fontSize: 13 * s,
                  fontWeight: AppTypography.regular,
                  color: AppColors.getTextSecondary(context),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            SizedBox(height: AppDesignSystem.space12 * s),

            // Lines and Pages info
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.space16 * s,
              ),
              child: Text(
                '${mushaf['lines']} / ${mushaf['pages']}',
                style: TextStyle(
                  fontSize: 14 * s,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),

            SizedBox(height: AppDesignSystem.space16 * s),
          ],
        ),
      ),
    );
  }
}

/// ✅ OPTIMIZED: Use pre-rendered AssetImage for instant preview
class _OptimizedMushafPreview extends StatelessWidget {
  final MushafLayout layout;
  final int previewPage;

  const _OptimizedMushafPreview({
    required this.layout,
    required this.previewPage,
  });

  String _getImagePath(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (layout) {
      case MushafLayout.indopak:
        return isDark
            ? 'assets/images/indopak_preview_dark.png'
            : 'assets/images/indopak_preview.png';
      case MushafLayout.qpc:
        return isDark
            ? 'assets/images/qpc_preview_dark.png'
            : 'assets/images/qpc_preview.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF1E1E1E)
          : Colors.white,
      child: Image.asset(
        _getImagePath(context),
        fit: BoxFit.contain, // Maintain aspect ratio
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 8),
                Text(
                  'Preview not available',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
