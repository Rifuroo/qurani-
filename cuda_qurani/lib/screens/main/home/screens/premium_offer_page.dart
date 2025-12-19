// lib/screens/main/home/screens/premium_offer_page.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';
import 'package:cuda_qurani/services/in_app_purchase_service.dart';

class PremiumOfferPage extends StatefulWidget {
  const PremiumOfferPage({super.key});

  @override
  State<PremiumOfferPage> createState() => _PremiumOfferPageState();
}

class _PremiumOfferPageState extends State<PremiumOfferPage> {
  final ScrollController _scrollController = ScrollController();
  final InAppPurchaseService _iapService = InAppPurchaseService();
  Map<String, dynamic> _translations = {};
  bool _isPurchasing = false;
  int _selectedPlanIndex = 1; // Default: yearly (index 1)

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    await _iapService.initialize();

    _iapService.onPurchaseSuccess = (purchase) {
      setState(() => _isPurchasing = false);
      _onPurchaseSuccess(purchase);
    };

    _iapService.onPurchaseError = (error) {
      setState(() => _isPurchasing = false);
      _showSnackbar(error, isError: true);
    };

    _iapService.onPurchasePending = () {
      _showSnackbar('Pembelian sedang diproses...');
    };

    _iapService.onPurchaseRestored = () {
      final premium = context.read<PremiumProvider>();
      premium.setPlan('premium');
      _showSnackbar('Pembelian berhasil dipulihkan!');
    };
    
    // DUMMY: Callback untuk dummy purchase - HAPUS SETELAH SETUP PLAY CONSOLE
    _iapService.onDummyPurchaseSuccess = (productId) {
      setState(() => _isPurchasing = false);
      _onDummyPurchaseSuccess(productId);
    };

