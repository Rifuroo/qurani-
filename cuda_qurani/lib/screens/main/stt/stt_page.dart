// lib\screens\main\stt\stt_page.dart

import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/slider_guide_popup.dart';

import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'services/quran_service.dart';
import 'utils/constants.dart';
import 'widgets/quran_widgets.dart';
import 'widgets/mushaf_view.dart';
import 'widgets/list_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/widgets/achievement_popup.dart';
import 'package:cuda_qurani/core/widgets/rate_limit_banner.dart';
import 'package:cuda_qurani/screens/main/home/screens/premium_offer_page.dart';

class SttPage extends StatefulWidget {
  final int? suratId;
  final int? pageId;
  final int? juzId;
  final bool isFromHistory;
  final Map<String, dynamic>? initialWordStatusMap;
  final String? resumeSessionId; // ✅ NEW: Continue existing session

  const SttPage({
    Key? key,
    this.suratId,
    this.pageId,
    this.juzId,
    this.isFromHistory = false,
    this.initialWordStatusMap,
    this.resumeSessionId, // ✅ NEW
  }) : assert(
         (suratId != null ? 1 : 0) +
                 (pageId != null ? 1 : 0) +
                 (juzId != null ? 1 : 0) ==
             1,
         'Exactly one of suratId, pageId, or juzId must be provided',
       ),
       super(key: key);

  @override
  State<SttPage> createState() => _SttPageState();
}

class _SttPageState extends State<SttPage> {
  bool _achievementShown = false;

  void _showAchievementPopup(BuildContext context, SttController controller) {
    if (_achievementShown) return;
    if (controller.newlyEarnedAchievements.isEmpty) return;

    _achievementShown = true;
    final achievement = controller.newlyEarnedAchievements.first;

    AchievementUnlockedDialog.show(
      context,
      emoji: achievement['newly_earned_emoji'] ?? '🏆',
      title: achievement['newly_earned_title'] ?? 'Achievement!',
      subtitle: achievement['newly_earned_code'] ?? '',
    ).then((_) {
      controller.clearNewAchievements();
      _achievementShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final controller = SttController(
              suratId: widget.suratId,
              pageId: widget.pageId,
              juzId: widget.juzId,
              isFromHistory: widget.isFromHistory,
              initialWordStatusMap: widget.initialWordStatusMap,
              resumeSessionId: widget.resumeSessionId, // ✅ NEW
            );
            Future.microtask(() => controller.initializeApp());
            return controller;
          },
        ),
        Provider(create: (_) => QuranService()),
      ],
      child: Consumer<SttController>(
        builder: (context, controller, child) {
          // ✅ NEW: Show achievement popup when earned
          if (controller.newlyEarnedAchievements.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showAchievementPopup(context, controller);
            });
          }

          return Scaffold(
            backgroundColor: backgroundColor,
            extendBodyBehindAppBar: true, // ✅ Key: Body extends behind AppBar
            appBar: const QuranAppBar(),
            body: controller.isLoading
                ? const SizedBox.shrink()
                : (controller.errorMessage?.isNotEmpty ?? false)
                ? Column(
                    children: [
                      // Error banner below AppBar
                      SizedBox(height: kToolbarHeight * 0.86),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.04,
                          vertical: MediaQuery.of(context).size.height * 0.015,
                        ),
                        color: errorColor.withValues(alpha: 0.9),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: MediaQuery.of(context).size.width * 0.05,
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.02,
                            ),
                            Expanded(
                              child: Text(
                                controller.errorMessage ?? 'An error occurred',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.035,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: MediaQuery.of(context).size.width * 0.05,
                              ),
                              onPressed: controller.clearError,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: controller.toggleUIVisibility,
                          child: Column(
                            children: [
                              Expanded(child: _buildMainContent()),
                              if (controller.showLogs && controller.isUIVisible)
                                const QuranLogsPanel(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: controller.toggleUIVisibility,
                    child: Column(
                      children: [
                        Expanded(child: _buildMainContent()),
                        if (controller.showLogs && controller.isUIVisible)
                          const QuranLogsPanel(),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<SttController>(
      builder: (context, controller, child) {
        return Stack(
          children: [
            _buildQuranText(context, controller),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: QuranBottomBar(),
            ),
            // ✅ TAMBAHKAN INI - Popup Guide
            const SliderGuidePopup(),

            // ✅ NEW: Rate Limit Warning Banner (at top)
            if (controller.rateLimit != null &&
                controller.rateLimitRemaining <= 1 &&
                controller.rateLimitRemaining > 0 &&
                !controller.isRateLimitExceeded)
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: RateLimitBanner(
                  current: controller.rateLimitCurrent,
                  limit: controller.rateLimitMax,
                  remaining: controller.rateLimitRemaining,
                  resetTime: controller.rateLimitResetFormatted,
                  plan: controller.rateLimitPlan,
                  isExceeded: false,
                  onUpgradePressed: () => _navigateToPremium(context),
                ),
              ),

            // ✅ NEW: Rate Limit Exceeded Overlay (full screen)
            if (controller.isRateLimitExceeded)
              Positioned.fill(
                child: RateLimitExceededOverlay(
                  limit: controller.rateLimitMax,
                  resetTime: controller.rateLimitResetFormatted,
                  plan: controller.rateLimitPlan,
                  onUpgradePressed: () => _navigateToPremium(context),
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),

            // ⏳ NEW: Duration Warning Banner (3 menit tersisa)
            if (controller.isDurationWarningActive &&
                !controller.isDurationLimitExceeded &&
                !controller.isDurationUnlimited)
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: DurationWarningBanner(
                  warningMessage: controller.durationWarning,
                  onDismiss: () {
                    // Optional: dismiss warning
                  },
                ),
              ),

            // // 🚨 NEW: Surah Mismatch Warning Banner
            // if (controller.isSurahMismatch && controller.surahMismatchWarning != null)
            //   Positioned(
            //     top: kToolbarHeight + MediaQuery.of(context).padding.top,
            //     left: 0,
            //     right: 0,
            //     child: SurahMismatchBanner(
            //       warningMessage: controller.surahMismatchWarning!,
            //       detectedSurahName: controller.detectedMismatchSurahName,
            //       onDismiss: () {
            //         // Will auto-dismiss after 10 seconds
            //       },
            //     ),
            //   ),

            // ⏳ NEW: Duration Limit Exceeded Overlay
            if (controller.isDurationLimitExceeded)
              Positioned.fill(
                child: DurationLimitExceededOverlay(
                  message: controller.durationWarning,
                  onUpgradePressed: () => _navigateToPremium(context),
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        );
      },
    );
  }

  void _navigateToPremium(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PremiumOfferPage()));
  }

  Widget _buildQuranText(BuildContext context, SttController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.03;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: controller.isQuranMode
            ? _buildMushafView(controller) // ✅ UBAH: Dynamic widget
            : _buildListView(controller), // ✅ UBAH: Dynamic widget
      ),
    );
  }

  Widget _buildMushafView(SttController controller) {
    // ✅ Key UNIK per layout untuk force rebuild saat switch
    final uniqueKey =
        '${controller.mushafLayout.toStringValue()}_${controller.currentPage}';

    return MushafDisplay(key: ValueKey('mushaf_$uniqueKey'));
  }

  Widget _buildListView(SttController controller) {
    // ✅ Key UNIK per layout untuk force rebuild saat switch
    final uniqueKey =
        '${controller.mushafLayout.toStringValue()}_${controller.listViewCurrentPage}';

    return QuranListView(key: ValueKey('list_$uniqueKey'));
  }
}
