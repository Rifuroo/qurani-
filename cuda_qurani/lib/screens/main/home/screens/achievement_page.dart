// lib/screens/main/home/screens/achievement_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/services/supabase_service.dart';

// Model for Achievement Data
class AchievementModel {
  final String title;
  final String subtitle;
  final String description;
  final String emoji;
  final Color color;
  final bool isEarned;
  final bool isLocked;
  final String? earnedDate;
  final int? count;
  final String? badgeType;

  AchievementModel({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.emoji,
    required this.color,
    this.isEarned = false,
    this.isLocked = true,
    this.earnedDate,
    this.count,
    this.badgeType,
  });
}

class AchievementPage extends StatefulWidget {
  const AchievementPage({Key? key}) : super(key: key);

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  // ==================== DATABASE INTEGRATION ====================
  final SupabaseService _supabaseService = SupabaseService();
  
  bool _isLoading = true;
  AchievementModel? _latestBadge;
  List<AchievementModel> _earnedBadges = [];
  List<AchievementModel> _remainingBadges = [];
  int _earnedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await _supabaseService.getAchievementsData(user.id);
      
      if (data != null && mounted) {
        // Parse latest badge
        if (data['latest_badge'] != null) {
          final lb = data['latest_badge'];
          _latestBadge = AchievementModel(
            title: lb['title'] ?? '',
            subtitle: lb['subtitle'] ?? '',
            description: lb['description'] ?? '',
            emoji: lb['emoji'] ?? '🏆',
            color: _parseColor(lb['color'], context),
            badgeType: lb['category'],
            isEarned: true,
            isLocked: false,
            earnedDate: _formatDate(lb['earned_at']),
          );
        }

        // Parse earned badges
        final earnedList = data['earned_badges'] as List? ?? [];
        _earnedBadges = earnedList.map((b) => AchievementModel(
          title: b['title'] ?? '',
          subtitle: b['subtitle'] ?? '',
          description: b['description'] ?? '',
          emoji: b['emoji'] ?? '🏆',
          color: _parseColor(b['color'], context),
          badgeType: b['category'],
          isEarned: true,
          isLocked: false,
          earnedDate: _formatDate(b['earned_at']),
        )).toList();

        // Parse remaining badges
        final remainingList = data['remaining_badges'] as List? ?? [];
        _remainingBadges = remainingList.map((b) => AchievementModel(
          title: b['title'] ?? '',
          subtitle: b['subtitle'] ?? '',
          description: b['description'] ?? '',
          emoji: b['emoji'] ?? '🔒',
          color: _parseColor(b['color'], context),
          badgeType: b['category'],
          isEarned: false,
          isLocked: true,
        )).toList();

        // Stats
        final stats = data['stats'] ?? {};
        _earnedCount = stats['earned_count'] ?? 0;
        _totalCount = stats['total_count'] ?? 0;

        setState(() => _isLoading = false);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading achievements: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _parseColor(String? hexColor, BuildContext context) {
    if (hexColor == null) return AppColors.getTextTertiary(context);
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.getTextTertiary(context);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${_monthName(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
      return '';
    }
  }

  String _monthName(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 
                    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  // Fallback badge if no data
  AchievementModel _fallbackBadge(BuildContext context) => AchievementModel(
    title: 'No Badges Yet',
    subtitle: 'Start reading!',
    badgeType: 'Beginner',
    description: 'Complete your first session to earn a badge.',
    emoji: '🎯',
    color: AppColors.getTextTertiary(context),
    isEarned: false,
    isLocked: true,
  );

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: const ProfileAppBar(title: 'Achievements', showBackButton: true),
      body: SafeArea(
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: AppColors.getPrimary(context)))
          : RefreshIndicator(
              onRefresh: _loadAchievements,
              color: AppColors.getPrimary(context),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.only(bottom: AppDesignSystem.space40 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLatestBadgeSection(context, s),
                    AppMargin.gapXLarge(context),
                    if (_earnedBadges.isNotEmpty) ...[
                      _buildEarnedBadgesSection(context, s),
                      AppMargin.gapLarge(context),
                    ],
                    _buildInfoBanner(context, s),
                    _buildRemainingBadgesSection(context, s),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  // ==================== LATEST BADGE CARD (HERO) ====================
  Widget _buildLatestBadgeSection(BuildContext context, double s) {
    final badge = _latestBadge ?? _fallbackBadge(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppDesignSystem.space16 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest Badge',
                style: AppTypography.h3(context, weight: AppTypography.bold, color: AppColors.getTextPrimary(context)),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space8 * s,
                  vertical: 2 * s,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getPrimaryContainer(context),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
                ),
                child: Text(
                  '$_earnedCount/$_totalCount',
                  style: AppTypography.captionSmall(
                    context,
                    color: AppColors.getPrimary(context),
                    weight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDesignSystem.space12 * s),

          Container(
            decoration: AppComponentStyles.card(
              color: AppColors.getSurface(context),
              shadow: true,
              borderRadius: AppDesignSystem.radiusLarge * s,
              borderColor: AppColors.getBorderLight(context),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  AppHaptics.light();
                  _showBadgeDetails(context, badge, s);
                },
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(AppDesignSystem.space20 * s),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    'assets/images/qurani-white-text.png',
                                    height: 25 * s,
                                    color: AppColors.getPrimary(context),
                                    fit: BoxFit.contain,
                                  ),
                                  if (badge.badgeType != null)
                                    Container(
                                      padding: EdgeInsets.only(left: 4 * s),
                                      child: Text(
                                        badge.badgeType!,
                                        style: AppTypography.bodyLarge(
                                          context,
                                          color: AppColors.getTextSecondary(context),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Icon(
                                Icons.share_outlined,
                                color: AppColors.getTextTertiary(context),
                                size: AppDesignSystem.iconMedium * s,
                              ),
                            ],
                          ),

                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 180 * s,
                                height: 180 * s,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      badge.color.withValues(alpha: 0.2),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.3, 1.0],
                                  ),
                                ),
                              ),
                              Container(
                                width: 125 * s,
                                height: 125 * s,
                                decoration: BoxDecoration(
                                  color: AppColors.getSurface(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.getBorderLight(context),
                                    width: 1 * s,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.getShadowLight(context),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  badge.emoji,
                                  style: TextStyle(fontSize: 55 * s),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: AppDesignSystem.space16 * s),

                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppDesignSystem.space12 * s,
                              vertical: AppDesignSystem.space4 * s,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceContainerLowest(context),
                              border: Border.all(color: AppColors.getBorderMedium(context)),
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
                            ),
                            child: Text(
                              badge.subtitle,
                              style: AppTypography.caption(
                                context,
                                color: AppColors.getTextPrimary(context),
                                weight: AppTypography.medium,
                              ),
                            ),
                          ),

                          SizedBox(height: AppDesignSystem.space16 * s),

                          Text(
                            badge.description,
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              context,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: AppColors.getBorderLight(context)),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDesignSystem.space20 * s,
                        vertical: AppDesignSystem.space12 * s,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STATUS',
                                style: AppTypography.captionSmall(
                                  context,
                                  weight: AppTypography.bold,
                                  color: AppColors.getTextTertiary(context),
                                ),
                              ),
                              SizedBox(height: 2 * s),
                              Text(
                                badge.isEarned 
                                  ? 'EARNED ON ${badge.earnedDate}'
                                  : 'NOT YET EARNED',
                                style: AppTypography.caption(
                                  context,
                                  weight: AppTypography.bold,
                                  color: AppColors.getTextTertiary(context),
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            badge.isEarned ? Icons.verified_rounded : Icons.lock_outline,
                            color: badge.isEarned ? AppColors.getSuccess(context) : AppColors.getTextTertiary(context),
                            size: 24 * s,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EARNED BADGES SECTION ====================
  Widget _buildEarnedBadgesSection(BuildContext context, double s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space20 * s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Earned Badges',
                style: AppTypography.h3(context, weight: AppTypography.bold, color: AppColors.getTextPrimary(context)),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space8 * s,
                  vertical: 2 * s,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getSuccessContainer(context),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
                ),
                child: Text(
                  '${_earnedBadges.length}',
                  style: AppTypography.captionSmall(
                    context,
                    color: AppColors.getSuccess(context),
                    weight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppDesignSystem.space16 * s),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space16 * s),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _earnedBadges.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.70,
              crossAxisSpacing: AppDesignSystem.space8 * s,
              mainAxisSpacing: AppDesignSystem.space16 * s,
            ),
            itemBuilder: (context, index) {
              return _buildBadgeItem(context, _earnedBadges[index], s);
            },
          ),
        ),
      ],
    );
  }

  // ==================== INFO BANNER ====================
  Widget _buildInfoBanner(BuildContext context, double s) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: AppDesignSystem.space12 * s,
        horizontal: AppDesignSystem.space20 * s,
      ),
      margin: EdgeInsets.only(bottom: AppDesignSystem.space24 * s),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLowest(context),
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.getBorderLight(context), width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 14 * s,
            color: AppColors.getTextTertiary(context),
          ),
          SizedBox(width: AppDesignSystem.space8 * s),
          Text(
            'TAP BADGE TO VIEW REQUIREMENTS',
            style: AppTypography.captionSmall(
              context,
              weight: AppTypography.bold,
              color: AppColors.getTextTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== REMAINING BADGES SECTION ====================
  Widget _buildRemainingBadgesSection(BuildContext context, double s) {
    if (_remainingBadges.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space20 * s),
        child: Text(
          'All badges earned!',
          style: AppTypography.body(context, color: AppColors.getTextSecondary(context)),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space20 * s),
          child: Text(
            'Remaining Badges',
            style: AppTypography.h3(context, weight: AppTypography.bold, color: AppColors.getTextPrimary(context)),
          ),
        ),
        SizedBox(height: AppDesignSystem.space16 * s),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space16 * s),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _remainingBadges.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.70,
              crossAxisSpacing: AppDesignSystem.space8 * s,
              mainAxisSpacing: AppDesignSystem.space16 * s,
            ),
            itemBuilder: (context, index) {
              return _buildBadgeItem(context, _remainingBadges[index], s);
            },
          ),
        ),
      ],
    );
  }

  // ==================== BADGE ITEM WIDGET ====================
  Widget _buildBadgeItem(BuildContext context, AchievementModel item, double s) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        _showBadgeDetails(context, item, s);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 72 * s,
                height: 72 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isLocked ? AppColors.getSurfaceContainerHigh(context) : item.color,
                  gradient: !item.isLocked
                      ? LinearGradient(
                          colors: [item.color, item.color.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  boxShadow: !item.isLocked
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: item.isLocked ? 0.5 : 1.0,
                      child: Text(
                        item.emoji,
                        style: TextStyle(fontSize: 32 * s),
                      ),
                    ),
                    if (item.isLocked)
                      Container(
                        padding: EdgeInsets.all(4 * s),
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(context).withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: AppColors.getTextPrimary(context),
                          size: 16 * s,
                        ),
                      ),
                  ],
                ),
              ),
              if (item.count != null && !item.isLocked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(4 * s),
                    decoration: BoxDecoration(
                      color: AppColors.getError(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.getSurface(context), width: 2 * s),
                    ),
                    constraints: BoxConstraints(minWidth: 22 * s, minHeight: 22 * s),
                    child: Center(
                      child: Text(
                        item.count.toString(),
                        style: TextStyle(
                          color: AppColors.getTextInverse(context),
                          fontSize: 10 * s,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: AppDesignSystem.space8 * s),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.0 * s),
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                context,
                weight: AppTypography.semiBold,
                color: item.isLocked ? AppColors.getTextTertiary(context) : AppColors.getTextPrimary(context),
              ),
            ),
          ),

          SizedBox(height: 2 * s),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.0 * s),
            child: Text(
              item.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.captionSmall(context, color: AppColors.getTextTertiary(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BADGE DETAIL DIALOG ====================
  void _showBadgeDetails(BuildContext context, AchievementModel item, double s) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
          ),
          elevation: AppDesignSystem.elevationMedium,
          backgroundColor: AppColors.getSurface(context),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.all(AppDesignSystem.space20 * s),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTypography.titleLarge(context, weight: AppTypography.bold),
                            ),
                            Text(
                              item.subtitle,
                              style: AppTypography.body(context, color: AppColors.getTextSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: EdgeInsets.all(4 * s),
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceContainerLow(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, size: 20 * s, color: AppColors.getTextPrimary(context)),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: AppColors.getBorderLight(context)),

                Padding(
                  padding: EdgeInsets.all(AppDesignSystem.space24 * s),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120 * s,
                            height: 120 * s,
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceContainerLowest(context),
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusXXLarge * s),
                              border: Border.all(color: AppColors.getBorderLight(context), width: 1 * s),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Icon(
                              item.isLocked ? Icons.lock_rounded : Icons.check_circle_rounded,
                              size: 28 * s,
                              color: item.isLocked ? AppColors.getTextDisabled(context) : item.color,
                            ),
                          ),
                          Opacity(
                            opacity: item.isLocked ? 0.5 : 1.0,
                            child: Text(item.emoji, style: TextStyle(fontSize: 64 * s)),
                          ),
                        ],
                      ),

                      SizedBox(height: AppDesignSystem.space24 * s),

                      Text(
                        item.description,
                        textAlign: TextAlign.center,
                        style: AppTypography.body(context, color: AppColors.getTextSecondary(context))
                            .copyWith(height: 1.5),
                      ),

                      if (item.isLocked) ...[
                        SizedBox(height: AppDesignSystem.space16 * s),
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: AppDesignSystem.space8 * s,
                            horizontal: AppDesignSystem.space12 * s,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceContainerLow(context),
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
                          ),
                          child: Text(
                            "Keep going to unlock this badge!",
                            style: AppTypography.caption(
                              context,
                              color: AppColors.getTextTertiary(context),
                              weight: AppTypography.medium,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppDesignSystem.space12 * s),
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceContainerLowest(context),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppDesignSystem.radiusLarge * s),
                      bottomRight: Radius.circular(AppDesignSystem.radiusLarge * s),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space2 * s),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STATUS',
                              style: AppTypography.captionSmall(
                                context,
                                weight: AppTypography.medium,
                                color: AppColors.getTextTertiary(context),
                              ),
                            ),
                            Text(
                              item.isEarned 
                                ? 'EARNED ON ${item.earnedDate}' 
                                : 'NOT YET EARNED',
                              style: AppTypography.caption(
                                context,
                                weight: AppTypography.medium,
                                color: AppColors.getTextTertiary(context),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.all(6 * s),
                          decoration: BoxDecoration(
                            color: AppColors.getTextInverse(context),
                            borderRadius: BorderRadius.circular(30 * s),
                          ),
                          child: Image.asset(
                            'assets/images/qurani-icon-green.png',
                            height: 28 * s,
                            color: AppColors.getPrimary(context),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



