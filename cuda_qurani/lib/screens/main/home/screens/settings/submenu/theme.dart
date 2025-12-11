// lib/screens/main/home/screens/settings/submenu/theme.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== THEME SETTINGS PAGE ====================
/// Halaman untuk memilih tema aplikasi: Auto, Light, Dark

enum ThemeMode { auto, light, dark }

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

  // Default selected theme (dummy state)
  ThemeMode _selectedTheme = ThemeMode.light;

  void _selectTheme(ThemeMode theme) {
    setState(() {
      _selectedTheme = theme;
    });
    AppHaptics.selection();

    // TODO: Implement theme change logic
    // Example: Provider.of<ThemeProvider>(context, listen: false).setTheme(theme);
  }

  Widget _buildThemeOption({
    required String label,
    required ThemeMode themeMode,
    required bool isSelected,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(
            AppDesignSystem.radiusMedium * s * 0.9,
          ),
          border: Border.all(
            color: isSelected ? Colors.black : AppColors.borderLight,
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
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
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
                  color: isSelected ? Colors.black : AppColors.borderMedium,
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
                          color: Colors.black,
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
      backgroundColor: AppColors.background,
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
                themeMode: ThemeMode.auto,
                isSelected: _selectedTheme == ThemeMode.auto,
              ),

              SizedBox(height: AppDesignSystem.space16 * s * 0.9),

              // Light Option
              _buildThemeOption(
                label: _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'theme_page.light_text')
                    : 'Light',
                themeMode: ThemeMode.light,
                isSelected: _selectedTheme == ThemeMode.light,
              ),

              SizedBox(height: AppDesignSystem.space16 * s * 0.9),

              // Dark Option
              _buildThemeOption(
                label: _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'theme_page.dark_text')
                    : 'Dark',
                themeMode: ThemeMode.dark,
                isSelected: _selectedTheme == ThemeMode.dark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



