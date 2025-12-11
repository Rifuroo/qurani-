// lib/screens/main/home/screens/home_page.dart

import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/all_session_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/achievement_page.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/providers/auth_provider.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/services/auth_service.dart';
import 'package:cuda_qurani/screens/main/stt/stt_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
    _loadLatestSession();
    _loadTranslations();
    _loadHomePageData();
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
      backgroundColor: AppColors.backgroundLight,
      appBar: const MenuAppBar(selectedIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAllData,
          color: AppColors.primary,
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

    String displayName = 'User';
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
          style: AppTypography.h1(context, weight: AppTypography.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        AppMargin.gapSmall(context),
        Text(_getGreeting(), style: AppTypography.caption(context)),
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
    if (_isLoadingSession) {
      return Container(
        padding: AppPadding.card(context),
        decoration: AppComponentStyles.card(
          color: AppColors.surface,
          borderRadius: AppDesignSystem.radiusLarge,
          borderColor: AppColors.borderLight,
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
          color: AppColors.surface,
          borderRadius: AppDesignSystem.radiusLarge,
          borderColor: AppColors.borderLight,
          borderWidth: AppDesignSystem.borderNormal,
          shadow: true,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.book_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            AppMargin.gapSmall(context),
            Text(
              'No recent session',
              style: AppTypography.body(context, color: AppColors.textTertiary),
            ),
            AppMargin.gapSmall(context),
            Text(
              'Start your first recitation',
              style: AppTypography.caption(context),
            ),
          ],
        ),
      );
    }

    final surahId = _latestSession!['surah_id'] ?? 0;
    final surahName =
        _latestSession!['surah_name'] ?? '${_t('home.surah_text')} $surahId';
    final totalAyahs = _latestSession!['total_ayahs'] ?? 0;
    final ayah = _latestSession!['ayah'] ?? 0;
    final position = _latestSession!['position'] ?? 0;
    final status = _latestSession!['status'] ?? 'unknown';
    final updatedAt = _latestSession!['updated_at'] ?? '';

    // Calculate time ago with translations
    String timeAgo = 'Just now';
    try {
      final updated = DateTime.parse(updatedAt);
      final diff = DateTime.now().difference(updated);
      if (diff.inMinutes < 60) {
        final mins = diff.inMinutes;
        timeAgo =
            '$mins ${mins > 1 ? _t('home.minutes_text') : _t('home.minute_text')} ${_t('home.ago_text')}';
      } else if (diff.inHours < 24) {
        final hrs = diff.inHours;
        timeAgo =
            '$hrs ${hrs > 1 ? _t('home.hours_text') : _t('home.hour_text')} ${_t('home.ago_text')}';
      } else {
        final dys = diff.inDays;
        timeAgo =
            '$dys ${dys > 1 ? _t('home.days_text') : _t('home.day_text')} ${_t('home.ago_text')}';
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
            color: AppColors.surface,
            borderRadius: AppDesignSystem.radiusLarge,
            borderColor: AppColors.borderLight,
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
                              ? AppColors.warning
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      AppMargin.gapHSmall(context),
                      Text(
                        status == 'paused'
                            ? 'PAUSED SESSION'
                            : _t('home.latest_Session_text').toUpperCase(),
                        style: AppTypography.overline(context),
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
                              ),
                            ),
                            AppMargin.customGapH(
                              context,
                              AppDesignSystem.space4,
                            ),
                            Icon(
                              Icons.history_rounded,
                              size: AppDesignSystem.iconSmall,
                              color: AppColors.textTertiary,
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
                style: AppTypography.h2(context, weight: AppTypography.bold),
              ),
              AppMargin.gapSmall(context),
              Text(
                '${_t('home.ayah_text')} $ayah${totalAyahs > 0 ? '/$totalAyahs' : ''}, ${_t('home.word_text')} ${position + 1} · $timeAgo',
                style: AppTypography.caption(context),
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
                      const BorderSide(
                        color: AppColors.textPrimary,
                        width: AppDesignSystem.borderThick,
                      ),
                    ),
                  ),
                  child: Text(
                    _t('home.continue_reading_text'),
                    style: AppTypography.label(
                      context,
                      color: AppColors.textPrimary,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resume: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ==================== STREAK SECTION ====================
  Widget _buildStreakSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home.streak_text'),
          style: AppTypography.titleLarge(context, weight: AppTypography.bold),
        ),
        AppMargin.gap(context),
        Row(
          children: [
            Expanded(
              child: _buildStreakCard(
                context: context,
                label: 'Current Streak 🔥',
                value: _currentStreak,
                unit: _currentStreak > 1
                    ? _t('home.days_text')
                    : _t('home.day_text'),
              ),
            ),
            AppMargin.gapH(context),
            Expanded(
              child: _buildStreakCard(
                context: context,
                label: _t('home.treak'),
                value: _longestStreak,
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
    required int value,
    required String unit,
  }) {
    return Container(
      padding: AppPadding.card(context),
      decoration: AppComponentStyles.card(
        color: AppColors.surface,
        borderRadius: AppDesignSystem.radiusLarge,
        borderColor: AppColors.borderLight,
        borderWidth: AppDesignSystem.borderNormal,
        shadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(context)),
          AppMargin.gapSmall(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$value',
                style: AppTypography.displaySmall(
                  context,
                  weight: AppTypography.bold,
                ),
              ),
              AppMargin.gapHSmall(context),
              Text(unit, style: AppTypography.caption(context)),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PROGRESS SECTION ====================
  Widget _buildProgressSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home.progress_text'),
          style: AppTypography.titleLarge(context, weight: AppTypography.bold),
        ),
        AppMargin.gap(context),
        Row(
          children: [
            Expanded(
              child: _buildProgressCard(
                context: context,
                label: _t('home.completion_text'),
                value: '$_completionPercentage%',
                color: AppColors.primary,
              ),
            ),
            AppMargin.gapH(context),
            Expanded(
              child: _buildProgressCard(
                context: context,
                label: _t('home.memorized_text'),
                value: '$_memorizedPercentage%',
                color: AppColors.accent,
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
                value: _engagementTime,
                color: AppColors.info,
              ),
            ),
            AppMargin.gapH(context),
            Expanded(
              child: _buildProgressCard(
                context: context,
                label: _versesRecited > 1
                    ? _t('home.verses_text')
                    : _t('home.verse_text'),
                value: '$_versesRecited',
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
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
        color: AppColors.surface,
        borderRadius: AppDesignSystem.radiusLarge,
        borderColor: AppColors.borderLight,
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
          Text(label, style: AppTypography.caption(context)),
          AppMargin.gapSmall(context),
          Text(
            value,
            style: AppTypography.h2(context, weight: AppTypography.bold),
          ),
        ],
      ),
    );
  }

  // ==================== TODAY'S GOAL ====================
  Widget _buildTodayGoal(BuildContext context) {
    String goalLabel = '${_t('home.verses_text')} Goal';
    String goalIcon = '📖';
    if (_goalType == 'minutes') {
      goalLabel = '${_t('home.time_text')} Goal';
      goalIcon = '⏱️';
    } else if (_goalType == 'pages') {
      goalLabel = 'Pages Goal';
      goalIcon = '📄';
    }

    String progressText =
        '$_goalCurrent/$_goalTarget ${_goalType == 'minutes' ? _t('home.session.min_text') : _goalType}';
    double progressPercent = _goalTarget > 0
        ? (_goalCurrent / _goalTarget).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home.todays_goal_text'),
          style: AppTypography.titleLarge(context, weight: AppTypography.bold),
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
                color: AppColors.surface,
                borderRadius: AppDesignSystem.radiusLarge,
                borderColor: AppColors.borderLight,
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
                                    ? AppColors.success
                                    : AppColors.primary,
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
                                    ),
                                  ),
                                  AppMargin.gapSmall(context),
                                  Text(
                                    progressText,
                                    style: AppTypography.caption(
                                      context,
                                      color: _goalCompleted
                                          ? AppColors.success
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_goalCompleted)
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                                size: AppDesignSystem.iconLarge,
                              )
                            else
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: AppDesignSystem.iconSmall,
                                color: AppColors.textDisabled,
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
                              backgroundColor: AppColors.borderLight,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
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
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusMedium,
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.textTertiary,
                            size: AppDesignSystem.iconLarge,
                          ),
                        ),
                        AppMargin.gapH(context),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set a Goal',
                                style: AppTypography.title(
                                  context,
                                  weight: AppTypography.semiBold,
                                ),
                              ),
                              AppMargin.gapSmall(context),
                              Text(
                                'Tap to create daily goal',
                                style: AppTypography.caption(context),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: AppDesignSystem.iconSmall,
                          color: AppColors.textDisabled,
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
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusSmall,
                      ),
                    ),
                    child: Text(
                      '$_earnedBadgesCount/$_totalBadgesCount',
                      style: AppTypography.captionSmall(
                        context,
                        color: AppColors.primary,
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
                'More',
                style: AppTypography.caption(
                  context,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        AppMargin.gap(context),
        SizedBox(
          height: AppDesignSystem.scale(context, 100),
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
                      label: badge['title'] ?? 'Badge',
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
              color: AppColors.textDisabled,
              size: AppDesignSystem.iconLarge,
            ),
            AppMargin.gapHSmall(context),
            Text(
              'Complete sessions to earn badges',
              style: AppTypography.caption(
                context,
                color: AppColors.textTertiary,
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
      width: AppDesignSystem.scale(context, 90),
      margin: EdgeInsets.only(
        right: AppDesignSystem.scale(context, AppDesignSystem.space12),
      ),
      padding: AppPadding.card(context),
      decoration: AppComponentStyles.card(
        color: AppColors.surface,
        borderRadius: AppDesignSystem.radiusLarge,
        borderColor: AppColors.borderLight,
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
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: AppDesignSystem.scale(context, 18),
                      minHeight: AppDesignSystem.scale(context, 18),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: AppTypography.captionSmall(
                          context,
                          color: Colors.white,
                          weight: AppTypography.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppMargin.gapSmall(context),
          Text(
            label,
            style: AppTypography.captionSmall(
              context,
              weight: AppTypography.medium,
            ),
          ),
        ],
      ),
    );
  }
}