    setState(() {});
  }
  
  // DUMMY: Handle dummy purchase success - HAPUS SETELAH SETUP PLAY CONSOLE
  void _onDummyPurchaseSuccess(String productId) {
    final premium = context.read<PremiumProvider>();
    premium.setPlan('premium');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildSuccessDialog(ctx),
    );
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('home/premium');
    setState(() => _translations = trans);
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

  void _onPurchaseSuccess(PurchaseDetails purchase) {
    final premium = context.read<PremiumProvider>();
    premium.setPlan('premium');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildSuccessDialog(ctx),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.getError(context)
            : AppColors.getPrimaryLight(context),
      ),
    );
  }

  Widget _buildSuccessDialog(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return Dialog(
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
              _t('premium_offer.plans.success_title'),
              style: AppTypography.h3(context, weight: AppTypography.bold),
              textAlign: TextAlign.center,
            ),
            AppMargin.gapSmall(context),
            Text(
              _t('premium_offer.plans.success_message'),
              style: AppTypography.body(
                context,
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            AppMargin.gapLarge(context),
            AppButton(
              text: _t('premium_offer.plans.success_button'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getSurfaceVariant(context),
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
                    height: AppDesignSystem.space80 *
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
          Image.asset(
            'assets/images/qurani-white-text.png',
            height: 28 * s,
            color: AppColors.getTextInverse(context),
            fit: BoxFit.contain,
          ),
          SizedBox(height: AppDesignSystem.space12 * s),
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
          _buildTableHeader(context),
          _buildSection(context,
              title: _t('premium_offer.sections.memorization'),
              features: [
                _FeatureRow(_t('premium_offer.features.hide_verses'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.mistake_detection'),
                    checkFree: false, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.tashkeel_mistakes'),
                    checkFree: false, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.tajweed_mistakes'),
                    checkFree: false, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.verse_peeking'),
                    checkFree: false, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.mistake_history'),
                    checkFree: false, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.mistake_frequency'),
                    checkFree: false, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.mistake_playback'),
                    checkFree: false, checkPremium: true),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.recitation'),
              features: [
                _FeatureRow(_t('premium_offer.features.follow_along'),
                    textFree: _t('premium_offer.features.values.unlimited'),
                    textPremium: _t('premium_offer.features.values.unlimited')),
                _FeatureRow(_t('premium_offer.features.session_audio'),
                    textFree: _t('premium_offer.features.values.last_session'),
                    textPremium: _t('premium_offer.features.values.unlimited')),
                _FeatureRow(_t('premium_offer.features.share_audio'),
                    textFree: _t('premium_offer.features.values.last_session'),
                    textPremium: _t('premium_offer.features.values.unlimited')),
                _FeatureRow(_t('premium_offer.features.session_pausing'),
                    checkFree: false, checkPremium: true),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.progress'),
              features: [
                _FeatureRow(_t('premium_offer.features.streaks'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.session_history'),
                    textFree: _t('premium_offer.features.values.last_session'),
                    textPremium: _t('premium_offer.features.values.unlimited')),
                _FeatureRow(_t('premium_offer.features.analytics'),
                    textFree: _t('premium_offer.features.values.basic'),
                    textPremium: _t('premium_offer.features.values.advanced')),
                _FeatureRow(_t('premium_offer.features.memorization_progress'),
                    textFree: _t('premium_offer.features.values.completion'),
                    textPremium:
                        _t('premium_offer.features.values.mistakes_overview')),
                _FeatureRow(_t('premium_offer.features.add_external_sessions'),
                    checkFree: false, checkPremium: true),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.challenges'),
              features: [
                _FeatureRow(_t('premium_offer.features.goals'),
                    textFree: _t('premium_offer.features.values.value_1'),
                    textPremium: _t('premium_offer.features.values.unlimited')),
                _FeatureRow(_t('premium_offer.features.badges'),
                    textFree: _t('premium_offer.features.values.earn'),
                    textPremium:
                        _t('premium_offer.features.values.discover_earn')),
                _FeatureRow(_t('premium_offer.features.notifications'),
                    checkFree: false, checkPremium: true),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.audio'),
              features: [
                _FeatureRow(_t('premium_offer.features.audio_follow_along'),
                    textFree: _t('premium_offer.features.values.ayah_ayah'),
                    textPremium: _t('premium_offer.features.values.word_word')),
                _FeatureRow(_t('premium_offer.features.various_recitations'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.repeat_functionality'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.custom_range'),
                    checkFree: true, checkPremium: true),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.search'),
              features: [
                _FeatureRow(_t('premium_offer.features.voice_search'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.text_search'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.recent_search_history'),
                    textFree: _t('premium_offer.features.values.value_3'),
                    textPremium: _t('premium_offer.features.values.value_15')),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.mushaf'),
              features: [
                _FeatureRow(_t('premium_offer.features.mushaf_types'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(
                    _t('premium_offer.features.translations_transliteration'),
                    checkFree: true,
                    checkPremium: true),
                _FeatureRow(_t('premium_offer.features.tafsir'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.bookmarks'),
                    checkFree: true, checkPremium: true),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.devices'),
              features: [
                _FeatureRow(_t('premium_offer.features.devices'),
                    textFree: _t('premium_offer.features.values.unlimited'),
                    textPremium: _t('premium_offer.features.values.unlimited')),
                _FeatureRow(_t('premium_offer.features.cross_device_sync'),
                    checkFree: true, checkPremium: true),
                _FeatureRow(_t('premium_offer.features.language_support'),
                    checkFree: true, checkPremium: true),
              ]),
          _buildSection(context,
              title: _t('premium_offer.sections.advertisement'),
              features: [
                _FeatureRow(_t('premium_offer.features.advertisement'),
                    textFree: _t('premium_offer.features.values.no_ads'),
                    textPremium: _t('premium_offer.features.values.no_ads')),
              ],
              isLast: true),
        ],
      ),
    );
  }

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
                    colors: [
                      AppColors.getWarning(context),
                      AppColors.getWarningLight(context)
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusRound * s),
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
        ...features.asMap().entries.map((entry) {
          final index = entry.key;
          final feature = entry.value;
          final isLastFeature = index == features.length - 1;
          return _buildFeatureRow(context,
              feature: feature, showDivider: !isLastFeature || !isLast);
        }),
      ],
    );
  }

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
          Expanded(
            flex: 2,
            child: Center(
              child: _buildFeatureValue(context,
                  text: feature.textFree, hasCheck: feature.checkFree),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _buildFeatureValue(context,
                  text: feature.textPremium, hasCheck: feature.checkPremium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureValue(BuildContext context,
      {String? text, bool hasCheck = false}) {
    final s = AppDesignSystem.getScaleFactor(context);

    if (hasCheck) {
      return Container(
        width: 24 * s,
        height: 24 * s,
        decoration: BoxDecoration(
          color: AppColors.getSuccess(context).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check,
            color: AppColors.getSuccess(context), size: 16 * s),
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

    return Container(
      width: 24 * s,
      height: 24 * s,
      decoration: BoxDecoration(
        color: AppColors.getTextPrimary(context).withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
    );
  }

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
              colors: [
                AppColors.getPrimaryLight(context),
                AppColors.getPrimaryLight(context)
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius:
                BorderRadius.circular(AppDesignSystem.radiusXXLarge * s),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.getPrimaryLight(context).withValues(alpha: 0.3),
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
                _showSubscriptionSheet(context);
              },
              borderRadius:
                  BorderRadius.circular(AppDesignSystem.radiusXXLarge * s),
              splashColor:
                  AppColors.getTextInverse(context).withValues(alpha: 0.2),
              highlightColor:
                  AppColors.getTextInverse(context).withValues(alpha: 0.1),
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

  void _showSubscriptionSheet(BuildContext context) {
    final premium = context.read<PremiumProvider>();

    if (premium.isPremium) {
      _showAlreadyPremiumDialog(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubscriptionSheet(
        iapService: _iapService,
        selectedIndex: _selectedPlanIndex,
        isPurchasing: _isPurchasing,
        onSelectPlan: (index) => setState(() => _selectedPlanIndex = index),
        onPurchase: (product) => _handlePurchase(product),
        // DUMMY: Tambahan callback untuk dummy - HAPUS SETELAH SETUP PLAY CONSOLE
        onDummyPurchase: (product) => _handleDummyPurchase(product),
        onRestore: () => _handleRestore(),
      ),
    );
  }

  Future<void> _handlePurchase(ProductDetails product) async {
    setState(() => _isPurchasing = true);
    Navigator.pop(context); // Close bottom sheet
    await _iapService.buySubscription(product);
  }
  
  // DUMMY: Handle dummy purchase - HAPUS SETELAH SETUP PLAY CONSOLE
  Future<void> _handleDummyPurchase(DummyProductDetails product) async {
    setState(() => _isPurchasing = true);
    Navigator.pop(context); // Close bottom sheet
    await _iapService.buyDummySubscription(product);
  }

  Future<void> _handleRestore() async {
    Navigator.pop(context);
    _showSnackbar(_t('premium_offer.plans.restoring'));
    await _iapService.restorePurchases();
  }

  void _showAlreadyPremiumDialog(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
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
                child: Icon(Icons.check_circle,
                    color: AppColors.getSuccess(context), size: 32 * s),
              ),
              AppMargin.gap(context),
              Text(
                _t('premium_offer.plans.already_premium_title'),
                style: AppTypography.h3(context, weight: AppTypography.bold),
                textAlign: TextAlign.center,
              ),
              AppMargin.gapSmall(context),
              Text(
                _t('premium_offer.plans.already_premium_message'),
                style: AppTypography.body(context,
                    color: AppColors.getTextSecondary(context)),
                textAlign: TextAlign.center,
              ),
              AppMargin.gapLarge(context),
              AppButton(
                text: _t('premium_offer.plans.ok'),
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

// ==================== SUBSCRIPTION SHEET ====================
class _SubscriptionSheet extends StatefulWidget {
  final InAppPurchaseService iapService;
  final int selectedIndex;
  final bool isPurchasing;
  final Function(int) onSelectPlan;
  final Function(ProductDetails) onPurchase;
  // DUMMY: Callback untuk dummy purchase - HAPUS SETELAH SETUP PLAY CONSOLE
  final Function(DummyProductDetails) onDummyPurchase;
  final VoidCallback onRestore;

  const _SubscriptionSheet({
    required this.iapService,
    required this.selectedIndex,
    required this.isPurchasing,
    required this.onSelectPlan,
    required this.onPurchase,
    required this.onDummyPurchase,
    required this.onRestore,
  });

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final products = widget.iapService.products;
    final dummyProducts = widget.iapService.dummyProducts;
    final useDummy = widget.iapService.useDummy;

    return Container(
      padding: EdgeInsets.fromLTRB(20 * s, 24 * s, 20 * s, 32 * s),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.radiusXLarge * s),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40 * s,
            height: 4 * s,
            decoration: BoxDecoration(
              color: AppColors.getBorderLight(context),
              borderRadius: BorderRadius.circular(2 * s),
            ),
          ),
          SizedBox(height: 20 * s),

          // Title
          Text(
            'Pilih Paket Premium',
            style: TextStyle(
              fontSize: 20 * s,
              fontWeight: AppTypography.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          SizedBox(height: 20 * s),

          // DUMMY: Tampilkan dummy products jika real products kosong - HAPUS SETELAH SETUP PLAY CONSOLE
          if (useDummy)
            ...dummyProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return _buildDummyProductCard(context, s, product, index);
            })
          else if (products.isNotEmpty)
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return _buildProductCard(context, s, product, index);
            })
          else
            _buildNoProductsState(context, s),

          SizedBox(height: 16 * s),

          // Purchase button
          SizedBox(
            width: double.infinity,
            height: 52 * s,
            child: ElevatedButton(
              // DUMMY: Support both real and dummy purchase - HAPUS useDummy SETELAH SETUP PLAY CONSOLE
              onPressed: (products.isNotEmpty || useDummy) && !widget.isPurchasing
                  ? () {
                      if (useDummy) {
                        widget.onDummyPurchase(dummyProducts[_selectedIndex]);
                      } else {
                        widget.onPurchase(products[_selectedIndex]);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimaryLight(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.getPrimaryLight(context).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusXXLarge * s),
                ),
                elevation: 0,
              ),
              child: widget.isPurchasing
                  ? SizedBox(
                      width: 24 * s,
                      height: 24 * s,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      'Berlangganan Sekarang',
                      style: TextStyle(
                        fontSize: 16 * s,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
            ),
          ),

          SizedBox(height: 12 * s),

          // Restore purchases
          TextButton(
            onPressed: widget.onRestore,
            child: Text(
              'Pulihkan Pembelian',
              style: TextStyle(
                fontSize: 14 * s,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ),

          // Terms
          Text(
            'Dengan berlangganan, kamu menyetujui Syarat & Ketentuan',
            style: TextStyle(
              fontSize: 11 * s,
              color: AppColors.getTextTertiary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoProductsState(BuildContext context, double s) {
    final error = widget.iapService.error;
    final isLoading = widget.iapService.isLoading;

    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40 * s),
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      padding: EdgeInsets.all(20 * s),
      margin: EdgeInsets.only(bottom: 12 * s),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLowest(context),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        border: Border.all(color: AppColors.getBorderLight(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline,
              size: 40 * s, color: AppColors.getTextTertiary(context)),
          SizedBox(height: 12 * s),
          Text(
            error ?? 'Produk tidak tersedia saat ini',
            style: TextStyle(
              fontSize: 14 * s,
              color: AppColors.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context, double s, ProductDetails product, int index) {
    final isSelected = _selectedIndex == index;
    final isYearly = product.id == IAPProductIds.premiumYearly;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        widget.onSelectPlan(index);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12 * s),
        padding: EdgeInsets.all(16 * s),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.getPrimaryLight(context).withValues(alpha: 0.1)
              : AppColors.getSurfaceContainerLowest(context),
          borderRadius:
              BorderRadius.circular(AppDesignSystem.radiusMedium * s),
          border: Border.all(
            color: isSelected
                ? AppColors.getPrimaryLight(context)
                : AppColors.getBorderLight(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24 * s,
              height: 24 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.getPrimaryLight(context)
                      : AppColors.getBorderLight(context),
                  width: 2,
                ),
                color: isSelected
                    ? AppColors.getPrimaryLight(context)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 16 * s)
                  : null,
            ),
            SizedBox(width: 12 * s),

            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        product.title.replaceAll('(Qurani)', '').trim(),
                        style: TextStyle(
                          fontSize: 15 * s,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      if (isYearly) ...[
                        SizedBox(width: 8 * s),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8 * s, vertical: 2 * s),
                          decoration: BoxDecoration(
                            color: AppColors.getSuccess(context),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                          child: Text(
                            'HEMAT 40%',
                            style: TextStyle(
                              fontSize: 9 * s,
                              fontWeight: AppTypography.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: 12 * s,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              product.price,
              style: TextStyle(
                fontSize: 15 * s,
                fontWeight: AppTypography.bold,
                color: AppColors.getPrimaryLight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DUMMY PRODUCT CARD - HAPUS METHOD INI SETELAH SETUP GOOGLE PLAY CONSOLE
  // ============================================================================
  Widget _buildDummyProductCard(
      BuildContext context, double s, DummyProductDetails product, int index) {
    final isSelected = _selectedIndex == index;
    final isYearly = product.id == IAPProductIds.premiumYearly;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        widget.onSelectPlan(index);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12 * s),
        padding: EdgeInsets.all(16 * s),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.getPrimaryLight(context).withValues(alpha: 0.1)
              : AppColors.getSurfaceContainerLowest(context),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
          border: Border.all(
            color: isSelected
                ? AppColors.getPrimaryLight(context)
                : AppColors.getBorderLight(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24 * s,
              height: 24 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.getPrimaryLight(context)
                      : AppColors.getBorderLight(context),
                  width: 2,
                ),
                color: isSelected
                    ? AppColors.getPrimaryLight(context)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 16 * s)
                  : null,
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        product.title,
                        style: TextStyle(
                          fontSize: 15 * s,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      if (isYearly) ...[
                        SizedBox(width: 8 * s),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8 * s, vertical: 2 * s),
                          decoration: BoxDecoration(
                            color: AppColors.getSuccess(context),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                          child: Text(
                            'HEMAT 40%',
                            style: TextStyle(
                              fontSize: 9 * s,
                              fontWeight: AppTypography.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: 12 * s,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              product.price,
              style: TextStyle(
                fontSize: 15 * s,
                fontWeight: AppTypography.bold,
                color: AppColors.getPrimaryLight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ============================================================================
  // END DUMMY PRODUCT CARD
  // ============================================================================
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
