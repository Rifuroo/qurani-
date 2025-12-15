// lib/screens/main/home/screens/settings/widgets/mushaf_layout_font.dart
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/stt/data/models.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart';
import 'package:cuda_qurani/models/quran_models.dart';
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
    }
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
        backgroundColor: AppColors.background,
        appBar: SettingsAppBar(
          title: _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'mushaf_type.title')
              : 'Mushaf Type',
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
                // Book Settings Header
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
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
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
                    color: AppColors.textSecondary,
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
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
                        color: AppColors.textPrimary,
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

            // Mushaf Preview
            Container(
              height: screenHeight * 0.38,
              margin: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.space16 * s,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusSmall * s,
                ),
                border: Border.all(
                  color: AppColors.borderLight,
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
                  color: AppColors.textSecondary,
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
                  color: AppColors.textPrimary,
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

/// ✅ REAL DATABASE PREVIEW: Load actual Surah Yasin first page from database
class _OptimizedMushafPreview extends StatefulWidget {
  final MushafLayout layout;
  final int previewPage;

  const _OptimizedMushafPreview({
    required this.layout,
    required this.previewPage,
  });

  @override
  State<_OptimizedMushafPreview> createState() => _OptimizedMushafPreviewState();
}

class _OptimizedMushafPreviewState extends State<_OptimizedMushafPreview> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MushafPageLine>? _pageLines;
  int? _yasinFirstPage;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(_OptimizedMushafPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if layout changed
    if (oldWidget.layout != widget.layout) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _pageLines = null;
      });
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    try {
      // ✅ Get Yasin first page number (Surah 36, Ayah 1)
      final yasinPage = await LocalDatabaseService.getPageNumber(36, 1);
      
      // ✅ Temporarily switch layout for preview loading
      final tempService = QuranService();
      await tempService.initialize();
      await tempService.setMushafLayout(widget.layout);
      
      // ✅ Load page data from database
      final lines = await tempService.getMushafPageLines(yasinPage);
      
      if (mounted) {
        setState(() {
          _yasinFirstPage = yasinPage;
          _pageLines = lines;
          _isLoading = false;
        });
      }
      
      print('✅ Preview loaded: Yasin page $yasinPage (${lines.length} lines) for ${widget.layout.displayName}');
    } catch (e) {
      print('❌ Preview load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load preview';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_errorMessage != null || _pageLines == null) {
      return Center(
        child: Text(
          _errorMessage ?? 'No data',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      );
    }

    // ✅ Render REAL mushaf page from database
    return _MushafPreviewRenderer(
      layout: widget.layout,
      pageLines: _pageLines!,
      pageNumber: _yasinFirstPage!,
    );
  }
}

/// ✅ CRITICAL: Render actual mushaf page data (non-interactive)
class _MushafPreviewRenderer extends StatelessWidget {
  final MushafLayout layout;
  final List<MushafPageLine> pageLines;
  final int pageNumber;

  const _MushafPreviewRenderer({
    required this.layout,
    required this.pageLines,
    required this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final fontFamily = layout.isGlyphBased
        ? 'p$pageNumber'
        : 'IndoPak-Nastaleeq';

    return AbsorbPointer(
      // ✅ Disable all interactions (swipe, tap, etc.)
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.02),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildPreviewLines(
                screenWidth,
                screenHeight,
                fontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPreviewLines(
    double screenWidth,
    double screenHeight,
    String fontFamily,
  ) {
    final widgets = <Widget>[];
    
    for (final line in pageLines) {
      switch (line.lineType) {
        case 'surah_name':
          widgets.add(_buildSurahHeader(line, screenHeight));
          break;
          
        case 'basmallah':
          widgets.add(_buildBasmallah(screenHeight));
          break;
          
        case 'ayah':
          widgets.add(_buildAyahLine(line, screenWidth, fontFamily));
          break;
      }
    }
    
    return widgets;
  }

  Widget _buildSurahHeader(MushafPageLine line, double screenHeight) {
    final surahId = line.surahNumber ?? 1;
    final surahGlyphCode = _formatSurahGlyph(surahId);
    
    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(vertical: screenHeight * 0.008),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'header',
            style: TextStyle(
              fontSize: screenHeight * 0.032,
              fontFamily: 'Quran-Common',
              color: Colors.black87,
            ),
          ),
          Text(
            surahGlyphCode,
            style: TextStyle(
              fontSize: screenHeight * 0.028,
              fontFamily: 'surah-name-v2',
              color: Colors.black,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildBasmallah(double screenHeight) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.006),
      child: Text(
        'ï·½',
        style: TextStyle(
          fontSize: screenHeight * 0.024,
          fontFamily: 'Quran-Common',
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildAyahLine(MushafPageLine line, double screenWidth, String fontFamily) {
    if (line.ayahSegments == null || line.ayahSegments!.isEmpty) {
      return const SizedBox.shrink();
    }

    final spans = <InlineSpan>[];
    
    for (final segment in line.ayahSegments!) {
      for (final word in segment.words) {
        spans.add(
          TextSpan(
            text: word.text,
            style: TextStyle(
              fontSize: layout == MushafLayout.indopak
                  ? screenWidth * 0.042
                  : screenWidth * 0.038,
              fontFamily: fontFamily,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
              height: 1.6,
              letterSpacing: layout.isGlyphBased ? -3 : 0,
            ),
          ),
        );
        
        // Add minimal spacing between words
        spans.add(
          TextSpan(
            text: ' ',
            style: TextStyle(fontSize: screenWidth * 0.01),
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.004),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: RichText(
          textAlign: line.isCentered ? TextAlign.center : TextAlign.justify,
          text: TextSpan(children: spans),
        ),
      ),
    );
  }

  String _formatSurahGlyph(int surahId) {
    if (surahId <= 9) return 'surah00$surahId';
    if (surahId <= 99) return 'surah0$surahId';
    return 'surah$surahId';
  }
}