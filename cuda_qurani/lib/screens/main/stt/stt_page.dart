// lib\screens\main\stt\stt_page.dart

import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/slider_guide_popup.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';

import 'controllers/stt_controller.dart';
import 'services/quran_service.dart';
import 'utils/constants.dart';
import 'widgets/quran_widgets.dart';
import 'widgets/mushaf_view.dart';
import 'widgets/list_view.dart';
import 'widgets/mushaf_paper_background.dart';
import 'widgets/bookmark_drawer.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/widgets/achievement_popup.dart';
import 'package:cuda_qurani/core/widgets/rate_limit_banner.dart';
import 'package:cuda_qurani/screens/main/home/screens/premium_offer_page.dart'; // ✅ NEW: Rate Limit
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/providers/premium_provider.dart'; // ✅ NEW: Premium gating for word colors

class SttPage extends StatefulWidget {
  final int? suratId;
  final int? pageId;
  final int? juzId;
  final bool isFromHistory;
  final Map<String, dynamic>? initialWordStatusMap;
  final String? resumeSessionId; // ✅ NEW: Continue existing session
  final int? highlightAyahId; // ✅ NEW: Deep link highlight

  const SttPage({
    Key? key,
    this.suratId,
    this.pageId,
    this.juzId,
    this.isFromHistory = false,
    this.initialWordStatusMap,
    this.resumeSessionId, // ✅ NEW
    this.highlightAyahId, // ✅ NEW: Deep link highlight
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
          create: (context) {
            final controller = SttController(
              suratId: widget.suratId,
              pageId: widget.pageId,
              juzId: widget.juzId,
              isFromHistory: widget.isFromHistory,
              initialWordStatusMap: widget.initialWordStatusMap,
              resumeSessionId: widget.resumeSessionId, // ✅ NEW
              highlightAyahId: widget.highlightAyahId, // ✅ NEW
            );

            // ✅ NEW: Set SettingsProvider for persistent layout/marking settings
            try {
              final settings = Provider.of<MushafSettingsService>(
                context,
                listen: false,
              );
              controller.setSettingsService(settings);
            } catch (e) {
              print('⚠️ SttPage: MushafSettingsService not found');
            }

            // ✅ NEW: Set PremiumProvider for word color gating
            try {
              final premium = Provider.of<PremiumProvider>(
                context,
                listen: false,
              );
              controller.setPremiumProvider(premium);
            } catch (e) {
              print(
                '⚠️ SttPage: PremiumProvider not found - word colors will default to premium mode',
              );
            }

            Future.microtask(() => controller.initializeApp());
            return controller;
          },
        ),
        Provider(create: (_) => QuranService()),
      ],
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        appBar: const QuranAppBar(),
        endDrawer: Consumer<SttController>(
          builder: (context, controller, _) =>
              BookmarkDrawer(controller: controller),
        ),
        endDrawerEnableOpenDragGesture:
            false, // Prevents accidental swipe-to-open
        body:
            Selector<
              SttController,
              ({String? errorMessage, bool isLoading, bool isOverlayVisible})
            >(
              selector: (_, c) => (
                errorMessage: c.errorMessage,
                isLoading: c.isLoading,
                isOverlayVisible: c.isOverlayVisible,
              ),
              builder: (context, data, _) {
                if (data.isLoading) return const SizedBox.shrink();

                final controller = context.read<SttController>();

                // Handle achievement popup logic - only if not in overlay mode
                if (!data.isOverlayVisible &&
                    controller.newlyEarnedAchievements.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showAchievementPopup(context, controller);
                  });
                }

