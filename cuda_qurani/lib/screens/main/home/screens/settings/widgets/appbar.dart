// lib/screens/main/home/screens/settings/widgets/appbar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

/// ==================== SETTINGS APP BAR ====================
/// AppBar untuk halaman settings dan submenunya dengan navigasi yang benar

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const SettingsAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final brightness = Theme.of(context).brightness;

    return AppBar(
      backgroundColor: AppColors.getSurface(context),
      foregroundColor: AppColors.getTextPrimary(context),
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      systemOverlayStyle:
          brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      leading: showBackButton
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  AppHaptics.light();
                  // ✅ PERBAIKAN: Gunakan pop() bukan pushReplacement()
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusSmall * s,
                ),
                splashColor: AppComponentStyles.rippleColor,
                child: Container(
                  padding: EdgeInsets.only(left: AppDesignSystem.space12 * s),
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.arrow_back_ios_rounded,
                    size: AppDesignSystem.iconMedium * s,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
            )
          : null,
      title: Text(
        title,
        style: AppTypography.titleLarge(
          context,
          weight: AppTypography.semiBold,
          color: AppColors.getTextPrimary(context),
        ),
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          height: AppDesignSystem.borderNormal,
          color: AppColors.getBorderLight(context),
        ),
      ),
    );
  }
}


