// lib/screens/main/home/screens/settings/submenu/listening.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/reciters_download.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== LISTENING SETTINGS PAGE ====================
/// Halaman untuk mengatur pengaturan listening/mendengarkan Quran

class ListeningPage extends StatefulWidget {
  const ListeningPage({Key? key}) : super(key: key);

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/experiences');
    setState(() {
      _translations = trans;
    });
  }

  // Dummy data untuk reciters
  final List<String> _reciters = [
    'Abdul-Rahman Al-Sudais',
    'Abu Bakr Al-Shatri',
    'Ahmad Alnufais',
    'Khalifa Al-Tunaiji',
    'Maher Al-Muaiqly',
    'Mishary Rashid Alafasy',
    'Saad Al-Ghamdi',
    'Abdulbasit Abdulsamad',
    'Mohamed Siddiq El-Minshawi',
    'Ali Abdur-Rahman Al-Huthaify',
  ];

  // Selected reciter (dummy state)
  String _selectedReciter = 'Ahmad Alnufais';

  // Selected play speed (dummy state)
  String _selectedSpeed = '1x';

  // Available play speeds
  final List<String> _playSpeeds = [
    '0.5x',
    '0.75x',
    '1x',
    '1.25x',
    '1.5x',
    '1.75x',
  ];

  // Dropdown expanded state
  bool _isDropdownExpanded = false;

  void _selectReciter(String reciter) {
    setState(() {
      _selectedReciter = reciter;
      _isDropdownExpanded = false;
    });
    AppHaptics.selection();

    // TODO: Implement reciter selection logic
  }

  void _toggleDropdown() {
    setState(() {
      _isDropdownExpanded = !_isDropdownExpanded;
    });
    AppHaptics.selection();
  }

  void _selectSpeed(String speed) {
    setState(() {
      _selectedSpeed = speed;
    });
    AppHaptics.selection();

    // TODO: Implement speed change logic
  }

  void _manageDownloads() {
    AppHaptics.selection();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RecitersDownloadPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.03, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          var fadeAnimation = animation.drive(
            Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        transitionDuration: AppDesignSystem.durationNormal,
      ),
    );
  }

  Widget _buildSpeedButton(String speed) {
    final s = AppDesignSystem.getScaleFactor(context);
    final isSelected = _selectedSpeed == speed;

    return InkWell(
      onTap: () => _selectSpeed(speed),
      borderRadius: BorderRadius.circular(
        AppDesignSystem.radiusMedium * s * 0.9,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space12 * s * 0.9,
          vertical: AppDesignSystem.space10 * s * 0.9,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : AppColors.surface,
          borderRadius: BorderRadius.circular(
            AppDesignSystem.radiusMedium * s * 0.9,
          ),
          border: Border.all(
            color: isSelected ? Colors.black : AppColors.borderLight,
            width: 1.0 * s * 0.9,
          ),
        ),
        child: Text(
          speed,
          style: TextStyle(
            fontSize: 15 * s * 0.9,
            fontWeight: isSelected
                ? AppTypography.semiBold
                : AppTypography.regular,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
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
            ? LanguageHelper.tr(
                _translations,
                'experiences_menu.listening_text',
              )
            : 'Listening',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reciter Section
                Text(
                  _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'experiences_menu.listening_page.reciter_text',
                        )
                      : 'Reciter',
                  style: TextStyle(
                    fontSize: 14 * s * 0.9,
                    fontWeight: AppTypography.medium,
                    color: AppColors.textSecondary,
                  ),
                ),

                SizedBox(height: AppDesignSystem.space12 * s * 0.9),

                // Reciter Container
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusMedium * s * 0.9,
                    ),
                    border: Border.all(
                      color: AppColors.borderLight,
                      width: 1.0 * s * 0.9,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Selected Reciter (Dropdown Header)
                      InkWell(
                        onTap: _toggleDropdown,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(
                            AppDesignSystem.radiusMedium * s * 0.9,
                          ),
                          topRight: Radius.circular(
                            AppDesignSystem.radiusMedium * s * 0.9,
                          ),
                          bottomLeft: _isDropdownExpanded
                              ? Radius.zero
                              : Radius.circular(
                                  AppDesignSystem.radiusMedium * s * 0.9,
                                ),
                          bottomRight: _isDropdownExpanded
                              ? Radius.zero
                              : Radius.circular(
                                  AppDesignSystem.radiusMedium * s * 0.9,
                                ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppDesignSystem.space16 * s * 0.9,
                            vertical: AppDesignSystem.space16 * s * 0.9,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedReciter,
                                  style: TextStyle(
                                    fontSize: 16 * s * 0.9,
                                    fontWeight: AppTypography.regular,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                _isDropdownExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 24 * s * 0.9,
                                color: AppColors.textPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Dropdown List
                      if (_isDropdownExpanded) ...[
                        Divider(
                          height: 1,
                          thickness: 1 * s * 0.9,
                          color: AppColors.borderLight,
                        ),
                        Container(
                          constraints: BoxConstraints(maxHeight: 250 * s * 0.9),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _reciters.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 1 * s * 0.9,
                              color: AppColors.borderLight,
                            ),
                            itemBuilder: (context, index) {
                              final reciter = _reciters[index];
                              final isSelected = reciter == _selectedReciter;

                              return InkWell(
                                onTap: () => _selectReciter(reciter),
                                child: Container(
                                  color: isSelected
                                      ? AppColors.borderLight.withValues(alpha: 0.3)
                                      : Colors.transparent,
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        AppDesignSystem.space16 * s * 0.9,
                                    vertical: AppDesignSystem.space16 * s * 0.9,
                                  ),
                                  child: Center(
                                    child: Text(
                                      reciter,
                                      style: TextStyle(
                                        fontSize: 16 * s * 0.9,
                                        fontWeight: isSelected
                                            ? AppTypography.medium
                                            : AppTypography.regular,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Divider before Manage Downloads
                      if (!_isDropdownExpanded)
                        Divider(
                          height: 1,
                          thickness: 1 * s * 0.9,
                          color: AppColors.borderLight,
                        ),

                      // Manage Downloads Button
                      if (!_isDropdownExpanded)
                        InkWell(
                          onTap: _manageDownloads,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(
                              AppDesignSystem.radiusMedium * s * 0.9,
                            ),
                            bottomRight: Radius.circular(
                              AppDesignSystem.radiusMedium * s * 0.9,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppDesignSystem.space16 * s * 0.9,
                              vertical: AppDesignSystem.space16 * s * 0.9,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _translations.isNotEmpty
                                        ? LanguageHelper.tr(
                                            _translations,
                                            'experiences_menu.listening_page.manage_downloads_text',
                                          )
                                        : 'Manage downloads',
                                    style: TextStyle(
                                      fontSize: 16 * s * 0.9,
                                      fontWeight: AppTypography.regular,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 24 * s * 0.9,
                                  height: 24 * s * 0.9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                  child: Icon(
                                    Icons.arrow_downward,
                                    size: 14 * s * 0.9,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: AppDesignSystem.space24 * s * 0.9),

                // Play Speed Section
                // Text(
                //   'Play speed',
                //   style: TextStyle(
                //     fontSize: 14 * s * 0.9,
                //     fontWeight: AppTypography.medium,
                //     color: AppColors.textSecondary,
                //   ),
                // ),

                // SizedBox(height: AppDesignSystem.space12 * s * 0.9),

                // Play Speed Buttons
                // SingleChildScrollView(
                //   scrollDirection: Axis.horizontal,
                //   child: Row(
                //     children: _playSpeeds.map((speed) {
                //       return Padding(
                //         padding: EdgeInsets.only(
                //           right: AppDesignSystem.space10 * s * 0.8,
                //         ),
                //         child: _buildSpeedButton(speed),
                //       );
                //     }).toList(),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



