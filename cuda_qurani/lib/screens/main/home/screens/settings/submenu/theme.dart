// lib/screens/main/home/screens/settings/submenu/theme.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:cuda_qurani/providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// ==================== THEME SETTINGS PAGE ====================
/// Halaman untuk memilih tema aplikasi: Auto, Light, Dark

enum CustomThemeMode { auto, light, dark }

class ThemePage extends StatefulWidget {
  const ThemePage({Key? key}) : super(key: key);

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/appearances');
    setState(() {
      _translations = trans;
    });
  }

  void _selectTheme(CustomThemeMode theme) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    // Convert custom enum to Flutter's ThemeMode
    ThemeMode flutterMode;
    switch (theme) {
      case CustomThemeMode.auto:
        flutterMode = ThemeMode.system;
        break;
      case CustomThemeMode.light:
        flutterMode = ThemeMode.light;
        break;
      case CustomThemeMode.dark:
        flutterMode = ThemeMode.dark;
        break;
    }
    
    themeProvider.setThemeMode(flutterMode);
    AppHaptics.selection();
  }
  
  CustomThemeMode _getCurrentThemeMode(ThemeProvider themeProvider) {
    switch (themeProvider.themeMode) {
      case ThemeMode.system:
        return CustomThemeMode.auto;
      case ThemeMode.light:
        return CustomThemeMode.light;
      case ThemeMode.dark:
        return CustomThemeMode.dark;
    }
  }

  Widget _buildThemeOption({
    required String label,
    required CustomThemeMode themeMode,
    required bool isSelected,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => _selectTheme(themeMode),
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
            color: isSelected ? colorScheme.primary : AppColors.getBorderLight(context),
            width: isSelected ? 1.5 * s * 0.9 : 1.0 * s * 0.9,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
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
            ),
            // Radio indicator
            Container(
              width: 20 * s * 0.9,
              height: 20 * s * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : AppColors.getBorderMedium(context),
                  width: isSelected ? 2.0 * s * 0.9 : 1.5 * s * 0.9,
                ),
                color: Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10 * s * 0.9,
                        height: 10 * s * 0.9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = _getCurrentThemeMode(themeProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'theme_page.theme_text')
            : 'Theme',
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
          child: Column(
            children: [
              // Auto (Light/Dark) Option
              _buildThemeOption(
                label: _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'theme_page.auto_text')
                    : 'Auto (Light/Dark)',
                themeMode: CustomThemeMode.auto,
                isSelected: currentMode == CustomThemeMode.auto,
              ),

              SizedBox(height: AppDesignSystem.space16 * s * 0.9),

              // Light Option
              _buildThemeOption(
                label: _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'theme_page.light_text')
                    : 'Light',
                themeMode: CustomThemeMode.light,
                isSelected: currentMode == CustomThemeMode.light,
              ),

              SizedBox(height: AppDesignSystem.space16 * s * 0.9),

              // Dark Option
              _buildThemeOption(
                label: _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'theme_page.dark_text')
                    : 'Dark',
                themeMode: CustomThemeMode.dark,
                isSelected: currentMode == CustomThemeMode.dark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



