// lib/screens/main/home/screens/settings/submenu/language.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';
import 'package:cuda_qurani/core/services/language_service.dart';
import 'package:cuda_qurani/providers/reminder_provider.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:cuda_qurani/services/daily_ayah_service.dart';

/// ==================== LANGUAGE SETTINGS PAGE ====================
/// Halaman untuk memilih bahasa aplikasi
/// Data bahasa diambil dari assets/lang/data/language.json

class LanguagePage extends StatefulWidget {
  const LanguagePage({Key? key}) : super(key: key);

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    // Load available languages saat page dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LanguageProvider>(context, listen: false);
      if (provider.availableLanguages.isEmpty) {
        provider.initialize();
      }
    });
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('settings/appearances');
    setState(() {
      _translations = trans;
    });
  }

  Future<void> _selectLanguage(LanguageModel language) async {
    final provider = Provider.of<LanguageProvider>(context, listen: false);

    // Skip jika sudah dipilih
    if (provider.currentLanguageCode == language.code) {
      return;
    }

    AppHaptics.selection();

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(
              AppDesignSystem.space24 * AppDesignSystem.getScaleFactor(context),
            ),
            decoration: BoxDecoration(
          color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(
                AppDesignSystem.radiusMedium *
                    AppDesignSystem.getScaleFactor(context),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                SizedBox(
                  height:
                      AppDesignSystem.space16 *
                      AppDesignSystem.getScaleFactor(context),
                ),
                Text(
                  _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'language_page.changing_text',
                        )
                      : 'Changing language...',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Change language
    final success = await provider.changeLanguage(language.code);

    if (!mounted) return;

    // Close loading dialog
    Navigator.pop(context);

    if (success) {
      // Sync FCM token with new language preference
      final reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
      await reminderProvider.syncLanguagePreference(language.code);
      
      // Refresh widget to reflect new language
      await DailyAyahService.refreshDailyAyah();

      // Restart app untuk apply bahasa baru
      await provider.restartApp(context);
    }
  }

  Widget _buildLanguageOption({
    required LanguageModel language,
    required bool isSelected,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return InkWell(
      onTap: () => _selectLanguage(language),
      borderRadius: BorderRadius.circular(
        AppDesignSystem.radiusMedium * s * 0.9,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space16 * s * 0.9,
          vertical: AppDesignSystem.space16 * s * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(
            AppDesignSystem.radiusMedium * s * 0.9,
          ),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.getBorderLight(context),
            width: isSelected ? 1.5 * s * 0.9 : 1.0 * s * 0.9,
          ),
        ),
        child: Row(
          children: [
            // Flag emoji
            // if (language.flag.isNotEmpty) ...[
            //   Text(language.flag, style: TextStyle(fontSize: 28 * s * 0.9)),
            //   SizedBox(width: AppDesignSystem.space12 * s * 0.9),
            // ],

            // Language name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Native name (e.g., "Bahasa Indonesia")
                  Text(
                    language.nativeName,
                    style: TextStyle(
                      fontSize: 16 * s * 0.9,
                      fontWeight: isSelected
                          ? AppTypography.semiBold
                          : AppTypography.regular,
                      color: isSelected
                          ? AppColors.getTextPrimary(context)
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
                  // English name (e.g., "Indonesian") - jika berbeda
                  if (language.name != language.nativeName) ...[
                    SizedBox(height: 2 * s * 0.9),
                    Text(
                      language.name,
                      style: TextStyle(
                        fontSize: 13 * s * 0.9,
                        fontWeight: AppTypography.regular,
                        color: AppColors.getTextTertiary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Radio indicator
            Container(
              width: 22 * s * 0.9,
              height: 22 * s * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.getBorderMedium(context),
                  width: isSelected ? 2.0 * s * 0.9 : 1.5 * s * 0.9,
                ),
                color: Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 11 * s * 0.9,
                        height: 11 * s * 0.9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'language_page.language_text')
            : 'Language',
      ),
      body: SafeArea(
        child: Consumer<LanguageProvider>(
          builder: (context, provider, child) {
            // Show loading state
            if (provider.isLoading && provider.availableLanguages.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: AppDesignSystem.space16 * s),
                    Text(
                      'Loading languages...',
                      style: TextStyle(
                        fontSize: 14 * s,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show error state
            if (provider.error != null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(AppDesignSystem.space20 * s),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48 * s,
                        color: AppColors.getError(context),
                      ),
                      SizedBox(height: AppDesignSystem.space16 * s),
                      Text(
                        'Failed to load languages',
                        style: TextStyle(
                          fontSize: 16 * s,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      SizedBox(height: AppDesignSystem.space8 * s),
                      Text(
                        provider.error!,
                        style: TextStyle(
                          fontSize: 14 * s,
                          color: AppColors.getTextSecondary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppDesignSystem.space24 * s),
                      ElevatedButton.icon(
                        onPressed: () => provider.initialize(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getPrimary(context),
                          foregroundColor: AppColors.getTextInverse(context),
                          padding: EdgeInsets.symmetric(
                            horizontal: AppDesignSystem.space24 * s,
                            vertical: AppDesignSystem.space12 * s,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMedium * s,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Get languages and current selection
            final languages = provider.availableLanguages;
            final currentCode = provider.currentLanguageCode;

            // Show empty state
            if (languages.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.language,
                      size: 48 * s,
                      color: AppColors.getTextTertiary(context),
                    ),
                    SizedBox(height: AppDesignSystem.space16 * s),
                    Text(
                      'No languages available',
                      style: TextStyle(
                        fontSize: 16 * s,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show languages list
            return ListView.separated(
              padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
              itemCount: languages.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: AppDesignSystem.space12 * s * 0.9),
              itemBuilder: (context, index) {
                final language = languages[index];
                return _buildLanguageOption(
                  language: language,
                  isSelected: currentCode == language.code,
                );
              },
            );
          },
        ),
      ),
    );
  }
}



