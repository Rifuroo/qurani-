// lib/screens/main/home/screens/settings/widgets/mushaf_layout_font.dart
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

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
    final trans = await context.loadTranslations('settings/mushaf_layout_font');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
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
      // 1. Save to SharedPreferences
      await _settingsService.setMushafLayout(newLayout);

      // 2. Rebuild metadata cache for new layout
      print('🔄 Rebuilding metadata cache for ${newLayout.displayName}...');
      await _metadataCache.rebuildForLayout(newLayout);

      // 3. Update UI state
      if (mounted) {
        setState(() {
          _selectedLayout = newLayout;
          _isSaving = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Layout changed to ${newLayout.displayName}',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('✅ Layout saved: ${newLayout.displayName}');
    } catch (e) {
      print('❌ Failed to save layout: $e');
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
