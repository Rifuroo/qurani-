// lib/screens/main/home/screens/settings/widgets/sound_effect.dart
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== SOUND EFFECT SELECTION PAGE ====================
/// Halaman untuk memilih sound effect yang akan digunakan saat mistake detection

class SoundEffectPage extends StatefulWidget {
  final String currentSoundEffect;
  final Function(String) onSoundEffectSelected;

  const SoundEffectPage({
    Key? key,
    required this.currentSoundEffect,
    required this.onSoundEffectSelected,
  }) : super(key: key);

  @override
  State<SoundEffectPage> createState() => _SoundEffectPageState();
}

class _SoundEffectPageState extends State<SoundEffectPage> {
  late String _selectedSoundEffect;

  // List of available sound effects (dummy data)
  final List<String> _soundEffects = [
    'Error',
    'Slap',
    'Knock',
    'Clack',
    'Bounce',
    'Ding',
    'Ping',
    'Pulse',
    'Zap',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSoundEffect = widget.currentSoundEffect;
  }

  void _selectSoundEffect(String soundEffect) {
    setState(() {
      _selectedSoundEffect = soundEffect;
    });
    AppHaptics.selection();
    widget.onSoundEffectSelected(soundEffect);

    // TODO: Play preview sound
  }

  Widget _buildSoundEffectOption({
    required String label,
    required bool isSelected,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return InkWell(
      onTap: () => _selectSoundEffect(label),
      borderRadius:
          BorderRadius.circular(AppDesignSystem.radiusMedium * s * 0.9),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space16 * s * 0.9,
          vertical: AppDesignSystem.space16 * s * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.circular(AppDesignSystem.radiusMedium * s * 0.9),
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
                      : AppColors.textPrimary,
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
      appBar: const SettingsAppBar(
        title: 'Sound effect',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
            child: Column(
              children: _soundEffects
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key < _soundEffects.length - 1
                            ? AppDesignSystem.space16 * s * 0.9
                            : 0,
                      ),
                      child: _buildSoundEffectOption(
                        label: entry.value,
                        isSelected: _selectedSoundEffect == entry.value,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}