                if (data.errorMessage?.isNotEmpty ?? false) {
                  return Column(
                    children: [
                      SizedBox(height: kToolbarHeight * 0.86),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.04,
                          vertical: MediaQuery.of(context).size.height * 0.015,
                        ),
                        color: AppColors.getError(
                          context,
                        ).withValues(alpha: 0.9),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: AppColors.textInverse),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data.errorMessage!,
                                style: TextStyle(color: AppColors.textInverse),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: AppColors.textInverse,
                              ),
                              onPressed: controller.clearError,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!controller.isOverlayVisible) {
                              controller.toggleUIVisibility();
                            }
                          },
                          child: Column(
                            children: [
                              Expanded(child: _buildMainContent(context)),
                              Selector<SttController, bool>(
                                selector: (_, c) => c.showLogs && c.isUIVisible,
                                builder: (_, show, __) => show
                                    ? const QuranLogsPanel()
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return GestureDetector(
                  onTap: () {
                    if (!controller.isOverlayVisible) {
                      controller.toggleUIVisibility();
                    }
                  },
                  child: MushafPaperBackground(
                    child: Column(
                      children: [
                        Expanded(child: _buildMainContent(context)),
                        Selector<SttController, bool>(
                          selector: (_, c) => c.showLogs && c.isUIVisible,
                          builder: (_, show, __) => show
                              ? const QuranLogsPanel()
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  // ✅ FIXED: Pass context to ensure Provider is found
  Widget _buildMainContent(BuildContext context) {
    // ✅ PASS context to ensure Provider is found
    // ✅ OPTIMIZATION: Remove blanket Consumer
    // Use select for specific checks to keep Stack stable
    return Stack(
      fit: StackFit.expand, // Force stack to fill available space
      children: [
        // MushafView handles its own listeners
        _buildQuranText(context, context.read<SttController>()),

        // BottomBar handles its own listeners
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: QuranBottomBar(key: ValueKey('quran_bottom_bar')),
        ),

        // Popup handles its own state
        const SliderGuidePopup(),

        // ✅ RATE LIMIT BANNER (Selector)
        Selector<SttController, bool>(
          selector: (_, c) =>
              c.rateLimit != null &&
              c.rateLimitRemaining <= 1 &&
              c.rateLimitRemaining > 0 &&
              !c.isRateLimitExceeded,
          builder: (context, show, _) {
            if (!show) return const SizedBox.shrink();
            final controller = context.read<SttController>();
            return Positioned(
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
            );
          },
        ),

        // ✅ RATE LIMIT EXCEEDED (Selector)
        Selector<SttController, bool>(
          selector: (_, c) => c.isRateLimitExceeded,
          builder: (context, show, _) => show
              ? Positioned.fill(
                  child: RateLimitExceededOverlay(
                    limit: context.read<SttController>().rateLimitMax,
                    resetTime: context
                        .read<SttController>()
                        .rateLimitResetFormatted,
                    plan: context.read<SttController>().rateLimitPlan,
                    onUpgradePressed: () => _navigateToPremium(context),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ✅ DURATION WARNING (Selector)
        Selector<SttController, bool>(
          selector: (_, c) =>
              c.isDurationWarningActive &&
              !c.isDurationLimitExceeded &&
              !c.isDurationUnlimited,
          builder: (context, show, _) => show
              ? Positioned(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: DurationWarningBanner(
                    warningMessage: context
                        .read<SttController>()
                        .durationWarning,
                    onDismiss: () {},
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ✅ DURATION EXCEEDED (Selector)
        Selector<SttController, bool>(
          selector: (_, c) => c.isDurationLimitExceeded,
          builder: (context, show, _) => show
              ? Positioned.fill(
                  child: DurationLimitExceededOverlay(
                    message: context.read<SttController>().durationWarning,
                    onUpgradePressed: () => _navigateToPremium(context),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _navigateToPremium(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PremiumOfferPage()));
  }

  Widget _buildQuranText(BuildContext context, SttController controller) {
    // ✅ OPTIMIZATION: Read only specific properties.
    final isQuranMode = context.select<SttController, bool>(
      (c) => c.isQuranMode,
    );

    // ✅ No horizontal padding - let individual views handle their own

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 100),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: isQuranMode
          ? _buildMushafView(controller)
          : _buildListView(controller),
    );
  }

  Widget _buildMushafView(SttController controller) {
    // ✅ STABLE KEY: Only unique per layout
    // Removing currentPage prevents full widget disposal during swipes
    final uniqueKey = controller.mushafLayout.toStringValue();

    return MushafDisplay(key: ValueKey('mushaf_$uniqueKey'));
  }

  Widget _buildListView(SttController controller) {
    final uniqueKey = controller.mushafLayout.toStringValue();

    return QuranListView(key: ValueKey('list_$uniqueKey'));
  }
}
