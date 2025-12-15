// lib/screens/main/home/screens/premium_offer_page.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';

class PremiumOfferPage extends StatefulWidget {
  const PremiumOfferPage({Key? key}) : super(key: key);

  @override
  State<PremiumOfferPage> createState() => _PremiumOfferPageState();
}

class _PremiumOfferPageState extends State<PremiumOfferPage> {
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('home/premium');
    setState(() {
      _translations = trans;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _t(String key) {
    return _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, key)
        : key.split('.').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: ProfileAppBar(
        title: _t('premium_offer.title'),
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildGradientHeader(context),
                  _buildComparisonTable(context),
                  SizedBox(
                    height:
                        AppDesignSystem.space80 *
                        AppDesignSystem.getScaleFactor(context),
                  ),
                ],
              ),
            ),
          ),
          _buildSubscribeButton(context),
        ],
      ),
    );
  }

  // ==================== GRADIENT HEADER ====================
  Widget _buildGradientHeader(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.getPrimaryLight(context),
            AppColors.getPrimaryLight(context),
            AppColors.getPrimaryLight(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDesignSystem.space20 * s,
        AppDesignSystem.space16 * s,
        AppDesignSystem.space20 * s,
        AppDesignSystem.space24 * s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Image.asset(
            'assets/images/qurani-white-text.png',
            height: 28 * s,
            color: AppColors.getTextInverse(context),
            fit: BoxFit.contain,
          ),

          SizedBox(height: AppDesignSystem.space12 * s),

          // Title
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('premium_offer.upgrade_title'),
                  style: TextStyle(
                    fontSize: 19 * s,
                    fontWeight: AppTypography.bold,
                    color: AppColors.getTextInverse(context),
                    height: 1.0,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== COMPARISON TABLE ====================
  Widget _buildComparisonTable(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space16 * s,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadowLight(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          _buildTableHeader(context),

          // Sections
          _buildSection(
            context,
            title: _t('premium_offer.sections.memorization'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.hide_verses'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.mistake_detection'),
                checkFree: false,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.tashkeel_mistakes'),
                checkFree: false,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.tajweed_mistakes'),
                checkFree: false,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.verse_peeking'),
                checkFree: false,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.mistake_history'),
                checkFree: false,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.mistake_frequency'),
                checkFree: false,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.mistake_playback'),
                checkFree: false,
                checkPremium: true,
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.recitation'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.follow_along'),
                textFree: _t('premium_offer.features.values.unlimited'),
                textPremium: _t('premium_offer.features.values.unlimited'),
              ),
              _FeatureRow(
                _t('premium_offer.features.session_audio'),
                textFree: _t('premium_offer.features.values.last_session'),
                textPremium: _t('premium_offer.features.values.unlimited'),
              ),
              _FeatureRow(
                _t('premium_offer.features.share_audio'),
                textFree: _t('premium_offer.features.values.last_session'),
                textPremium: _t('premium_offer.features.values.unlimited'),
              ),
              _FeatureRow(
                _t('premium_offer.features.session_pausing'),
                checkFree: false,
                checkPremium: true,
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.progress'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.streaks'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.session_history'),
                textFree: _t('premium_offer.features.values.last_session'),
                textPremium: _t('premium_offer.features.values.unlimited'),
              ),
              _FeatureRow(
                _t('premium_offer.features.analytics'),
                textFree: _t('premium_offer.features.values.basic'),
                textPremium: _t('premium_offer.features.values.advanced'),
              ),
              _FeatureRow(
                _t('premium_offer.features.memorization_progress'),
                textFree: _t('premium_offer.features.values.completion'),
                textPremium: _t(
                  'premium_offer.features.values.mistakes_overview',
                ),
              ),
              _FeatureRow(
                _t('premium_offer.features.add_external_sessions'),
                checkFree: false,
                checkPremium: true,
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.challenges'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.goals'),
                textFree: _t('premium_offer.features.values.value_1'),
                textPremium: _t('premium_offer.features.values.unlimited'),
              ),
              _FeatureRow(
                _t('premium_offer.features.badges'),
                textFree: _t('premium_offer.features.values.earn'),
                textPremium: _t('premium_offer.features.values.discover_earn'),
              ),
              _FeatureRow(
                _t('premium_offer.features.notifications'),
                checkFree: false,
                checkPremium: true,
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.audio'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.audio_follow_along'),
                textFree: _t('premium_offer.features.values.ayah_ayah'),
                textPremium: _t('premium_offer.features.values.word_word'),
              ),
              _FeatureRow(
                _t('premium_offer.features.various_recitations'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.repeat_functionality'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.custom_range'),
                checkFree: true,
                checkPremium: true,
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.search'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.voice_search'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.text_search'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.recent_search_history'),
                textFree: _t('premium_offer.features.values.value_3'),
                textPremium: _t('premium_offer.features.values.value_15'),
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.mushaf'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.mushaf_types'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.translations_transliteration'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.tafsir'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.bookmarks'),
                checkFree: true,
                checkPremium: true,
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.devices'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.devices'),
                textFree: _t('premium_offer.features.values.unlimited'),
                textPremium: _t('premium_offer.features.values.unlimited'),
              ),
              _FeatureRow(
                _t('premium_offer.features.cross_device_sync'),
                checkFree: true,
                checkPremium: true,
              ),
              _FeatureRow(
                _t('premium_offer.features.language_support'),
                checkFree: true,
                checkPremium: true,
              ),
            ],
          ),

          _buildSection(
            context,
            title: _t('premium_offer.sections.advertisement'),
            features: [
              _FeatureRow(
                _t('premium_offer.features.advertisement'),
                textFree: _t('premium_offer.features.values.no_ads'),
                textPremium: _t('premium_offer.features.values.no_ads'),
              ),
            ],
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ==================== TABLE HEADER ====================
  Widget _buildTableHeader(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDesignSystem.space16 * s,
        AppDesignSystem.space16 * s,
        AppDesignSystem.space16 * s,
        AppDesignSystem.space12 * s,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.getBorderLight(context),
            width: AppDesignSystem.borderNormal * s,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              _t('premium_offer.compare_premium_features_text'),
              style: TextStyle(
                fontSize: 14 * s,
                fontWeight: AppTypography.medium,
                color: AppColors.getTextTertiary(context),
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                _t('premium_offer.plans.free_text'),
                style: TextStyle(
                  fontSize: 12 * s,
                  fontWeight: AppTypography.bold,
                  color: AppColors.getTextPrimary(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space12 * s,
                  vertical: AppDesignSystem.space6 * s,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.getWarning(context), AppColors.getWarningLight(context)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusRound * s,
                  ),
                ),
                child: Text(
                  _t('premium_offer.plans.premium_text'),
                  style: TextStyle(
                    fontSize: 9 * s,
                    fontWeight: AppTypography.bold,
                    color: AppColors.getTextInverse(context),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SECTION BUILDER ====================
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<_FeatureRow> features,
    bool isLast = false,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppDesignSystem.space12 * s,
            AppDesignSystem.space12 * s,
            AppDesignSystem.space12 * s,
            AppDesignSystem.space10 * s,
          ),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceContainerLowest(context),
            border: Border(
              bottom: BorderSide(
                color: AppColors.getBorderLight(context),
                width: AppDesignSystem.borderNormal * s,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14 * s,
              fontWeight: AppTypography.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ),

        // Features
        ...features.asMap().entries.map((entry) {
          final index = entry.key;
          final feature = entry.value;
          final isLastFeature = index == features.length - 1;

          return _buildFeatureRow(
            context,
            feature: feature,
            showDivider: !isLastFeature || !isLast,
          );
        }).toList(),
      ],
    );
  }

  // ==================== FEATURE ROW ====================
  Widget _buildFeatureRow(
    BuildContext context, {
    required _FeatureRow feature,
    required bool showDivider,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space12 * s,
      ),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.getBorderLight(context),
                  width: AppDesignSystem.borderNormal * s,
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          // Feature Name
          Expanded(
            flex: 5,
            child: Text(
              feature.name,
              style: TextStyle(
                fontSize: 14 * s,
                fontWeight: AppTypography.regular,
                color: AppColors.getTextPrimary(context),
                height: 1.3,
              ),
            ),
          ),

          // Free Column
          Expanded(
            flex: 2,
            child: Center(
              child: _buildFeatureValue(
                context,
                text: feature.textFree,
                hasCheck: feature.checkFree,
              ),
            ),
          ),

          // Premium Column
          Expanded(
            flex: 2,
            child: Center(
              child: _buildFeatureValue(
                context,
                text: feature.textPremium,
                hasCheck: feature.checkPremium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FEATURE VALUE ====================
  Widget _buildFeatureValue(
    BuildContext context, {
    String? text,
    bool hasCheck = false,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    if (hasCheck) {
      return Container(
        width: 24 * s,
        height: 24 * s,
        decoration: BoxDecoration(
          color: AppColors.getSuccess(context).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check, color: AppColors.getSuccess(context), size: 16 * s),
      );
    }

    if (text != null) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 11 * s,
          fontWeight: AppTypography.semiBold,
          color: AppColors.getTextPrimary(context),
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Not available - show empty gray circle container only
    return Container(
      width: 24 * s,
      height: 24 * s,
      decoration: BoxDecoration(
        color: AppColors.getTextPrimary(context).withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
    );
  }

  // ==================== SUBSCRIBE BUTTON ====================
  Widget _buildSubscribeButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDesignSystem.space16 * s,
        AppDesignSystem.space10 * s,
        AppDesignSystem.space16 * s,
        AppDesignSystem.space10 * s,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border(
          top: BorderSide(
            color: AppColors.getBorderLight(context),
            width: AppDesignSystem.borderNormal * s,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadowLight(context),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 52 * s,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.getPrimaryLight(context), AppColors.getPrimaryLight(context)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(
              AppDesignSystem.radiusXXLarge * s,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.getPrimaryLight(context).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                AppHaptics.medium();
                _showSubscriptionDialog(context);
              },
              borderRadius: BorderRadius.circular(
                AppDesignSystem.radiusXXLarge * s,
              ),
              splashColor: AppColors.getTextInverse(context).withValues(alpha: 0.2),
              highlightColor: AppColors.getTextInverse(context).withValues(alpha: 0.1),
              child: Center(
                child: Text(
                  _t('premium_offer.plans.subscribe_button'),
                  style: TextStyle(
                    fontSize: 16 * s,
                    fontWeight: AppTypography.bold,
                    color: AppColors.getTextInverse(context),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== SUBSCRIPTION DIALOG ====================
  void _showSubscriptionDialog(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final premium = context.read<PremiumProvider>();

    // If already premium, show success message
    if (premium.isPremium) {
      _showAlreadyPremiumDialog(context, s);
      return;
    }

    // Show subscription info dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
        ),
        elevation: AppDesignSystem.elevationHigh,
        child: Container(
          padding: AppPadding.all(context, AppDesignSystem.space24),
          decoration: AppComponentStyles.dialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64 * s,
                height: 64 * s,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.getWarning(context).withValues(alpha: 0.2),
                      AppColors.getWarningLight(context).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  color: AppColors.getWarning(context),
                  size: 32 * s,
                ),
              ),

              AppMargin.gap(context),

              // Title
              Text(
                _t('premium_offer.plans.dialog_title'),
                style: AppTypography.h3(context, weight: AppTypography.bold),
                textAlign: TextAlign.center,
              ),

              AppMargin.gapSmall(context),

              // Message
              Text(
                _t('premium_offer.plans.dialog_message'),
                style: AppTypography.body(
                  context,
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              AppMargin.gap(context),

              // Benefits preview
              Container(
                padding: EdgeInsets.all(12 * s),
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceContainerLowest(context),
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusMedium * s,
                  ),
                ),
                child: Column(
                  children: [
                    _buildBenefitItem(
                      context,
                      s,
                      _t('premium_offer.features.mistake_detection'),
                    ),
                    _buildBenefitItem(
                      context,
                      s,
                      _t('premium_offer.features.tajweed_mistakes'),
                    ),
                    _buildBenefitItem(
                      context,
                      s,
                      _t('premium_offer.features.analytics'),
                    ),
                    _buildBenefitItem(
                      context,
                      s,
                      _t('premium_offer.features.goals'),
                    ),
                  ],
                ),
              ),

              AppMargin.gapLarge(context),

              // Button
              AppButton(
                text: _t('premium_offer.plans.dialog_close'),
                onPressed: () => Navigator.pop(context),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(BuildContext context, double s, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * s),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.getSuccess(context),
            size: 16 * s,
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13 * s, color: AppColors.getTextPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlreadyPremiumDialog(BuildContext context, double s) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
        ),
        child: Container(
          padding: AppPadding.all(context, AppDesignSystem.space24),
          decoration: AppComponentStyles.dialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64 * s,
                height: 64 * s,
                decoration: BoxDecoration(
                  color: AppColors.getSuccess(context).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.getSuccess(context),
                  size: 32 * s,
                ),
              ),
              AppMargin.gap(context),
              Text(
                'You\'re Premium!',
                style: AppTypography.h3(context, weight: AppTypography.bold),
                textAlign: TextAlign.center,
              ),
              AppMargin.gapSmall(context),
              Text(
                'You already have access to all premium features. Enjoy!',
                style: AppTypography.body(
                  context,
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              AppMargin.gapLarge(context),
              AppButton(
                text: 'Great!',
                onPressed: () => Navigator.pop(context),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== FEATURE ROW DATA CLASS ====================
class _FeatureRow {
  final String name;
  final String? textFree;
  final String? textPremium;
  final bool checkFree;
  final bool checkPremium;

  _FeatureRow(
    this.name, {
    this.textFree,
    this.textPremium,
    this.checkFree = false,
    this.checkPremium = false,
  });
}
