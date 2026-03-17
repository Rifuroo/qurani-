// lib/screens/main/home/screens/settings/settings_page.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/dropped_connection.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/hidden_verses.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/language.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/listening.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/marking.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/mistake_feedback.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/mushaf_layout.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/recitation.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/reciters_download.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/reminders.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/tafsir_download.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/theme.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/session_start&Stop.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/translation_download.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/data_usage.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
    Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/settings');
    setState(() {
      _translations = trans;
    });
  }
  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showDivider = true,
    Color? iconColor,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space16 * s,
          vertical: AppDesignSystem.space12 * s,
        ),
        decoration: showDivider ? AppComponentStyles.divider() : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: AppDesignSystem.iconMedium * s,
              color: iconColor ?? AppColors.getTextPrimary(context),
            ),
            SizedBox(width: AppDesignSystem.space16 * s),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(
                  context,
                  weight: AppTypography.medium,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: AppDesignSystem.iconSmall * s,
              color: AppColors.getTextDisabled(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final s = AppDesignSystem.getScaleFactor(context);
    return Padding(
      padding: EdgeInsets.only(bottom: AppDesignSystem.space8 * s),
      child: Text(
        title,
        style: AppTypography.overline(
          context,
          color: AppColors.getTextTertiary(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getSurfaceVariant(context),
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty 
            ? LanguageHelper.tr(_translations, 'settings.settings_text')
            : 'Settings',
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: AppPadding.horizontal(context, AppDesignSystem.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppMargin.gapLarge(context),

                // ==================== EXPERIENCES ====================
                _buildSectionHeader(_translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.experiences_text').toUpperCase()
                      : 'EXPERIENCES'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingItem(
                        icon: Icons.mic_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.recitation_text')
                      : 'Recitation',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const RecitationPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.play_arrow_rounded,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.listening_text')
                      : 'Listening',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const ListeningPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                AppMargin.gapLarge(context),

                // ==================== QURAN APPEARANCE ====================
                _buildSectionHeader(_translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.quran_appearance_text').toUpperCase()
                      : 'QURAN APPEARANCE'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingItem(
                        icon: Icons.menu_book_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.mushaf_layout_text')
                      : 'Mushaf Layout',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const MushafLayoutPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.visibility_off_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.hidden_verses_text')
                      : 'Hidden Verses',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const HiddenVersesPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.edit_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.marking_text')
                      : 'Marking',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const MarkingPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                AppMargin.gapLarge(context),

                // ==================== APPEARANCE ====================
                _buildSectionHeader(_translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.appearance_text').toUpperCase()
                      : 'APPEARANCE'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingItem(
                        icon: Icons.language_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.language_text')
                      : 'Language',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const LanguagePage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.brightness_6_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.theme_text')
                      : 'Theme',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const ThemePage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                AppMargin.gapLarge(context),

                // ==================== NOTIFICATIONS ====================
                _buildSectionHeader(_translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.notifications_text').toUpperCase()
                      : 'NOTIFICATIONS'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _buildSettingItem(
                    icon: Icons.notifications_outlined,
                    label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.reminders_text')
                      : 'Reminders',
                    onTap: () {
                      AppHaptics.light();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const RemindersPage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const begin = Offset(-0.03, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;
                                var tween = Tween(
                                  begin: begin,
                                  end: end,
                                ).chain(CurveTween(curve: curve));
                                var offsetAnimation = animation.drive(tween);
                                var fadeAnimation = animation.drive(
                                  Tween(
                                    begin: 0.0,
                                    end: 1.0,
                                  ).chain(CurveTween(curve: curve)),
                                );

                                return FadeTransition(
                                  opacity: fadeAnimation,
                                  child: SlideTransition(
                                    position: offsetAnimation,
                                    child: child,
                                  ),
                                );
                              },
                          transitionDuration: AppDesignSystem.durationNormal,
                        ),
                      );
                    },
                    showDivider: false,
                  ),
                ),

                AppMargin.gapLarge(context),

                // ==================== SOUNDS & HAPTICS ====================
                _buildSectionHeader(_translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.sounds_haptics_text').toUpperCase()
                      : 'SOUNDS & HAPTICS'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingItem(
                        icon: Icons.error_outline,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.mistake_feedback_text')
                      : 'Mistake Feedback',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const MistakeFeedbackPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.mic_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.session_start_stop_text')
                      : 'Session Start & Stop',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const SessionStartStopPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.wifi_off_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.dropped_connection_text')
                      : 'Dropped Connection',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const DroppedConnectionPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                AppMargin.gapLarge(context),

                // ==================== DOWNLOADS ====================
                _buildSectionHeader(_translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.downloads_text').toUpperCase()
                      : 'DOWNLOADS'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingItem(
                        icon: Icons.record_voice_over_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.reciters_text')
                      : 'Reciters',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const RecitersDownloadPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.translate_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.translations_text')
                      : 'Translations',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const TranslationDownloadPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.book_outlined,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.tafsir_text')
                      : 'Tafsir',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const TafsirDownloadPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                AppMargin.gapLarge(context),

                // ==================== PRIVACY ====================
                _buildSectionHeader(_translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.privacy_text').toUpperCase()
                      : 'PRIVACY'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingItem(
                        icon: Icons.lock_outline,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.data_usage_text')
                      : 'Data Usage',
                        onTap: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const DataUsagePage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(0.03, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    var fadeAnimation = animation.drive(
                                      Tween(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).chain(CurveTween(curve: curve)),
                                    );

                                    return FadeTransition(
                                      opacity: fadeAnimation,
                                      child: SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      ),
                                    );
                                  },
                              transitionDuration:
                                  AppDesignSystem.durationNormal,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.delete_outline,
                        label: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.delete_all_audio_data_text')
                      : 'Delete All Audio Data',
                        iconColor: AppColors.getError(context),
                        onTap: () {
                          AppHaptics.medium();
                          _showDeleteAudioDialog();
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                AppMargin.customGap(context, AppDesignSystem.space80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAudioDialog() {
    final s = AppDesignSystem.getScaleFactor(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
        ),
        elevation: AppDesignSystem.elevationHigh,
        child: Container(
          padding: AppPadding.all(context, AppDesignSystem.space24),
          decoration: AppComponentStyles.dialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon & Title
              Row(
                children: [
                  Container(
                    width: 48 * s,
                    height: 48 * s,
                    decoration: BoxDecoration(
                      color: AppColors.getError(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusMedium * s,
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppColors.getError(context),
                      size: AppDesignSystem.iconLarge * s,
                    ),
                  ),
                  AppMargin.gapH(context),
                  Expanded(
                    child: Text(
                      _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.delete_all_audio_data_text')
                      : 'Delete All Audio Data',
                      style: AppTypography.h3(
                        context,
                        weight: AppTypography.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),

              AppMargin.gap(context),

              // Content
              Text(
                _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.delete_all_audio_data_desc')
                      :                 'Are you sure you want to delete all audio recordings? This action cannot be undone and will permanently remove all your recitation history.',
                style: AppTypography.body(
                  context,
                  color: AppColors.getTextSecondary(context),
                ),
              ),

              AppMargin.gapLarge(context),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppTextButton(
                    text: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.cancel_text')
                      : 'Cancel',
                    onPressed: () {
                      AppHaptics.light();
                      Navigator.pop(context);
                    },
                    color: AppColors.getTextTertiary(context),
                  ),
                  AppMargin.gapHSmall(context),
                  AppButton(
                    text: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'settings.delete_text')
                      : 'Delete',
                    backgroundColor: AppColors.getError(context),
                    textColor: AppColors.getTextInverse(context),
                    onPressed: () {
                      AppHaptics.heavy();
                      Navigator.pop(context);
                      // TODO: Implement delete audio data
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppComponentStyles.successSnackBar(
                          message: 'Audio data deleted successfully',
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
