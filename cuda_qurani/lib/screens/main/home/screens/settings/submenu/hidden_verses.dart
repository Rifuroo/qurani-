// lib/screens/main/home/screens/settings/submenu/hidden_verses.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== HIDDEN VERSES SETTINGS PAGE ====================
/// Halaman untuk mengatur pengaturan hidden verses/ayah adjustments

class HiddenVersesPage extends StatefulWidget {
  const HiddenVersesPage({Key? key}) : super(key: key);

  @override
  State<HiddenVersesPage> createState() => _HiddenVersesPageState();
}

class _HiddenVersesPageState extends State<HiddenVersesPage> {
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

  // Default states untuk semua toggle (dummy state)
  bool _hideVerses = false;
  bool _hideVerseMarkers = false;

  void _toggleHideVerses(bool value) {
    setState(() {
      _hideVerses = value;
    });
    AppHaptics.selection();

    // TODO: Implement toggle logic
  }

  void _toggleHideVerseMarkers(bool value) {
    setState(() {
      _hideVerseMarkers = value;
    });
    AppHaptics.selection();

    // TODO: Implement toggle logic
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(
                _translations,
                'hidden_verses.hidden_verses_text',
              )
            : 'Hidden Verses',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ayah Adjustments Section
                Text(
                  _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'hidden_verses.ayah_adjustments_text',
                        )
                      : 'Ayah Adjustments',
                  style: TextStyle(
                    fontSize: 14 * s * 0.9,
                    fontWeight: AppTypography.medium,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),

                SizedBox(height: AppDesignSystem.space12 * s * 0.9),

                // Ayah Adjustments Container
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusMedium * s * 0.9,
                    ),
                    border: Border.all(
                      color: AppColors.getBorderLight(context),
                      width: 1.0 * s * 0.9,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Hide Verses
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDesignSystem.space16 * s * 0.9,
                          vertical: AppDesignSystem.space16 * s * 0.4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              size: 20 * s * 0.9,
                              color: AppColors.getTextPrimary(context),
                            ),
                            SizedBox(width: AppDesignSystem.space12 * s * 0.9),
                            Expanded(
                              child: Text(
                                _translations.isNotEmpty
                                    ? LanguageHelper.tr(
                                        _translations,
                                        'hidden_verses.hide_verses_text',
                                      )
                                    : 'Hide Verses',
                                style: TextStyle(
                                  fontSize: 16 * s * 0.9,
                                  fontWeight: AppTypography.regular,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                            ),
                            Switch(
                              value: _hideVerses,
                              onChanged: _toggleHideVerses,
                              activeTrackColor: AppColors.getPrimary(context).withValues(alpha: 0.5),
                              activeThumbColor: Colors.white,
                              inactiveThumbColor: AppColors.getBorderMedium(context),
                              inactiveTrackColor: AppColors.getBorderLight(context),
                            ),
                          ],
                        ),
                      ),

                      // Divider
                      Divider(
                        height: 1,
                        thickness: 1 * s * 0.9,
                        color: AppColors.getBorderLight(context),
                      ),

                      // Hide verse markers
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDesignSystem.space16 * s * 0.9,
                          vertical: AppDesignSystem.space16 * s * 0.4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.hide_source,
                              size: 20 * s * 0.9,
                              color: AppColors.getTextPrimary(context),
                            ),
                            SizedBox(width: AppDesignSystem.space12 * s * 0.9),
                            Expanded(
                              child: Text(
                                _translations.isNotEmpty
                                    ? LanguageHelper.tr(
                                        _translations,
                                        'hidden_verses.hide_verse_markers_text',
                                      )
                                    : 'Hide verse markers',
                                style: TextStyle(
                                  fontSize: 16 * s * 0.9,
                                  fontWeight: AppTypography.regular,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                            ),
                            Switch(
                              value: _hideVerseMarkers,
                              onChanged: _toggleHideVerseMarkers,
                              activeTrackColor: AppColors.getPrimary(context).withValues(alpha: 0.5),
                              activeThumbColor: Colors.white,
                              inactiveThumbColor: AppColors.getBorderMedium(context),
                              inactiveTrackColor: AppColors.getBorderLight(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppDesignSystem.space16 * s * 0.9),

                // Description text
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.space4 * s * 0.9,
                  ),
                  child: Text(
                    _translations.isNotEmpty
                        ? LanguageHelper.tr(
                            _translations,
                            'hidden_verses.hidden_verses_desc',
                          )
                        : 'Hide the words that you haven\'t recited yet, to practice your memorization.',
                    style: TextStyle(
                      fontSize: 14 * s * 0.9,
                      fontWeight: AppTypography.regular,
                      color: AppColors.getTextSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
