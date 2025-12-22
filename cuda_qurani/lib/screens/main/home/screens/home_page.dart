// lib/screens/main/home/screens/home_page.dart

import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/screens/main/home/screens/all_session_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/achievement_page.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/providers/auth_provider.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/services/auth_service.dart';
import 'package:cuda_qurani/screens/main/stt/stt_page.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/providers/premium_provider.dart'; // ✅ NEW: Premium gating
import 'package:cuda_qurani/models/premium_features.dart'; // ✅ NEW: Premium features
import 'package:cuda_qurani/screens/main/home/screens/premium_offer_page.dart'; // ✅ NEW

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('home/home');
    setState(() {
      _translations = trans;
    });
  }

  String _t(String key) {
    return _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, key)
        : key.split('.').last;
  }

  // Stats data - fetched from database
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _versesRecited = 0;
  int _completionPercentage = 0;
  int _memorizedPercentage = 0;
  String _engagementTime = "0:00:00";
  // ignore: unused_field
  bool _isLoadingStats = true;

  // Today's Goal data
  String _goalType = 'verses';
  int _goalTarget = 1;
  int _goalCurrent = 0;
  bool _goalCompleted = false;
  bool _hasGoal = false;

  // Recent badges for preview
  List<Map<String, dynamic>> _recentBadges = [];
  int _earnedBadgesCount = 0;
  int _totalBadgesCount = 0;

  // Continue Reading & Recent Progress
  // ignore: unused_field
  Map<String, dynamic>? _continueReading;
  List<Map<String, dynamic>> _recentProgress = [];

  // Backend integration
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _latestSession;
  bool _isLoadingSession = true;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _loadHomePageData();
    // ✅ OPTIMIZATION: Only load session for PREMIUM users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final premium = context.read<PremiumProvider>();
      if (premium.canAccess(PremiumFeature.sessionResume)) {
        _loadLatestSession();
      } else {
        setState(() => _isLoadingSession = false); // Skip for FREE
      }
    });
  }

  /// OPTIMIZED: Load ALL home page data in ONE call
  Future<void> _loadHomePageData() async {
    final userUuid = _authService.userId;
    if (userUuid == null) {
      if (mounted) setState(() => _isLoadingStats = false);
      return;
    }

    try {
      final data = await _supabaseService.getHomePageData(userUuid);

      if (!mounted) return;

      if (data != null) {
        // Parse streak
        final streak = data['streak'] as Map<String, dynamic>? ?? {};
        _currentStreak = streak['current'] ?? 0;
        _longestStreak = streak['longest'] ?? 0;

        // Parse stats
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        _versesRecited = stats['total_ayahs_read'] ?? 0;
        final totalSeconds = stats['total_time_seconds'] ?? 0;
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;
        _engagementTime =
            '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        _completionPercentage = ((_versesRecited / 6236) * 100).round();

        // Parse today's goal
        final goal = data['today_goal'] as Map<String, dynamic>?;
        if (goal != null) {
          _goalType = goal['goal_type'] ?? 'verses';
          _goalTarget = goal['target_value'] ?? 1;
          _goalCurrent = goal['current_value'] ?? 0;
          _goalCompleted = goal['is_completed'] ?? false;
          _hasGoal = goal['has_goal'] ?? false;
        }

        // Parse recent badges
        final badges = data['recent_badges'] as List? ?? [];
        _recentBadges = badges
            .map((b) => Map<String, dynamic>.from(b))
            .toList();

        // Parse badges count
        final badgesCount = data['badges_count'] as Map<String, dynamic>? ?? {};
        _earnedBadgesCount = badgesCount['earned'] ?? 0;
        _totalBadgesCount = badgesCount['total'] ?? 0;

        // Parse continue reading
        final continueReading =
            data['continue_reading'] as Map<String, dynamic>?;
        _continueReading = continueReading;

        // Parse recent progress
        final recentProgress = data['recent_progress'] as List? ?? [];
        _recentProgress = recentProgress
            .map((p) => Map<String, dynamic>.from(p))
            .toList();

        setState(() => _isLoadingStats = false);
        print(
          '✅ HOME: Data loaded - streak: $_currentStreak, badges: $_earnedBadgesCount/$_totalBadgesCount, progress: ${_recentProgress.length} surahs',
        );
      } else {
        setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  /// Load latest resumable session from backend
  Future<void> _loadLatestSession() async {
    if (!_authService.isAuthenticated) {
      if (mounted) setState(() => _isLoadingSession = false);
      return;
    }

    final userUuid = _authService.userId;

    if (userUuid == null) {
      if (mounted) setState(() => _isLoadingSession = false);
      return;
    }

    try {
      final session = await _supabaseService.getResumableSession(userUuid);

      if (!mounted) return;

      setState(() {
        _latestSession = session;
        _isLoadingSession = false;
      });
    } catch (e) {
      print('❌ HOME: Error loading latest session: $e');
      if (mounted) setState(() => _isLoadingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getSurfaceVariant(context),
      appBar: const MenuAppBar(selectedIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAllData,
          color: AppColors.getPrimary(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: AppPadding.section(context),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildGreetingHeader(context),
                    AppMargin.gapLarge(context),
                    _buildLatestSession(context),
                    AppMargin.gapXLarge(context),
                    _buildStreakSection(context),
                    AppMargin.gapXLarge(context),
                    _buildProgressSection(context),
                    AppMargin.gapXLarge(context),
                    _buildTodayGoal(context),
                    AppMargin.gapXLarge(context),
                    _buildAchievements(context),
                    AppMargin.customGap(context, AppDesignSystem.space40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== GREETING HEADER ====================
  Widget _buildGreetingHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    String displayName = _t('home.user_text');
    if (user != null) {
      if (user.fullName != null && user.fullName!.isNotEmpty) {
        displayName = user.fullName!;
      } else {
        displayName = user.email.split('@')[0];
        if (displayName.isNotEmpty) {
          displayName = displayName[0].toUpperCase() + displayName.substring(1);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          style: AppTypography.h1(
            context,
            weight: AppTypography.bold,
            color: AppColors.getTextPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        AppMargin.gapSmall(context),
        Text(
          _getGreeting(),
          style: AppTypography.caption(
            context,
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final goodText = _t('home.greeting_text');

    if (hour < 12) {
      return '$goodText ${_t('home.morning')}';
    }
    if (hour < 17) {
      return '$goodText ${_t('home.afternoon')}';
    }
    return '$goodText ${_t('home.evening')}';
  }

  // ==================== LATEST SESSION CARD ====================
  Widget _buildLatestSession(BuildContext context) {
    final premium = context.watch<PremiumProvider>();

    // ✅ FREE USER: Show locked placeholder (no session data loaded)
    if (!premium.canAccess(PremiumFeature.sessionResume)) {
      return _buildLockedSessionCard(context);
    }

    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isArabic = languageProvider.currentLanguageCode == 'ar';

    if (_isLoadingSession) {
      return Container(
        padding: AppPadding.card(context),
        decoration: AppComponentStyles.card(
          color: AppColors.getSurface(context),
          borderRadius: AppDesignSystem.radiusLarge,
          borderColor: AppColors.getBorderLight(context),
          borderWidth: AppDesignSystem.borderNormal,
          shadow: true,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_latestSession == null) {
      return Container(
        padding: AppPadding.card(context),
        decoration: AppComponentStyles.card(
          color: AppColors.getSurface(context),
          borderRadius: AppDesignSystem.radiusLarge,
          borderColor: AppColors.getBorderLight(context),
          borderWidth: AppDesignSystem.borderNormal,
          shadow: true,
        ),
        child: Column(
          children: [
            Icon(
              Icons.book_outlined,
              size: 48,
              color: AppColors.getTextTertiary(context),
            ),
            AppMargin.gapSmall(context),
            Text(
              _t('home.no_recent_session_text'),
              style: AppTypography.body(
                context,
                color: AppColors.getTextTertiary(context),
              ),
            ),
            AppMargin.gapSmall(context),
            Text(
              _t('home.start_first_recitation_text'),
              style: AppTypography.caption(
                context,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    final surahId = _latestSession!['surah_id'] ?? 0;
    // ✅ Logic: If Arabic, use name_arabic, else use name_simple
    final surahName = isArabic
        ? (_latestSession!['name_arabic'] ??
              _latestSession!['surah_name'] ??
              '${_t('home.surah_text')} ${context.formatNumber(surahId)}')
        : (_latestSession!['surah_name'] ??
              '${_t('home.surah_text')} ${context.formatNumber(surahId)}');
    final totalAyahs = _latestSession!['total_ayahs'] ?? 0;
    final ayah = _latestSession!['ayah'] ?? 0;
    final position = _latestSession!['position'] ?? 0;
    final status = _latestSession!['status'] ?? 'unknown';
    final updatedAt = _latestSession!['updated_at'] ?? '';

    // Calculate time ago with translations
    String timeAgo = _t('home.just_now_text');
    try {
      final updated = DateTime.parse(updatedAt);
      final diff = DateTime.now().difference(updated);
      if (diff.inMinutes < 60) {
        final mins = diff.inMinutes;
        timeAgo =
            '${context.formatNumber(mins)} ${mins > 1 ? _t('home.minutes_text') : _t('home.minute_text')} ${_t('home.ago_text')}';
      } else if (diff.inHours < 24) {
        final hrs = diff.inHours;
        timeAgo =
            '${context.formatNumber(hrs)} ${hrs > 1 ? _t('home.hours_text') : _t('home.hour_text')} ${_t('home.ago_text')}';
      } else {
        final dys = diff.inDays;
        timeAgo =
            '${context.formatNumber(dys)} ${dys > 1 ? _t('home.days_text') : _t('home.day_text')} ${_t('home.ago_text')}';
      }
    } catch (e) {
      // Keep default
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          _resumeSession();
        },
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
        splashColor: AppComponentStyles.rippleColor,
        highlightColor: AppComponentStyles.hoverColor,
        child: Container(
          padding: AppPadding.card(context),
          decoration: AppComponentStyles.card(
            color: AppColors.getSurface(context),
            borderRadius: AppDesignSystem.radiusLarge,
            borderColor: AppColors.getBorderLight(context),
            borderWidth: AppDesignSystem.borderNormal,
            shadow: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppDesignSystem.space6,
                        height: AppDesignSystem.space6,
                        decoration: BoxDecoration(
                          color: status == 'paused'
                              ? AppColors.getWarning(context)
                              : AppColors.getPrimary(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                      AppMargin.gapHSmall(context),
                      Text(
                        status == 'paused'
                            ? _t('home.paused_Session_text').toUpperCase()
                            : _t('home.latest_Session_text').toUpperCase(),
                        style: AppTypography.overline(
                          context,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        AppHaptics.light();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllSessionPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusSmall,
                      ),
                      child: Padding(
                        padding: AppPadding.all(
                          context,
                          AppDesignSystem.space4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              _t('home.see_all_text'),
                              style: AppTypography.caption(
                                context,
                                weight: AppTypography.semiBold,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            AppMargin.customGapH(
                              context,
                              AppDesignSystem.space4,
                            ),
                            Icon(
                              Icons.history_rounded,
                              size: AppDesignSystem.iconSmall,
                              color: AppColors.getTextTertiary(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AppMargin.gap(context),
              // Surah Title
              Text(
                surahName,
                style: AppTypography.h2(
                  context,
                  weight: AppTypography.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              AppMargin.gapSmall(context),
              Text(
                '${_t('home.ayah_text')} ${context.formatNumber(ayah)}${totalAyahs > 0 ? '/${context.formatNumber(totalAyahs)}' : ''}, ${_t('home.word_text')} ${context.formatNumber(position + 1)} · $timeAgo',
                style: AppTypography.caption(
                  context,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              AppMargin.gap(context),
              // Continue Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    AppHaptics.medium();
                    _resumeSession();
                  },
                  style: AppComponentStyles.secondaryButton(context).copyWith(
                    side: WidgetStateProperty.all(
                      BorderSide(
                        color: AppColors.getTextPrimary(context),
                        width: AppDesignSystem.borderThick,
                      ),
                    ),
                  ),
                  child: Text(
                    _t('home.continue_reading_text'),
                    style: AppTypography.label(
                      context,
                      color: AppColors.getTextPrimary(context),
                      weight: AppTypography.semiBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Locked session card for FREE users - no data fetch
  Widget _buildLockedSessionCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PremiumOfferPage())),
      child: Container(
        padding: AppPadding.card(context),
        decoration: AppComponentStyles.card(
          // ✅ FIX: Use surface color instead of transparent text color for background
          color: AppColors.getSurface(context),
          borderRadius: AppDesignSystem.radiusLarge,
          borderColor: AppColors.getBorderLight(context),
          borderWidth: AppDesignSystem.borderNormal,
          shadow: true,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getWarning(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                color: AppColors.getWarning(context),
                size: 28,
              ),
            ),
            AppMargin.gap(context),
            Text(
              _t('home.resume_session_text'),
              style: AppTypography.h3(
                context,
                weight: AppTypography.bold,
                color: AppColors.getTextPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            AppMargin.gapSmall(context),
            Text(
              _t('home.premium_feature_text'),
              style: AppTypography.body(
                context,
                color: AppColors.getWarning(context),
              ),
            ),
            AppMargin.gap(context),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.getWarning(context)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _t('home.upgrade_to_premium_text'),
                style: AppTypography.label(
                  context,
                  color: AppColors.getWarning(context),
                  weight: AppTypography.semiBold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Refresh all data (for pull-to-refresh and auto-refresh)
  Future<void> _refreshAllData() async {
    setState(() => _isLoadingStats = true);
    await Future.wait([_loadHomePageData(), _loadLatestSession()]);
  }

  /// Resume session action
  Future<void> _resumeSession() async {
    if (_latestSession == null) return;

    try {
      final surahId = _latestSession!['surah_id'] as int;
      final ayah = _latestSession!['ayah'] as int?;
      final position = _latestSession!['position'] as int?;
      final sessionId = _latestSession!['session_id'] as String?;

      Map<String, dynamic>? wordStatusMap;
      if (_latestSession!['data'] != null &&
          _latestSession!['data']['word_status_map'] != null) {
        wordStatusMap = Map<String, dynamic>.from(
          _latestSession!['data']['word_status_map'],
        );
      }

      print('▶️ Navigating to resume session:');
      print('   Surah: $surahId');
      print('   Ayah: $ayah');
      print('   Position: $position');
      print('   Session ID: $sessionId');
      print('   Word status map: ${wordStatusMap?.keys.length ?? 0} ayahs');

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SttPage(
            suratId: surahId,
            isFromHistory: true,
            initialWordStatusMap: wordStatusMap,
            resumeSessionId: sessionId,
          ),
        ),
      );

      if (mounted) {
        print('🔄 HOME: Auto-refreshing after recording...');
        _refreshAllData();
      }
    } catch (e) {
      print('❌ Failed to resume session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('home.failed_to_resume_text')}: $e'),
            backgroundColor: AppColors.getError(context),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ==================== STREAK SECTION ====================
  Widget _buildStreakSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home.streak_text'),
          style: AppTypography.titleLarge(
            context,
            weight: AppTypography.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        AppMargin.gap(context),
        Row(
          children: [
            Expanded(
              child: _buildStreakCard(
                context: context,
                label: _t('home.current_streak_text'),
                value: context.formatNumber(_currentStreak),
                unit: _currentStreak > 1
                    ? _t('home.days_text')
                    : _t('home.day_text'),
              ),
            ),
            AppMargin.gapH(context),
            Expanded(
              child: _buildStreakCard(
                context: context,
                label: _t('home.longest_streak_text'),
                value: context.formatNumber(_longestStreak),
                unit: _longestStreak > 1
                    ? _t('home.days_text')
                    : _t('home.day_text'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakCard({
    required BuildContext context,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: AppPadding.card(context),
      decoration: AppComponentStyles.card(
        color: AppColors.getSurface(context),
        borderRadius: AppDesignSystem.radiusLarge,
        borderColor: AppColors.getBorderLight(context),
        borderWidth: AppDesignSystem.borderNormal,
        shadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption(
              context,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          AppMargin.gapSmall(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.displaySmall(
                  context,
                  weight: AppTypography.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              AppMargin.gapHSmall(context),
              Text(
                unit,
                style: AppTypography.caption(
                  context,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PROGRESS SECTION ====================
  Widget _buildProgressSection(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isArabic = languageProvider.currentLanguageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home.progress_text'),
          style: AppTypography.titleLarge(
            context,
            weight: AppTypography.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        AppMargin.gap(context),
        Row(
          children: [
            Expanded(
              child: _buildProgressCard(
                context: context,
                label: _t('home.completion_text'),
                value: '${context.formatNumber(_completionPercentage)}%',
                color: AppColors.getPrimary(context),
              ),
            ),
            AppMargin.gapH(context),
            Expanded(
              child: _buildProgressCard(
                context: context,
                label: _t('home.memorized_text'),
                value: '${context.formatNumber(_memorizedPercentage)}%',
                color: AppColors.getSecondary(context),
              ),
            ),
          ],
        ),
        AppMargin.gap(context),
        Row(
          children: [
            Expanded(
              child: _buildProgressCard(
                context: context,
                label: _t('home.time_text'),
                value: _formatEngagementTime(
                  context,
                  _engagementTime,
                  isArabic,
                ),
                color: AppColors.getInfo(context),
              ),
            ),
            AppMargin.gapH(context),
            Expanded(
              child: _buildProgressCard(
                context: context,
                label: _versesRecited > 1
                    ? _t('home.verses_text')
                    : _t('home.verse_text'),
                value: context.formatNumber(_versesRecited),
                color: AppColors.getSuccess(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ Format engagement time with RTL support for Arabic
  String _formatEngagementTime(
    BuildContext context,
    String time,
    bool isArabic,
  ) {
    if (!isArabic) {
      // LTR: hours:minutes:seconds
      return context.formatNumber(time);
    }

    // RTL: seconds:minutes:hours for Arabic
    final parts = time.split(':');
    if (parts.length == 3) {
      final hours = context.formatNumber(parts[0]);
      final minutes = context.formatNumber(parts[1]);
      final seconds = context.formatNumber(parts[2]);
      return '$seconds:$minutes:$hours'; // Reversed for RTL
    }

    return context.formatNumber(time);
  }

  Widget _buildProgressCard({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: AppPadding.card(context),
      decoration: AppComponentStyles.card(
        color: AppColors.getSurface(context),
        borderRadius: AppDesignSystem.radiusLarge,
        borderColor: AppColors.getBorderLight(context),
        borderWidth: AppDesignSystem.borderNormal,
        shadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppDesignSystem.space6,
            height: AppDesignSystem.space6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          AppMargin.gap(context),
          Text(
            label,
            style: AppTypography.caption(
              context,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          AppMargin.gapSmall(context),
          Text(
            value,
            style: AppTypography.h2(
              context,
              weight: AppTypography.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TODAY'S GOAL ====================
  Widget _buildTodayGoal(BuildContext context) {
    String goalIcon = '📖';
    final String goalText = _t('home.goal_text');
    final String pageText = _t('home.page_text');
    String goalLabel = '${_t('home.verses_text')} $goalText';
    if (_goalType == 'minutes') {
      goalLabel = '${_t('home.time_text')} $goalText';
      goalIcon = '⏱️';
    } else if (_goalType == 'pages') {
      goalLabel = '$pageText $goalText';
      goalIcon = '📄';
    }

    String progressText =
        '${context.formatNumber(_goalCurrent)}/${context.formatNumber(_goalTarget)} ${_goalType == 'minutes' ? _t('home.session.min_text') : _goalType}';
    double progressPercent = _goalTarget > 0
        ? (_goalCurrent / _goalTarget).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home.todays_goal_text'),
          style: AppTypography.titleLarge(
            context,
            weight: AppTypography.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        AppMargin.gap(context),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              AppHaptics.light();
            },
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
            splashColor: AppComponentStyles.rippleColor,
            child: Container(
              padding: AppPadding.card(context),
              decoration: AppComponentStyles.card(
                color: AppColors.getSurface(context),
                borderRadius: AppDesignSystem.radiusLarge,
                borderColor: AppColors.getBorderLight(context),
                borderWidth: AppDesignSystem.borderNormal,
                shadow: false,
              ),
              child: _hasGoal
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: AppDesignSystem.iconHuge,
                              height: AppDesignSystem.iconHuge,
                              decoration: BoxDecoration(
                                color: _goalCompleted
                                    ? AppColors.getSuccess(context)
                                    : AppColors.getPrimary(context),
                                borderRadius: BorderRadius.circular(
                                  AppDesignSystem.radiusMedium,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  goalIcon,
                                  style: TextStyle(
                                    fontSize: AppDesignSystem.scale(
                                      context,
                                      24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AppMargin.gapH(context),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goalLabel,
                                    style: AppTypography.title(
                                      context,
                                      weight: AppTypography.semiBold,
                                      color: AppColors.getTextPrimary(context),
                                    ),
                                  ),
                                  AppMargin.gapSmall(context),
                                  Text(
                                    progressText,
                                    style: AppTypography.caption(
                                      context,
                                      color: _goalCompleted
                                          ? AppColors.getSuccess(context)
                                          : AppColors.getTextTertiary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_goalCompleted)
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.getSuccess(context),
                                size: AppDesignSystem.iconLarge,
                              )
                            else
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: AppDesignSystem.iconSmall,
                                color: AppColors.getTextDisabled(context),
                              ),
                          ],
                        ),
                        if (!_goalCompleted) ...[
                          AppMargin.gap(context),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusSmall,
                            ),
                            child: LinearProgressIndicator(
                              value: progressPercent,
                              backgroundColor: AppColors.getBorderLight(
                                context,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.getPrimary(context),
                              ),
                              minHeight: AppDesignSystem.scale(context, 6),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: AppDesignSystem.iconHuge,
                          height: AppDesignSystem.iconHuge,
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceContainerLow(context),
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMedium,
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.getTextTertiary(context),
                            size: AppDesignSystem.iconLarge,
                          ),
                        ),
                        AppMargin.gapH(context),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('home.set_goal_text'),
                                style: AppTypography.title(
                                  context,
                                  weight: AppTypography.semiBold,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                              AppMargin.gapSmall(context),
                              Text(
                                _t('home.tap_to_create_goal_text'),
                                style: AppTypography.caption(
                                  context,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: AppDesignSystem.iconSmall,
                          color: AppColors.getTextDisabled(context),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ACHIEVEMENTS ====================
  Widget _buildAchievements(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  _t('home.achievements_text'),
                  style: AppTypography.titleLarge(
                    context,
                    weight: AppTypography.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                if (_earnedBadgesCount > 0) ...[
                  AppMargin.gapHSmall(context),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.space6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.getPrimaryContainer(context),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusSmall,
                      ),
                    ),
                    child: Text(
                      '${context.formatNumber(_earnedBadgesCount)}/${context.formatNumber(_totalBadgesCount)}',
                      style: AppTypography.captionSmall(
                        context,
                        color: AppColors.getPrimary(context),
                        weight: AppTypography.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const AchievementPage(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          const begin = Offset(-0.03, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;
                          var tween = Tween(
                            begin: begin,
                            end: end,
                          ).chain(CurveTween(curve: curve));
                          var offsetAnimation = animation.drive(tween);
                          var fadeAnimation = animation.drive(
                            Tween(
                              begin: 0.0,
                              end: 1.0,
                            ).chain(CurveTween(curve: curve)),
                          );
                          return FadeTransition(
                            opacity: fadeAnimation,
                            child: SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            ),
                          );
                        },
                    transitionDuration: AppDesignSystem.durationNormal,
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space8,
                  vertical: AppDesignSystem.space4,
                ),
                minimumSize: Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _t('home.more_text'),
                style: AppTypography.caption(
                  context,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
          ],
        ),
        AppMargin.gap(context),
        SizedBox(
          height: AppDesignSystem.scale(context, 130), // ✅ Increased from 100
          child: _recentBadges.isEmpty
              ? _buildEmptyBadges(context)
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _recentBadges.length,
                  itemBuilder: (context, index) {
                    final badge = _recentBadges[index];
                    return _buildAchievementBadge(
                      context: context,
                      emoji: badge['emoji'] ?? '🏆',
                      label: badge['title'] ?? _t('home.badge_text'),
                      count: null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyBadges(BuildContext context) {
    return Center(
      child: Container(
        padding: AppPadding.card(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: AppColors.getTextDisabled(context),
              size: AppDesignSystem.iconLarge,
            ),
            AppMargin.gapHSmall(context),
            Text(
              _t('home.complete_sessions_to_earn_badges_text'),
              style: AppTypography.caption(
                context,
                color: AppColors.getTextTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementBadge({
    required BuildContext context,
    required String emoji,
    required String label,
    required int? count,
  }) {
    return Container(
      width: AppDesignSystem.scale(context, 110), // ✅ Increased from 100
      margin: EdgeInsets.only(
        right: AppDesignSystem.scale(context, AppDesignSystem.space12),
      ),
      padding: AppPadding.card(context),
      decoration: AppComponentStyles.card(
        color: AppColors.getSurface(context),
        borderRadius: AppDesignSystem.radiusLarge,
        borderColor: AppColors.getBorderLight(context),
        borderWidth: AppDesignSystem.borderNormal,
        shadow: false,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: AppDesignSystem.scale(context, 25)),
              ),
              if (count != null)
                Positioned(
                  top: AppDesignSystem.scale(context, -4),
                  right: AppDesignSystem.scale(context, -4),
                  child: Container(
                    padding: AppPadding.all(context, AppDesignSystem.space4),
                    decoration: BoxDecoration(
                      color: AppColors.getWarning(context),
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: AppDesignSystem.scale(context, 18),
                      minHeight: AppDesignSystem.scale(context, 18),
                    ),
                    child: Center(
                      child: Text(
                        context.formatNumber(count),
                        style: AppTypography.captionSmall(
                          context,
                          color: AppColors.getTextInverse(context),
                          weight: AppTypography.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppMargin.gapSmall(context),
          // ✅ Removed Flexible/maxLines to show full text
          Text(
            label,
            style: AppTypography.captionSmall(
              context,
              weight: AppTypography.medium,
              color: AppColors.getTextPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
