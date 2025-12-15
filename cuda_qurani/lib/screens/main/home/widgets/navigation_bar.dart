// lib/screens/main/home/widgets/navigation_bar.dart

import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/activity_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/completion_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/premium_offer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cuda_qurani/screens/main/stt/utils/constants.dart' as constants;
import 'package:cuda_qurani/screens/main/home/screens/home_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/surah_list_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/profile_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/settings_page.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';

class MenuAppBar extends StatefulWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final bool showSearch;
  final TextEditingController? searchController;
  final Function(String)? onSearchChanged;
  final VoidCallback? onSearchClear;

  const MenuAppBar({
    Key? key,
    required this.selectedIndex,
    this.showSearch = false,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(120);

  @override
  State<MenuAppBar> createState() => _MenuAppBarState();
}

class _MenuAppBarState extends State<MenuAppBar>


    with SingleTickerProviderStateMixin {
  bool _isSearchFocused = false;
  late FocusNode _searchFocusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Menu items with proper structure
  List<Map<String, dynamic>> get _menuItems => [
    {
      'label': _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'appbar_widget.home_text')
          : 'Home',
      'index': 0,
      'icon': Icons.home_outlined,
    },
    {
      'label': _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'appbar_widget.quran_text')
          : 'Quran',
      'index': 1,
      'icon': Icons.menu_book_outlined,
    },
    {
      'label': _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'appbar_widget.completion_text')
          : 'Completion',
      'index': 2,
      'icon': Icons.flag_outlined,
    },
    {
      'label': _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'appbar_widget.activity_text')
          : 'Activity',
      'index': 4,
      'icon': Icons.analytics_outlined,
    },
    {
      'label': _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'appbar_widget.premium_text')
          : 'Premium',
      'index': 6,
      'icon': Icons.settings_outlined,
    },
  ];

  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('appbar');
    setState(() {
      _translations = trans;
    });
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _loadTranslations();
    _searchFocusNode.addListener(_handleSearchFocusChange);

    _animationController = AnimationController(
      vsync: this,
      duration: AppDesignSystem.durationFast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _handleSearchFocusChange() {
    if (mounted) {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border(
          bottom: BorderSide(
            color: AppColors.getBorderLight(context),
            width: AppDesignSystem.borderNormal,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildTopBar(context), _buildMenuBar(context)],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      height: 50 * s,
      padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space20 * s),
      child: Row(
        children: [
          Image.asset(
            'assets/images/qurani-white-text.png',
            height: 28 * s,
            color: AppColors.primary,
            fit: BoxFit.contain,
          ),
          SizedBox(width: AppDesignSystem.space16 * s),
          const Spacer(),
          SizedBox(width: AppDesignSystem.space12 * s),
          _buildTopIconButton(
            context,
            icon: Icons.person_outline_rounded,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ProfilePage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0.02, 0.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                          child: child,
                        ),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 250),
              ),
            ),
            isSelected: widget.selectedIndex == 3,
          ),
          SizedBox(width: AppDesignSystem.space8 * s),
          if (widget.selectedIndex != 6)
            _buildTopIconButton(
              context,
              icon: Icons.settings_outlined,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const SettingsPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0.02, 0.0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
                            child: child,
                          ),
                        );
                      },
                  transitionDuration: const Duration(milliseconds: 250),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool isSelected = false,
    String? tooltip,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    final size = 40 * s;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        splashColor: AppComponentStyles.rippleColor,
        highlightColor: AppComponentStyles.hoverColor,
        child: AnimatedContainer(
          duration: AppDesignSystem.durationFast,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryWithOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              AppDesignSystem.radiusMedium * s,
            ),
            border: isSelected
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: AppDesignSystem.borderNormal * s,
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.getTextSecondary(context),
            size: AppDesignSystem.iconLarge * s,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }

    return button;
  }

  Widget _buildMenuBar(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / _menuItems.length;

    return Container(
      height: 56 * s,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space8 * s),
        child: Row(
          children: _menuItems.map((item) {
            return _buildMenuItem(
              context,
              label: item['label'] as String,
              index: item['index'] as int,
              icon: item['icon'] as IconData,
              itemWidth: itemWidth,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String label,
    required int index,
    required IconData icon,
    required double itemWidth,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    final isSelected = widget.selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          _navigateToPage(context, index);
        },
        splashColor: AppComponentStyles.rippleColor,
        highlightColor: AppComponentStyles.hoverColor,
        child: AnimatedContainer(
          duration: AppDesignSystem.durationFast,
          padding: EdgeInsets.symmetric(
            vertical: AppDesignSystem.space2 * s,
            horizontal: AppDesignSystem.space16 * s,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: AppDesignSystem.borderXXThick * s,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.label(
                  context,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.getTextDisabled(context),
                  weight: isSelected
                      ? AppTypography.semiBold
                      : AppTypography.medium,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SMOOTH NAVIGATION (NO FLICKER) ====================
  void _navigateToPage(BuildContext context, int index) {
    if (widget.selectedIndex == index) return;

    Widget targetPage;
    switch (index) {
      case 0:
        targetPage = const HomePage();
        break;
      case 1:
        targetPage = const SurahListPage();
        break;
      case 2:
        targetPage = const CompletionPage();
        break;
      case 3:
        targetPage = const ProfilePage();
        break;
      case 4:
        targetPage = const ActivityPage();
        break;
      case 5:
        targetPage = const SettingsPage();
        break;
      case 6:
        targetPage = const PremiumOfferPage();
        break;
      default:
        return;
    }

    // ✨ SOLUSI: Gunakan push dengan popUntil untuk main pages
    // Ini lebih smooth karena tidak ada flicker
    if (index == 6 || index == 5) {
      // Premium & Settings tetap push biasa
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.0, 0.02),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                    ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        ),
      );
      return;
    }

    // ✨ MAIN PAGES: Gunakan pushAndRemoveUntil untuk navigation yang clean
    // Ini menghindari stack yang terlalu dalam
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Crossfade transition - paling smooth, no flicker
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
      (route) => false, // Clear semua route sebelumnya
    );
  }
}

// ==================== PROFILE APP BAR ====================
class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const ProfileAppBar({
    Key? key,
    this.title = 'Account',
    this.actions,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return AppBar(
      backgroundColor: AppColors.getSurface(context),
      foregroundColor: AppColors.getTextPrimary(context),
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: showBackButton
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  AppHaptics.light();
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



