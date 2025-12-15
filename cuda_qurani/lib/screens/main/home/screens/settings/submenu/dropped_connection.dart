// lib/screens/main/home/screens/settings/submenu/dropped_connection.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== DROPPED CONNECTION SETTINGS PAGE ====================
/// Halaman untuk mengatur pengaturan feedback saat koneksi jaringan terputus

class DroppedConnectionPage extends StatefulWidget {
  const DroppedConnectionPage({Key? key}) : super(key: key);

  @override
  State<DroppedConnectionPage> createState() => _DroppedConnectionPageState();
}

class _DroppedConnectionPageState extends State<DroppedConnectionPage> {
      Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/sound&haptics');
    setState(() {
      _translations = trans;
    });
  }
  // Default states untuk semua toggle (dummy state)
  bool _playSound = true;
  bool _vibrateDevice = true;

  void _togglePlaySound(bool value) {
    setState(() {
      _playSound = value;
    });
    AppHaptics.selection();

    // TODO: Implement toggle logic
  }

  void _toggleVibrateDevice(bool value) {
    setState(() {
      _vibrateDevice = value;
    });
    AppHaptics.selection();

    // TODO: Implement toggle logic
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: SettingsAppBar(title: _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'sound_and_haptics.dropped_connection.dropped_connection_text')
                      : 'Dropped Connection'),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sound Section
                Text(
                  _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'sound_and_haptics.sound_text')
                      : 'Sound',
                  style: TextStyle(
                    fontSize: 14 * s * 0.9,
                    fontWeight: AppTypography.medium,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),

                SizedBox(height: AppDesignSystem.space12 * s * 0.9),

                // Sound Container
                Container(
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
                      color: AppColors.getBorderLight(context),
                      width: 1.0 * s * 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        size: 20 * s * 0.9,
                        color: AppColors.getTextPrimary(context),
                      ),
                      SizedBox(width: AppDesignSystem.space12 * s * 0.9),
                      Expanded(
                        child: Text(
                          _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'sound_and_haptics.play_a_sound_text')
                      : 'Play a Sound',
                          style: TextStyle(
                            fontSize: 16 * s * 0.9,
                            fontWeight: AppTypography.regular,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      Switch(
                        value: _playSound,
                        onChanged: _togglePlaySound,
                        activeTrackColor: AppColors.getSuccess(context),
                        activeThumbColor: AppColors.getSuccess(context),
                        inactiveThumbColor: AppColors.getBorderMedium(context),
                        inactiveTrackColor: AppColors.getBorderLight(context),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppDesignSystem.space12 * s * 0.9),

                // Description text
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.space4 * s * 0.9,
                  ),
                  child: Text(
                    _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'sound_and_haptics.dropped_connection.dropped_connection_sound_desc')
                      : 'Adjust the sound played when the network connection is lost during recitation.',
                    style: TextStyle(
                      fontSize: 14 * s * 0.9,
                      fontWeight: AppTypography.regular,
                      color: AppColors.getTextSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ),

                SizedBox(height: AppDesignSystem.space24 * s * 0.9),

                // Haptic Section
                Text(
                  _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'sound_and_haptics.haptic_text')
                      : 'Haptic',
                  style: TextStyle(
                    fontSize: 14 * s * 0.9,
                    fontWeight: AppTypography.medium,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),

                SizedBox(height: AppDesignSystem.space12 * s * 0.9),

                // Vibrate Container
                Container(
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
                      color: AppColors.getBorderLight(context),
                      width: 1.0 * s * 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.vibration,
                        size: 20 * s * 0.9,
                        color: AppColors.getTextPrimary(context),
                      ),
                      SizedBox(width: AppDesignSystem.space12 * s * 0.9),
                      Expanded(
                        child: Text(
                          _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'sound_and_haptics.vibrate_my_device_text')
                      : 'Vibrate my Device',
                          style: TextStyle(
                            fontSize: 16 * s * 0.9,
                            fontWeight: AppTypography.regular,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      Switch(
                        value: _vibrateDevice,
                        onChanged: _toggleVibrateDevice,
                        activeTrackColor: AppColors.getSuccess(context),
                        activeThumbColor: AppColors.getSuccess(context),
                        inactiveThumbColor: AppColors.getBorderMedium(context),
                        inactiveTrackColor: AppColors.getBorderLight(context),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppDesignSystem.space12 * s * 0.9),

                // Description text
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.space4 * s * 0.9,
                  ),
                  child: Text(
                    _translations.isNotEmpty 
                      ? LanguageHelper.tr(_translations, 'sound_and_haptics.dropped_connection.dropped_connection_stop_haptic_desc')
                      : 'Adjust the haptic feedback when the network connection is lost during recitation.',
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