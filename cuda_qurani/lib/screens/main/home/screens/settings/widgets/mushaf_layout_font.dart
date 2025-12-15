// lib/screens/main/home/screens/settings/widgets/mushaf_layout_font.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/mushaf_view.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart';
import 'package:provider/provider.dart';

/// ==================== MUSHAF LAYOUT & FONT PAGE ====================
/// Halaman untuk memilih tipe Mushaf (Indopak, Madani, dll)

class MushafLayoutFontPage extends StatefulWidget {
  const MushafLayoutFontPage({Key? key}) : super(key: key);

  @override
  State<MushafLayoutFontPage> createState() => _MushafLayoutFontPageState();
}

class _MushafLayoutFontPageState extends State<MushafLayoutFontPage> {
  Map<String, dynamic> _translations = {};
  String _selectedMushafType = 'Madani Mushaf (1405)'; // Default selected
  bool _showTajweedColors = false;

  // Mushaf types data
  final List<Map<String, dynamic>> _mushafTypes = [
    {
      'id': 'indopak',
      'title': 'Indopak Mushaf (Naskh)',
      'subtitle': '',
      'description':
          'Designed specifically for non-Arabic speakers, this layout is widely used in South Asia for its readability.',
      'lines': '15 Lines',
      'pages': '610 pages',
      'previewPage': 440,
    },
    {
      'id': 'madani_1405',
      'title': 'Madani Mushaf (1405)',
      'subtitle': '',
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
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('settings/mushaf_layout_font');
    setState(() {
      _translations = trans;
    });
  }

  void _selectMushafType(String title) {
    setState(() {
      _selectedMushafType = title;
    });
    AppHaptics.selection();
  }

  Map<String, dynamic> get _selectedMushaf {
    return _mushafTypes.firstWhere(
      (m) => m['title'] == _selectedMushafType,
      orElse: () => _mushafTypes[1], // Default to Madani 1405
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

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
                        color: AppColors.textPrimary,
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
                      final isSelected = _selectedMushafType == mushaf['title'];

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

                SizedBox(height: AppDesignSystem.space24 * s),

                // Show Tajweed Colors Toggle
                // Container(
                //   padding: EdgeInsets.symmetric(
                //     horizontal: AppDesignSystem.space16 * s,
                //     vertical: AppDesignSystem.space12 * s,
                //   ),
                //   decoration: BoxDecoration(
                //     color: AppColors.surface,
                //     borderRadius: BorderRadius.circular(
                //       AppDesignSystem.radiusMedium * s,
                //     ),
                //     border: Border.all(
                //       color: AppColors.borderLight,
                //       width: 1.0 * s,
                //     ),
                //   ),
                //   child: Row(
                //     children: [
                //       // Tajweed Icon (Arabic letter)
                //       Text(
                //         'ﺝ',
                //         style: TextStyle(
                //           fontSize: 22 * s,
                //           color: AppColors.textPrimary,
                //           fontWeight: AppTypography.bold,
                //         ),
                //       ),

                //       SizedBox(width: AppDesignSystem.space12 * s),

                //       // Title
                //       Expanded(
                //         child: Text(
                //           _translations.isNotEmpty
                //               ? LanguageHelper.tr(
                //                   _translations,
                //                   'mushaf_type.show_tajweed_colors',
                //                 )
                //               : 'Show Tajweed Colors',
                //           style: TextStyle(
                //             fontSize: 16 * s,
                //             fontWeight: AppTypography.regular,
                //             color: AppColors.textPrimary,
                //           ),
                //         ),
                //       ),

                //       // Info Icon
                //       Container(
                //         width: 18 * s,
                //         height: 18 * s,
                //         margin: EdgeInsets.only(
                //           right: AppDesignSystem.space12 * s,
                //         ),
                //         decoration: BoxDecoration(
                //           shape: BoxShape.circle,
                //           color: AppColors.borderMedium,
                //         ),
                //         child: Center(
                //           child: Text(
                //             'i',
                //             style: TextStyle(
                //               fontSize: 12 * s,
                //               fontWeight: AppTypography.bold,
                //               color: Colors.white,
                //             ),
                //           ),
                //         ),
                //       ),

                //       // Toggle Switch
                //       Switch(
                //         value: _showTajweedColors,
                //         onChanged: (value) {
                //           setState(() {
                //             _showTajweedColors = value;
                //           });
                //           AppHaptics.selection();
                //         },
                //         activeColor: AppColors.primary,
                //         inactiveThumbColor: Colors.white,
                //         inactiveTrackColor: AppColors.borderMedium,
                //       ),
                //     ],
                //   ),
                // ),

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

    return GestureDetector(
      onTap: () => _selectMushafType(mushaf['title']),
      child: Container(
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
                      mushaf['subtitle'].isEmpty
                          ? mushaf['title']
                          : mushaf['title'],
                      style: TextStyle(
                        fontSize: 18 * s,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // Checkmark
                  if (isSelected)
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
            if (mushaf['subtitle'].isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space16 * s,
                ),
                child: Text(
                  mushaf['subtitle'],
                  style: TextStyle(
                    fontSize: 16 * s,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

            SizedBox(height: AppDesignSystem.space12 * s),

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
                child: _buildMushafPreview(context, mushaf['previewPage']),
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

  Widget _buildMushafPreview(BuildContext context, int previewPage) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final controller = SttController(pageId: previewPage);
            controller.initializeApp();
            return controller;
          },
        ),
        Provider(create: (_) => QuranService()),
      ],
      child: Consumer<SttController>(
        builder: (context, controller, _) {
          if (controller.isLoading) {
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            );
          }

          return Stack(
            children: [
              // Mushaf content
              SizedBox(
                width: screenWidth * 0.85,
                height: screenHeight * 0.38,
                child: IgnorePointer(
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: screenWidth,
                      maxHeight: screenHeight * 0.6,
                      child: Transform.scale(
                        scale: 0.55,
                        child: const MushafDisplay(),
                      ),
                    ),
                  ),
                ),
              ),

              // Overlay to prevent interaction
              Positioned.fill(child: Container(color: Colors.transparent)),
            ],
          );
        },
      ),
    );
  }
}
