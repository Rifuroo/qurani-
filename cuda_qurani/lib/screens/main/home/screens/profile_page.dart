// lib/screens/main/home/screens/profile_page.dart
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/screens/main/auth/login/login_page.dart';
import 'package:cuda_qurani/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('profile/profile');
    setState(() {
      _translations = trans;
    });
  }

  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getSurfaceVariant(context),
      appBar: ProfileAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'profile.account_text')
            : 'Account',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: AppPadding.horizontal(context, AppDesignSystem.space24),
            child: Column(
              children: [
                AppMargin.gap(context),
                _buildProfileHeader(),
                AppMargin.gap(context),
                _buildInfoSection(),
                AppMargin.gap(context),
                _buildActionButtons(),
                AppMargin.gapLarge(context),
                _buildMenuSection(),
                AppMargin.gap(context),
                _buildDeleteAccount(),
                AppMargin.customGap(context, 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // ✅ FIX: Jangan render jika user null atau sedang logout
    if (user == null || _isLoggingOut) {
      return AppCard(
        padding: AppPadding.all(context, AppDesignSystem.space20),
        child: Row(
          children: [
            Container(
              width: AppDesignSystem.scale(context, 64),
              height: AppDesignSystem.scale(context, 64),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceContainerLowest(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: AppDesignSystem.scale(context, 24),
                  height: AppDesignSystem.scale(context, 24),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            AppMargin.gapH(context),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: AppDesignSystem.scale(context, 20),
                    width: AppDesignSystem.scale(context, 120),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceContainerLowest(context),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.scale(context, 4),
                      ),
                    ),
                  ),
                  AppMargin.gapSmall(context),
                  Container(
                    height: AppDesignSystem.scale(context, 16),
                    width: AppDesignSystem.scale(context, 160),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceContainerLowest(context),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.scale(context, 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Get user info
    String displayName = user.email.split('@')[0];
    String avatarLetter = displayName[0].toUpperCase();

    if (user.fullName != null && user.fullName!.isNotEmpty) {
      displayName = user.fullName!;
      avatarLetter = user.fullName![0].toUpperCase();
    }

    return AppCard(
      padding: AppPadding.all(context, AppDesignSystem.space20),
      child: Row(
        children: [
          // Avatar with gradient background
          Container(
            width: AppDesignSystem.scale(context, 64),
            height: AppDesignSystem.scale(context, 64),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.getPrimary(context).withValues(alpha: 0.2),
                  AppColors.getPrimary(context).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                avatarLetter,
                style: AppTypography.h2(
                  context,
                  color: AppColors.getPrimary(context),
                  weight: AppTypography.semiBold,
                ),
              ),
            ),
          ),
          AppMargin.gapH(context),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: AppTypography.titleLarge(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppMargin.gapSmall(context),
                Text(
                  user.email,
                  style: AppTypography.body(
                    context,
                    color: AppColors.getTextTertiary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // ✅ FIX: Tampilkan skeleton saat logout
    if (user == null || _isLoggingOut) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildInfoRowSkeleton(showDivider: true),
            _buildInfoRowSkeleton(showDivider: false),
          ],
        ),
      );
    }

    // Format date
    final date = user.createdAt;
    String joinedDate =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildInfoRow(
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'profile.joined_text')
                : 'Joined',
            context.formatNumber(joinedDate),
            showDivider: true,
          ),
          _buildInfoRow(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'profile.subscription_status_text',
                  )
                : 'Subscription Status',
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'profile.premium_text')
                : 'Premium',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    required bool showDivider,
  }) {
    return Container(
      padding: AppPadding.all(context, AppDesignSystem.space16),
      decoration: showDivider
          ? AppComponentStyles.divider(color: AppColors.getBorderLight(context))
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body(context)),
          Text(
            value,
            style: AppTypography.body(context, color: AppColors.getTextTertiary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowSkeleton({required bool showDivider}) {
    return Container(
      padding: AppPadding.all(context, AppDesignSystem.space16),
      decoration: showDivider
          ? AppComponentStyles.divider(color: AppColors.getBorderLight(context))
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: AppDesignSystem.scale(context, 16),
            width: AppDesignSystem.scale(context, 80),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceContainerLowest(context),
              borderRadius: BorderRadius.circular(
                AppDesignSystem.scale(context, 4),
              ),
            ),
          ),
          Container(
            height: AppDesignSystem.scale(context, 16),
            width: AppDesignSystem.scale(context, 100),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceContainerLowest(context),
              borderRadius: BorderRadius.circular(
                AppDesignSystem.scale(context, 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          text: _translations.isNotEmpty
              ? LanguageHelper.tr(
                  _translations,
                  'profile.switch_account_text',
                ).toUpperCase()
              : 'SWITCH ACCOUNT',
          onPressed: _showSwitchAccountBottomSheet,
          isLogout: false,
        ),
        AppMargin.gapSmall(context),
        _buildActionButton(
          text: _translations.isNotEmpty
              ? LanguageHelper.tr(
                  _translations,
                  'profile.logout_text',
                ).toUpperCase()
              : 'LOG OUT',
          onPressed: _showLogoutDialog,
          isLogout: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    required bool isLogout,
  }) {
    final bool isDisabled = _isLoggingOut;

    return Container(
      height: AppDesignSystem.scale(context, 48),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border.all(
          color: isDisabled
              ? AppColors.getBorderLight(context)
              : AppColors.getTextPrimary(context).withValues(alpha: 0.75),
          width: AppDesignSystem.scale(context, 1.5),
        ),
        borderRadius: BorderRadius.circular(
          AppDesignSystem.scale(context, AppDesignSystem.radiusXXLarge),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? null
              : () {
                  AppHaptics.light();
                  onPressed();
                },
          borderRadius: BorderRadius.circular(
            AppDesignSystem.scale(context, AppDesignSystem.radiusXXLarge),
          ),
          splashColor: AppComponentStyles.rippleColor,
          highlightColor: AppComponentStyles.hoverColor,
          child: Center(
            child: _isLoggingOut && isLogout
                ? SizedBox(
                    width: AppDesignSystem.scale(context, 20),
                    height: AppDesignSystem.scale(context, 20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.getPrimary(context),
                      ),
                    ),
                  )
                : Text(
                    text,
                    style: AppTypography.label(
                      context,
                      color: isDisabled
                          ? AppColors.getTextDisabled(context)
                          : AppColors.getTextPrimary(context),
                      weight: AppTypography.semiBold,
                    ).copyWith(letterSpacing: 0.5),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildMenuItem(
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'profile.about_qurani_text')
                : 'About Qurani',
            Icons.info_outline,
          ),
          _buildMenuItem(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'profile.request_a_feature_text',
                  )
                : 'Request a Feature',
            Icons.chat_bubble_outline,
          ),
          _buildMenuItem(
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'profile.help_center_text')
                : 'Help Center',
            Icons.help_outline,
          ),
          _buildMenuItem(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'profile.share_application_text',
                  )
                : 'Share Application',
            Icons.share_outlined,
          ),
          _buildMenuItem(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'profile.rate_application_text',
                  )
                : 'Rate Application',
            Icons.star_outline,
          ),
          _buildMenuItem(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'profile.terms_and_conditions_text',
                  )
                : 'Terms of Service',
            Icons.arrow_forward_ios,
          ),
          _buildMenuItem(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'profile.privacy_policy_text',
                  )
                : 'Privacy Policy',
            Icons.arrow_forward_ios,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String label,
    IconData icon, {
    bool showDivider = true,
  }) {
    return InkWell(
      onTap: _isLoggingOut
          ? null
          : () {
              AppHaptics.light();
              // TODO: Implement navigation
            },
      splashColor: AppComponentStyles.rippleColor,
      highlightColor: AppComponentStyles.hoverColor,
      child: Container(
        padding: AppPadding.all(context, AppDesignSystem.space16),
        decoration: showDivider
            ? AppComponentStyles.divider(color: AppColors.getBorderLight(context))
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.body(
                context,
                color: _isLoggingOut
                    ? AppColors.getTextDisabled(context)
                    : AppColors.getTextPrimary(context),
              ),
            ),
            Icon(
              icon,
              size: AppDesignSystem.scale(context, AppDesignSystem.iconSmall),
              color: AppColors.getTextDisabled(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccount() {
    return AppCard(
      child: InkWell(
        onTap: _isLoggingOut
            ? null
            : () {
                AppHaptics.light();
                _showDeleteAccountDialog();
              },
        splashColor: AppColors.getError(context).withValues(alpha: 0.05),
        highlightColor: AppColors.getError(context).withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(
          AppDesignSystem.scale(context, AppDesignSystem.radiusMedium),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'profile.delete_account_text',
                  )
                : 'Delete Account',
            style: AppTypography.body(
              context,
              color: _isLoggingOut ? AppColors.getTextDisabled(context) : AppColors.error,
              weight: AppTypography.medium,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BOTTOM SHEET - SWITCH ACCOUNT ====================
  void _showSwitchAccountBottomSheet() {
    final screenHeight = AppDesignSystem.screenHeight(context);
    final sheetHeight = screenHeight * 0.4;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.getScrim(context),
      builder: (context) => _SwitchAccountBottomSheet(),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppDesignSystem.scale(context, AppDesignSystem.radiusLarge),
          ),
        ),
        title: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'profile.logout_text')
              : 'Logout',
          style: AppTypography.titleLarge(context),
        ),
        content: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'profile.logout_desc')
              : 'Apakah Anda yakin ingin keluar?',
          style: AppTypography.body(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'profile.cancel_text')
                  : 'Cancel',
              style: AppTypography.label(
                context,
                color: AppColors.getTextTertiary(context),
                weight: AppTypography.medium,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            child: Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'profile.logout_text')
                  : 'Logout',
              style: AppTypography.label(
                context,
                color: AppColors.error,
                weight: AppTypography.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppDesignSystem.scale(context, AppDesignSystem.radiusLarge),
          ),
        ),
        title: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'profile.delete_account_text')
              : 'Delete Account',
          style: AppTypography.titleLarge(context, color: AppColors.error),
        ),
        content: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'profile.delete_account_desc')
              : 'This action cannot be undone. All your data will be permanently deleted.',
          style: AppTypography.body(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(
                      _translations,
                      'profile.cancel_text',
                    ).toUpperCase()
                  : 'Cancel',
              style: AppTypography.label(
                context,
                color: AppColors.getTextTertiary(context),
                weight: AppTypography.medium,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete account
              ScaffoldMessenger.of(context).showSnackBar(
                AppComponentStyles.infoSnackBar(
                  message: 'Delete account feature coming soon',
                ),
              );
            },
            child: Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'profile.delete_text')
                  : 'Delete',
              style: AppTypography.label(
                context,
                color: AppColors.error,
                weight: AppTypography.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    // ✅ FIX: Set loading state SEBELUM logout
    setState(() {
      _isLoggingOut = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await authProvider.signOut();

      if (!mounted) return;

      // ✅ FIX: Langsung navigate tanpa delay, jangan reset loading state
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.successSnackBar(message: 'Logged out successfully'),
      );
    } catch (e) {
      print('❌ ProfilePage: Logout failed - $e');

      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(
          message: 'Logout failed: ${e.toString()}',
        ),
      );
    }
  }
}

// ==================== SWITCH ACCOUNT BOTTOM SHEET WIDGET ====================
// Replace the _SwitchAccountBottomSheet class with this:

class _SwitchAccountBottomSheet extends StatefulWidget {
  const _SwitchAccountBottomSheet({Key? key}) : super(key: key);

  @override
  State<_SwitchAccountBottomSheet> createState() =>
      _SwitchAccountBottomSheetState();
}

class _SwitchAccountBottomSheetState extends State<_SwitchAccountBottomSheet> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('profile/profile');
    setState(() {
      _translations = trans;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            AppDesignSystem.scale(context, AppDesignSystem.radiusXLarge),
          ),
          topRight: Radius.circular(
            AppDesignSystem.scale(context, AppDesignSystem.radiusXLarge),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: AppPadding.vertical(context, AppDesignSystem.space12),
            width: AppDesignSystem.scale(context, 40),
            height: AppDesignSystem.scale(context, 4),
            decoration: BoxDecoration(
              color: AppColors.getBorderMedium(context),
              borderRadius: BorderRadius.circular(
                AppDesignSystem.scale(context, AppDesignSystem.radiusRound),
              ),
            ),
          ),

          // Header
          Padding(
            padding: AppPadding.horizontal(context, AppDesignSystem.space24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'profile.switch_account_text',
                        )
                      : 'Switch Account',
                  style: AppTypography.h3(context),
                ),
                AppIconButton(
                  icon: Icons.close,
                  onPressed: () => Navigator.pop(context),
                  size: AppDesignSystem.iconLarge,
                ),
              ],
            ),
          ),

          AppMargin.gap(context),
          const AppDivider(),

          // Account List
          currentUser == null
              ? Expanded(child: _buildEmptyState(context))
              : _buildAccountList(context, currentUser),

          // Add Account Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDesignSystem.space20 * AppDesignSystem.getScaleFactor(context),
              AppDesignSystem.space16 * AppDesignSystem.getScaleFactor(context),
              AppDesignSystem.space20 * AppDesignSystem.getScaleFactor(context),
              AppDesignSystem.space20 * AppDesignSystem.getScaleFactor(context),
            ),
            child: Container(
              height: AppDesignSystem.scale(context, 48),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                border: Border.all(
                  color: AppColors.getTextPrimary(context).withOpacity(0.50),
                  width: AppDesignSystem.scale(context, 1.5),
                ),
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.scale(context, AppDesignSystem.radiusXXLarge),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    AppHaptics.light();
                    Navigator.pop(context);
                    _showAddAccountDialog(context);
                  },
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.scale(
                      context,
                      AppDesignSystem.radiusXXLarge,
                    ),
                  ),
                  splashColor: AppComponentStyles.rippleColor,
                  highlightColor: AppComponentStyles.hoverColor,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: AppDesignSystem.scale(
                            context,
                            AppDesignSystem.iconMedium,
                          ),
                          color: AppColors.getTextPrimary(context).withValues(alpha: 0.85),
                        ),
                        AppMargin.gapHSmall(context),
                        Text(
                          _translations.isNotEmpty
                              ? LanguageHelper.tr(
                                  _translations,
                                  'profile.add_account_text',
                                ).toUpperCase()
                              : 'ADD ACCOUNT',
                          style: AppTypography.label(
                            context,
                            color: AppColors.getTextPrimary(context).withValues(alpha: 0.85),
                            weight: AppTypography.semiBold,
                          ).copyWith(letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: AppDesignSystem.scale(context, 10)),
        ],
      ),
    );
  }

  Widget _buildAccountList(BuildContext context, currentUser) {
    String displayEmail = currentUser.email;
    String displayName = currentUser.email.split('@')[0];
    String avatarLetter = displayName[0].toUpperCase();

    if (currentUser.fullName != null && currentUser.fullName!.isNotEmpty) {
      displayName = currentUser.fullName!;
      avatarLetter = currentUser.fullName![0].toUpperCase();
    }

    return Column(
      children: [
        Padding(
          padding: AppPadding.only(
            context,
            top: AppDesignSystem.space16,
            left: AppDesignSystem.space16,
            right: AppDesignSystem.space16,
          ),
          child: _buildAccountItem(
            context: context,
            avatarLetter: avatarLetter,
            name: displayName,
            email: currentUser.email,
            isActive: true,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                AppComponentStyles.infoSnackBar(
                  message: 'Already using this account',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountItem({
    required BuildContext context,
    required String avatarLetter,
    required String name,
    required String email,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppComponentStyles.rippleColor,
        highlightColor: AppComponentStyles.hoverColor,
        borderRadius: BorderRadius.circular(
          AppDesignSystem.scale(context, AppDesignSystem.radiusMedium),
        ),
        child: Container(
          padding: AppPadding.all(context, AppDesignSystem.space16),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            border: Border.all(
              color: isActive
                  ? AppColors.getTextPrimary(context).withValues(alpha: 0.50)
                  : AppColors.getBorderMedium(context),
              width: AppDesignSystem.scale(context, isActive ? 1.5 : 1),
            ),
            borderRadius: BorderRadius.circular(
              AppDesignSystem.scale(context, AppDesignSystem.radiusMedium),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppDesignSystem.scale(context, 48),
                height: AppDesignSystem.scale(context, 48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.getPrimary(context).withValues(alpha: 0.2),
                      AppColors.getPrimary(context).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    avatarLetter,
                    style: AppTypography.titleLarge(
                      context,
                      color: AppColors.getPrimary(context),
                      weight: AppTypography.semiBold,
                    ),
                  ),
                ),
              ),
              AppMargin.gapH(context),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppTypography.title(
                        context,
                        weight: AppTypography.semiBold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppMargin.gapSmall(context),
                    Text(
                      email,
                      style: AppTypography.caption(
                        context,
                        color: AppColors.getTextTertiary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isActive) ...[
                AppMargin.gapHSmall(context),
                Icon(
                  Icons.check_circle,
                  color: AppColors.getSecondary(context).withValues(alpha: 0.80),
                  size: AppDesignSystem.scale(
                    context,
                    AppDesignSystem.iconLarge,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppPadding.all(context, AppDesignSystem.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppDesignSystem.scale(context, 80),
              height: AppDesignSystem.scale(context, 80),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceContainerLowest(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: AppDesignSystem.scale(context, 40),
                color: AppColors.getTextDisabled(context),
              ),
            ),
            AppMargin.gapLarge(context),
            Text('No accounts yet', style: AppTypography.titleLarge(context)),
            AppMargin.gapSmall(context),
            Text(
              'Add an account to get started',
              style: AppTypography.body(context, color: AppColors.getTextTertiary(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppDesignSystem.scale(context, AppDesignSystem.radiusLarge),
          ),
        ),
        title: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'profile.add_account_text')
              : 'Add Account',
          style: AppTypography.titleLarge(context),
        ),
        content: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'profile.add_account_desc')
              : 'This feature is coming soon. You can logout and login with a different account.',
          style: AppTypography.body(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: AppTypography.label(
                context,
                color: AppColors.getPrimary(context),
                weight: AppTypography.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
