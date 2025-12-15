// lib/screens/main/home/screens/settings/submenu/mushaf_layout.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/mushaf_layout_font.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/mushaf_view.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/list_view.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart';
import 'package:provider/provider.dart';

/// ==================== MUSHAF LAYOUT PAGE ====================
/// Halaman untuk memilih layout tampilan Quran (Book vs Translation/Transliteration)

class MushafLayoutPage extends StatefulWidget {
  const MushafLayoutPage({Key? key}) : super(key: key);

  @override
  State<MushafLayoutPage> createState() => _MushafLayoutPageState();
}

class _MushafLayoutPageState extends State<MushafLayoutPage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/quran_appearance');
    setState(() {
      _translations = trans;
    });
  }

  // Selected layout mode
  String _selectedLayout = 'Book'; // 'Book' or 'Translation/Transliteration'

  void _selectLayout(String layout) {
    setState(() {
      _selectedLayout = layout;
    });
    AppHaptics.selection();
  }

  void _navigateToMushafSettings() {
    AppHaptics.selection();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MushafLayoutFontPage()),
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
                'mushaf_layout.mushaf_layout_text',
              )
            : 'Mushaf Layout',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header
                Text(
                  _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'mushaf_layout.select_text',
                        )
                      : 'Select Reading Layout',
                  style: TextStyle(
                    fontSize: 14 * s * 0.9,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                  ),
                ),

                SizedBox(height: AppDesignSystem.space16 * s * 0.9),

                // Layout Options Container
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusMedium * s * 0.9,
                    ),
                    border: Border.all(
                      color: AppColors.borderLight,
                      width: 1.0 * s * 0.9,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Book Option
                      _buildLayoutOption(
                        context: context,
                        icon: Icons.book_outlined,
                        title: _translations.isNotEmpty
                            ? LanguageHelper.tr(
                                _translations,
                                'mushaf_layout.book_text',
                              )
                            : 'Book',
                        subtitle: _translations.isNotEmpty
                            ? LanguageHelper.tr(
                                _translations,
                                'mushaf_layout.madani_text',
                              )
                            : 'Madani Mushaf (1405)',
                        isSelected: _selectedLayout == 'Book',
                        onTap: () => _selectLayout('Book'),
                        isFirst: true,
                        isLast: false,
                      ),

                      // Divider
                      Divider(
                        height: 1,
                        thickness: 1 * s * 0.9,
                        color: AppColors.borderLight,
                      ),

                      // Translation/Transliteration Option
                      _buildLayoutOption(
                        context: context,
                        icon: Icons.translate_outlined,
                        title: _translations.isNotEmpty
                            ? LanguageHelper.tr(
                                _translations,
                                'mushaf_layout.translation_text',
                              )
                            : 'Translation / Transliteration',
                        subtitle: 'Dr. Mustafa Khattab, The Clear Quran',
                        isSelected:
                            _selectedLayout == 'Translation/Transliteration',
                        onTap: () =>
                            _selectLayout('Translation/Transliteration'),
                        isFirst: false,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppDesignSystem.space24 * s * 0.9),

                // Mushaf Layout and Font Navigation
                InkWell(
                  onTap: _navigateToMushafSettings,
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusMedium * s * 0.9,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.space16 * s * 0.9,
                      vertical: AppDesignSystem.space16 * s * 0.9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusMedium * s * 0.9,
                      ),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1.0 * s * 0.9,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _translations.isNotEmpty
                                    ? LanguageHelper.tr(
                                        _translations,
                                        'mushaf_layout.mushaf_layout_and_font_text',
                                      ).toUpperCase()
                                    : 'MUSHAF LAYOUT AND FONT',
                                style: TextStyle(
                                  fontSize: 11 * s * 0.9,
                                  fontWeight: AppTypography.semiBold,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 4 * s * 0.9),
                              Text(
                                _translations.isNotEmpty
                                    ? LanguageHelper.tr(
                                        _translations,
                                        'mushaf_layout.mushaf_layout_and_font_desc',
                                      )
                                    : 'Choose the different Mushaf you wish to use.',
                                style: TextStyle(
                                  fontSize: 14 * s * 0.9,
                                  fontWeight: AppTypography.regular,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 24 * s * 0.9,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: AppDesignSystem.space24 * s * 0.9),

                // Preview Section
                Text(
                  _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'mushaf_layout.preview_text',
                        )
                      : 'Preview',
                  style: TextStyle(
                    fontSize: 14 * s * 0.9,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                  ),
                ),

                SizedBox(height: AppDesignSystem.space16 * s * 0.9),

                // Preview Container with actual widget preview
                _buildPreviewSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isFirst,
    required bool isLast,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.only(
        topLeft: isFirst
            ? Radius.circular(AppDesignSystem.radiusMedium * s * 0.9)
            : Radius.zero,
        topRight: isFirst
            ? Radius.circular(AppDesignSystem.radiusMedium * s * 0.9)
            : Radius.zero,
        bottomLeft: isLast
            ? Radius.circular(AppDesignSystem.radiusMedium * s * 0.9)
            : Radius.zero,
        bottomRight: isLast
            ? Radius.circular(AppDesignSystem.radiusMedium * s * 0.9)
            : Radius.zero,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space16 * s * 0.9,
          vertical: AppDesignSystem.space16 * s * 0.9,
        ),
        child: Row(
          children: [
            // Icon
            Icon(icon, size: 24 * s * 0.9, color: AppColors.textPrimary),

            SizedBox(width: AppDesignSystem.space12 * s * 0.9),

            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16 * s * 0.9,
                      fontWeight: AppTypography.regular,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2 * s * 0.9),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13 * s * 0.9,
                      fontWeight: AppTypography.regular,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Radio Button
            Container(
              width: 20 * s * 0.9,
              height: 20 * s * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.borderMedium,
                  width: isSelected ? 6 * s * 0.9 : 2 * s * 0.9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.45, // Fixed preview height
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(
          AppDesignSystem.radiusMedium * s * 0.9,
        ),
        border: Border.all(color: AppColors.borderLight, width: 1.0 * s * 0.9),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppDesignSystem.radiusMedium * s * 0.9,
        ),
        child: _selectedLayout == 'Book'
            ? _buildMushafPreview(context)
            : _buildListPreview(context),
      ),
    );
  }

  Widget _buildMushafPreview(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Create a minimal SttController instance just for preview
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final controller = SttController(pageId: 440); // Preview page 1
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
              // Mushaf content with EXPLICIT size constraints
              SizedBox(
                width: screenWidth,
                height: screenHeight * 0.45,
                child: IgnorePointer(
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: screenWidth,
                      maxHeight: screenHeight * 0.8,
                      child: Transform.scale(
                        scale: 0.7,
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

  Widget _buildListPreview(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Create a minimal SttController instance just for preview
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final controller = SttController(pageId: 440); // Preview page 1
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
              // List view content with EXPLICIT size constraints
              SizedBox(
                width: screenWidth,
                height: screenHeight * 0.45,
                child: IgnorePointer(
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: screenWidth,
                      maxHeight: screenHeight * 0.8,
                      child: Transform.scale(
                        scale: 0.7,
                        child: const QuranListView(),
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



