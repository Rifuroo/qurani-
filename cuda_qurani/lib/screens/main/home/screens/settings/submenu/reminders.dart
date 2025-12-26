import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';
import 'package:cuda_qurani/models/premium_features.dart';
import 'package:cuda_qurani/providers/reminder_provider.dart';
import 'package:cuda_qurani/core/widgets/premium_dialog.dart';

/// ==================== REMINDERS SETTINGS PAGE ====================
/// Halaman untuk mengatur reminder/pengingat aplikasi

class RemindersPage extends StatefulWidget {
  const RemindersPage({Key? key}) : super(key: key);

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
      Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/notifications');
    setState(() {
      _translations = trans;
    });
  }
  void _toggleStreakReminder(bool value) {
    context.read<ReminderProvider>().toggleStreakReminder(value);
    AppHaptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'reminders_text')
                      : 'Reminders',
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Streak Reminder Option
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space16 * s * 0.9,
                  vertical: AppDesignSystem.space16 * s * 0.9,
                ),
                  decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s * 0.9),
                  border: Border.all(
                    color: AppColors.getBorderLight(context),
                    width: 1.0 * s * 0.9,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'streak_reminder_text')
                      : 'Streak Reminders',
                        style: TextStyle(
                          fontSize: 16 * s * 0.9,
                          fontWeight: AppTypography.regular,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                    // 🔒 PREMIUM GATED
                    Consumer<ReminderProvider>(
                      builder: (context, reminderProvider, child) {
                        return _buildPremiumSwitch(
                          context,
                          feature: PremiumFeature.notifications,
                          value: reminderProvider.streakReminderEnabled,
                          onChanged: _toggleStreakReminder,
                        );
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppDesignSystem.space16 * s * 0.9),

              // Info text and Allow button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'streak_reminder_desc')
                      : 'Please allow notifications in your device settings to receive reminders.',
                      style: TextStyle(
                        fontSize: 14 * s * 0.9,
                        fontWeight: AppTypography.regular,
                        color: AppColors.getError(context),
                      ),
                    ),
                  ),
                  SizedBox(width: AppDesignSystem.space12 * s * 0.9),
                  // Allow button
                  ElevatedButton(
                    onPressed: () async {
                      AppHaptics.selection();
                      final granted = await context.read<ReminderProvider>().requestPermissions();
                      if (granted && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifikasi diaktifkan!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getTextPrimary(context),
                      foregroundColor: AppColors.getTextInverse(context),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDesignSystem.space20 * s * 1.5,
                        vertical: AppDesignSystem.space10 * s * 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s * 1.5),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'allow_text')
                      : 'Allow',
                      style: TextStyle(
                        fontSize: 14 * s * 0.9,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔒 Helper untuk build switch dengan premium gating
  Widget _buildPremiumSwitch(
    BuildContext context, {
    required PremiumFeature feature,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final premium = context.watch<PremiumProvider>();
    final canAccess = premium.canAccess(feature);
    final s = AppDesignSystem.getScaleFactor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PRO badge jika tidak bisa akses
        if (!canAccess)
          GestureDetector(
            onTap: () => showPremiumFeatureDialog(context, feature),
            child: Container(
              margin: EdgeInsets.only(right: 8 * s),
              padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 2 * s),
              decoration: BoxDecoration(
                color: AppColors.getWarning(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4 * s),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 10 * s, color: AppColors.getWarning(context)),
                  SizedBox(width: 2 * s),
                  Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 8 * s,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getWarning(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Switch
        Switch(
          value: canAccess ? value : false,
          onChanged: canAccess
              ? onChanged
              : (_) => showPremiumFeatureDialog(context, feature),
          activeTrackColor: AppColors.getPrimary(context).withValues(alpha: 0.5),
          activeThumbColor: Colors.white,
          inactiveThumbColor: AppColors.getBorderMedium(context),
          inactiveTrackColor: AppColors.getBorderLight(context),
        ),
      ],
    );
  }
}