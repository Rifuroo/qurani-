// lib/screens/main/home/screens/settings/submenu/data_usage.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== DATA USAGE SETTINGS PAGE ====================
/// Halaman untuk mengatur penggunaan data aplikasi

class DataUsagePage extends StatefulWidget {
  const DataUsagePage({Key? key}) : super(key: key);

  @override
  State<DataUsagePage> createState() => _DataUsagePageState();
}

class _DataUsagePageState extends State<DataUsagePage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/privacy');
    setState(() {
      _translations = trans;
    });
  }

  // Default state untuk audio data dan AI training (dummy state)
  bool _saveAudioDataEnabled = true;
  bool _allowAITrainingEnabled = true;

  void _toggleSaveAudioData(bool value) {
    setState(() {
      _saveAudioDataEnabled = value;
    });
    AppHaptics.selection();

    // TODO: Implement save audio data toggle logic
    // Example: Save to SharedPreferences or update via Provider
  }

  void _toggleAITraining(bool value) {
    setState(() {
      _allowAITrainingEnabled = value;
    });
    AppHaptics.selection();

    // TODO: Implement AI training toggle logic
    // Example: Save to SharedPreferences or update via Provider
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required Function(bool) onChanged,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s * 0.9,
        vertical: AppDesignSystem.space16 * s * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(
          AppDesignSystem.radiusMedium * s * 0.9,
        ),
        border: Border.all(color: AppColors.getBorderLight(context), width: 1.0 * s * 0.9),
      ),
      child: Row(
        children: [
          // Icon
          Icon(icon, size: 24 * s * 0.9, color: AppColors.getTextPrimary(context)),
          SizedBox(width: AppDesignSystem.space12 * s * 0.9),
          // Label
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16 * s * 0.9,
                fontWeight: AppTypography.regular,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
          // Switch button
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeTrackColor: AppColors.getSuccess(context),
            activeThumbColor: AppColors.getSuccess(context),
            inactiveThumbColor: AppColors.getBorderMedium(context),
            inactiveTrackColor: AppColors.borderLight,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionText(String text) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Text(
      text,
      style: TextStyle(
        fontSize: 14 * s * 0.9,
        fontWeight: AppTypography.regular,
        color: AppColors.textSecondary,
        height: 1.5,
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
            ? LanguageHelper.tr(_translations, 'data_usage.data_usage_text')
            : 'Data Usage',
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
          children: [
            // Section header: Audio Data
            Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(
                      _translations,
                      'data_usage.audio_data_text',
                    )
                  : 'Audio Data',
              style: TextStyle(
                fontSize: 14 * s * 0.9,
                fontWeight: AppTypography.medium,
                color: AppColors.textSecondary,
              ),
            ),

            SizedBox(height: AppDesignSystem.space16 * s * 0.9),

            // Save audio data toggle
            _buildToggleOption(
              icon: Icons.cloud_upload_outlined,
              label: _translations.isNotEmpty
                  ? LanguageHelper.tr(
                      _translations,
                      'data_usage.save_audio_data_text',
                    )
                  : 'Save audio data',
              isEnabled: _saveAudioDataEnabled,
              onChanged: _toggleSaveAudioData,
            ),

            SizedBox(height: AppDesignSystem.space16 * s * 0.9),

            // Description text for audio data
            _buildDescriptionText(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(
                      _translations,
                      'data_usage.save_audio_data_text',
                    )
                  : 'Qurani securely stores your audio in the cloud to provide you with unique features such as replaying mistakes, listening to your audio, and sharing audio. If you disable this setting, you will lose access to these features. This setting is not applied retroactively.',
            ),

            SizedBox(height: AppDesignSystem.space32 * s * 0.9),

            // Section header: AI Training
          ],
        ),
      ),
    );
  }
}
