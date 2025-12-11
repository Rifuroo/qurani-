// lib/screens/main/home/screens/activity_page.dart

import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  Map<String, dynamic> _translations = {};
  bool _isRTL = false;

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('home/activity');
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _translations = trans;
      _isRTL = languageProvider.currentLanguageCode == 'ar';
    });
  }

  final SupabaseService _supabaseService = SupabaseService();

  // Loading & data state
  bool _isLoading = true;
  Map<String, dynamic>? _activityData;

  // Cache for instant reload
  static Map<String, dynamic>? _cache;
  static DateTime? _cacheTime;

  // Filter states
  String _globalFilter = 'day';
  String _pagesTimeframe = 'day';
  String _engagementTimeframe = 'day';
  String _statisticsTimeframe = 'THIS DAY';

  final List<String> _timeframeOptions = ['day', 'week', 'month'];
  final Map<String, String> _globalFilterOptions = {
    'day': 'Day',
    'week': 'Week',
    'month': 'Month',
  };

  // Total ayahs in Quran for completion calculation
  static const int _totalQuranAyahs = 6236;

  @override
  void initState() {
    super.initState();
    _loadActivityData();
    _loadTranslations();
  }

  Future<void> _loadActivityData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Show cached data immediately (instant UI)
    if (_cache != null) {
      if (mounted) {
        setState(() {
          _activityData = _cache;
          _isLoading = false;
        });
      }

      // If cache is fresh (< 30 seconds), don't refetch
      if (_cacheTime != null &&
          DateTime.now().difference(_cacheTime!).inSeconds < 30) {
        return;
      }
    }

    // Fetch fresh data (single optimized call)
    try {
      final data = await _supabaseService.getActivityPageData(user.id);

      if (data != null && mounted) {
        _cache = data;
        _cacheTime = DateTime.now();
        setState(() {
          _activityData = data;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Get chart data key based on timeframe
  String _getChartKey(String timeframe) {
    switch (timeframe) {
      case 'day':
        return 'chart_day';
      case 'week':
        return 'chart_week';
      case 'month':
        return 'chart_month';
      default:
        return 'chart_day';
    }
  }

  // Get engagement chart data based on selected timeframe
  List<FlSpot> _getEngagementChartData() {
    if (_activityData == null) return [const FlSpot(0, 0)];

    final chartKey = _getChartKey(_engagementTimeframe);
    final chartData = _activityData![chartKey] as List? ?? [];
    if (chartData.isEmpty) return [const FlSpot(0, 0)];

    final spots = <FlSpot>[];
    for (int i = 0; i < chartData.length; i++) {
      final minutes = ((chartData[i]['duration_seconds'] ?? 0) as int) / 60;
      spots.add(FlSpot(i.toDouble(), minutes));
    }
    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  List<String> _getEngagementXLabels() {
    if (_activityData == null) return [''];

    final chartKey = _getChartKey(_engagementTimeframe);
    final chartData = _activityData![chartKey] as List? ?? [];
    if (chartData.isEmpty) return [''];

    return chartData.map((d) {
      return d['activity_date']?.toString() ?? '';
    }).toList();
  }

  double _getEngagementMaxY() {
    final spots = _getEngagementChartData();
    double maxY = 10;
    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    return maxY + 5;
  }

  // Get accuracy chart key based on timeframe
  String _getAccuracyChartKey(String timeframe) {
    switch (timeframe) {
      case 'day':
        return 'accuracy_day';
      case 'week':
        return 'accuracy_week';
      case 'month':
        return 'accuracy_month';
      default:
        return 'accuracy_day';
    }
  }

  // Get accuracy chart data based on selected timeframe
  List<FlSpot> _getAccuracyChartData() {
    if (_activityData == null) return [const FlSpot(0, 0)];

    final chartKey = _getAccuracyChartKey(_engagementTimeframe);
    final chartData = _activityData![chartKey] as List? ?? [];
    if (chartData.isEmpty) return [const FlSpot(0, 0)];

    final spots = <FlSpot>[];
    for (int i = 0; i < chartData.length; i++) {
      final accuracy = (chartData[i]['accuracy'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), accuracy));
    }
    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  List<String> _getAccuracyXLabels() {
    if (_activityData == null) return [''];

    final chartKey = _getAccuracyChartKey(_engagementTimeframe);
    final chartData = _activityData![chartKey] as List? ?? [];
    if (chartData.isEmpty) return [''];

    return chartData.map((d) {
      return d['activity_date']?.toString() ?? '';
    }).toList();
  }

  double _getAccuracyMaxY() {
    return 100.0; // Accuracy is always 0-100%
  }

  // Get pages chart data (currently only day view available)
  List<FlSpot> _getPagesChartData() {
    if (_activityData == null) return [const FlSpot(0, 0)];

    // For now, pages only has day view from database
    final pagesData = _activityData!['pages_day'] as List? ?? [];
    if (pagesData.isEmpty) return [const FlSpot(0, 0)];

    final spots = <FlSpot>[];
    for (int i = 0; i < pagesData.length; i++) {
      final pages = (pagesData[i]['pages_count'] ?? 0) as int;
      spots.add(FlSpot(i.toDouble(), pages.toDouble()));
    }
    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  List<String> _getPagesXLabels() {
    if (_activityData == null) return [''];

    final pagesData = _activityData!['pages_day'] as List? ?? [];
    if (pagesData.isEmpty) return [''];

    return pagesData.map((d) {
      return d['activity_date']?.toString() ?? '';
    }).toList();
  }

  double _getPagesMaxY() {
    final spots = _getPagesChartData();
    double maxY = 5;
    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    return maxY + 2;
  }

  // Get statistics for a period
  Map<String, dynamic> _getStatsForPeriod(String period) {
    if (_activityData == null) {
      return _defaultStats();
    }

    final stats = _activityData!['stats'] as Map<String, dynamic>? ?? {};
    final badges = _activityData!['badges'] as Map<String, dynamic>? ?? {};

    final periodKey = period.toLowerCase();
    final periodStats = stats[periodKey] as Map<String, dynamic>? ?? {};
    final badgeCount = badges[periodKey] as int? ?? 0;

    final durationSeconds = periodStats['duration_seconds'] as int? ?? 0;
    final reciteTimeSeconds = periodStats['recite_time_seconds'] as int? ?? 0;
    final verses = periodStats['verses'] as int? ?? 0;
    final accuracy = (periodStats['accuracy'] as num?)?.toDouble() ?? 0.0;
    final completion = (verses / _totalQuranAyahs * 100);
    final deeds = verses * 10;

    return {
      'engagement': _formatDuration(durationSeconds),
      'completion': '${completion.toStringAsFixed(completion < 1 ? 2 : 1)}${_translations.isNotEmpty ? LanguageHelper.tr(_translations, 'activity.percent_suffix') : '%'}',
      'verses': verses,
      'recitation': _formatDuration(reciteTimeSeconds),
      'accuracy': accuracy,
      'badges': badgeCount,
      'deeds': _formatNumber(deeds),
      'searches': 0,
      'shared': 0,
    };
  }

  Map<String, dynamic> _defaultStats() {
    return {
      'engagement': '00:00',
      'completion': '0${_translations.isNotEmpty ? LanguageHelper.tr(_translations, 'activity.percent_suffix') : '%'}',
      'verses': 0,
      'recitation': '00:00',
      'accuracy': 0.0,
      'badges': 0,
      'deeds': '0',
      'searches': 0,
      'shared': 0,
    };
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '${context.formatNumber('00')}:${context.formatNumber('00')}';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    // Format untuk RTL (Arabic) = detik:menit:jam
    // Format untuk LTR = jam:menit:detik
    if (_isRTL) {
      if (hours > 0) {
        return '${context.formatNumber(secs.toString().padLeft(2, '0'))}:${context.formatNumber(minutes.toString().padLeft(2, '0'))}:${context.formatNumber(hours.toString().padLeft(2, '0'))}';
      }
      return '${context.formatNumber(secs.toString().padLeft(2, '0'))}:${context.formatNumber(minutes.toString().padLeft(2, '0'))}';
    } else {
      if (hours > 0) {
        return '${context.formatNumber(hours.toString().padLeft(2, '0'))}:${context.formatNumber(minutes.toString().padLeft(2, '0'))}:${context.formatNumber(secs.toString().padLeft(2, '0'))}';
      }
      return '${context.formatNumber(minutes.toString().padLeft(2, '0'))}:${context.formatNumber(secs.toString().padLeft(2, '0'))}';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${context.formatNumber((number / 1000000).toStringAsFixed(1))}M';
    }
    if (number >= 1000) {
      return '${context.formatNumber((number / 1000).toStringAsFixed(1))}K';
    }
    return context.formatNumber(number);
  }

  String _formatEngagementWithSuffix(String timeStr) {
    // Parse time string untuk extract hours dan minutes
    final parts = timeStr.split(':');
    
    final hourSuffix = _translations.isNotEmpty 
        ? LanguageHelper.tr(_translations, 'activity.hour_suffix') 
        : 'h';
    final minuteSuffix = _translations.isNotEmpty 
        ? LanguageHelper.tr(_translations, 'activity.minute_suffix') 
        : 'm';
    
    if (_isRTL) {
      // RTL format: detik:menit atau detik:menit:jam
      if (parts.length == 2) {
        // Format: detik:menit
        final minutes = int.tryParse(parts[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (minutes > 0) {
          return '$timeStr (${context.formatNumber(minutes)}$minuteSuffix)';
        }
        return timeStr;
      } else if (parts.length == 3) {
        // Format: detik:menit:jam
        final hours = int.tryParse(parts[2].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final minutes = int.tryParse(parts[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (hours > 0) {
          return '$timeStr (${context.formatNumber(hours)}$hourSuffix ${context.formatNumber(minutes)}$minuteSuffix)';
        }
        if (minutes > 0) {
          return '$timeStr (${context.formatNumber(minutes)}$minuteSuffix)';
        }
      }
    } else {
      // LTR format: menit:detik atau jam:menit:detik
      if (parts.length == 2) {
        // Format: menit:detik
        final minutes = int.tryParse(parts[0].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (minutes > 0) {
          return '$timeStr (${context.formatNumber(minutes)}$minuteSuffix)';
        }
        return timeStr;
      } else if (parts.length == 3) {
        // Format: jam:menit:detik
        final hours = int.tryParse(parts[0].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final minutes = int.tryParse(parts[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (hours > 0) {
          return '$timeStr (${context.formatNumber(hours)}$hourSuffix ${context.formatNumber(minutes)}$minuteSuffix)';
        }
        if (minutes > 0) {
          return '$timeStr (${context.formatNumber(minutes)}$minuteSuffix)';
        }
      }
    }
    
    return timeStr;
  }

  String _mapTabToKey(String tab) {
    switch (tab) {
      case 'THIS DAY':
        return 'day';
      case 'THIS WEEK':
        return 'week';
      case 'THIS MONTH':
        return 'month';
      case 'THIS YEAR':
        return 'year';
      case 'ALL TIME':
        return 'lifetime';
      default:
        return 'lifetime';
    }
  }

  String _mapGlobalToStatTab(String global) {
    switch (global) {
      case 'day':
        return 'THIS DAY';
      case 'week':
        return 'THIS WEEK';
      case 'month':
        return 'THIS MONTH';
      default:
        return 'THIS DAY';
    }
  }

  void _onGlobalFilterChanged(String? newValue) {
    if (newValue == null) return;
    AppHaptics.light();
    setState(() {
      _globalFilter = newValue;
      _pagesTimeframe = newValue;
      _engagementTimeframe = newValue;
      _statisticsTimeframe = _mapGlobalToStatTab(newValue);
    });
  }

  void _changeTimeframe(String currentTimeframe, bool isNext, bool isPages) {
    final currentIndex = _timeframeOptions.indexOf(currentTimeframe);
    int newIndex = isNext
        ? (currentIndex + 1) % _timeframeOptions.length
        : (currentIndex - 1 + _timeframeOptions.length) %
              _timeframeOptions.length;

    AppHaptics.light();
    setState(() {
      if (isPages) {
        _pagesTimeframe = _timeframeOptions[newIndex];
      } else {
        _engagementTimeframe = _timeframeOptions[newIndex];
      }
      if (_pagesTimeframe == _engagementTimeframe) {
        _globalFilter = _pagesTimeframe;
        _statisticsTimeframe = _mapGlobalToStatTab(_pagesTimeframe);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const MenuAppBar(selectedIndex: 4),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _cache = null; // Force refresh
            await _loadActivityData();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: AppPadding.only(
                  context,
                  left: AppDesignSystem.space20,
                  top: AppDesignSystem.space20,
                  right: AppDesignSystem.space20,
                  bottom: AppDesignSystem.space32,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildGlobalFilterDropdown(context),
                    AppMargin.gapLarge(context),
                    _buildPagesChart(context),
                    AppMargin.gapLarge(context),
                    _buildEngagementChart(context),
                    AppMargin.gapLarge(context),
                    _buildAccuracyChart(context),
                    AppMargin.gapLarge(context),
                    _buildStatistics(context),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalFilterDropdown(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
      shadow: false,
      borderColor: AppColors.borderLight,
      child: Row(
        children: [
          Icon(
            Icons.filter_list_rounded,
            color: AppColors.textSecondary,
            size: 15 * s,
          ),
          SizedBox(width: 6 * s),
          Text(
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'activity.filter_period_text')
                : 'Filter Period:',
            style: TextStyle(
              fontSize: 12 * s,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 2 * s),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6 * s),
            ),
            child: DropdownButton<String>(
              value: _globalFilter,
              underline: const SizedBox(),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textPrimary,
                size: 16 * s,
              ),
              style: TextStyle(
                fontSize: 11 * s,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(6 * s),
              items: _globalFilterOptions.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        _getTranslatedFilterOption(e.key).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11 * s,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onGlobalFilterChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _getTranslatedFilterOption(String key) {
    if (_translations.isEmpty) return key;
    switch (key) {
      case 'day':
        return LanguageHelper.tr(_translations, 'activity.day_text');
      case 'week':
        return LanguageHelper.tr(_translations, 'activity.week_text');
      case 'month':
        return LanguageHelper.tr(_translations, 'activity.month_text');
      default:
        return key;
    }
  }

  Widget _buildPagesChart(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final spots = _getPagesChartData();
    final labels = _getPagesXLabels();
    final maxY = _getPagesMaxY();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.pages_text')
                    : 'Pages',
                style: TextStyle(
                  fontSize: 16 * s,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              _buildTimeframeSelector(_pagesTimeframe, true, context),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.all(16 * s),
          shadow: false,
          borderColor: AppColors.borderLight,
          child: SizedBox(
            height: 180 * s,
            child: _isLoading
                ? _buildChartSkeleton(context)
                : (spots.length <= 1 && spots.first.y == 0)
                ? _buildEmptyChart(
                    context, 
                    _translations.isNotEmpty
                        ? LanguageHelper.tr(_translations, 'activity.no_pages_data')
                        : 'No pages data yet'
                  )
                : _buildLineChart(spots, maxY, labels, context),
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementChart(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final spots = _getEngagementChartData();
    final labels = _getEngagementXLabels();
    final maxY = _getEngagementMaxY();

    final minutesSuffix = _translations.isNotEmpty 
        ? LanguageHelper.tr(_translations, 'activity.minutes_suffix')
        : 'minutes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _translations.isNotEmpty
                    ? '${LanguageHelper.tr(_translations, 'activity.engangement_text')} ($minutesSuffix)'
                    : 'Engagement (minutes)',
                style: TextStyle(
                  fontSize: 16 * s,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              _buildTimeframeSelector(_engagementTimeframe, false, context),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.all(16 * s),
          shadow: false,
          borderColor: AppColors.borderLight,
          child: SizedBox(
            height: 180 * s,
            child: _isLoading
                ? _buildChartSkeleton(context)
                : (spots.length <= 1 && spots.first.y == 0)
                ? _buildEmptyChart(
                    context, 
                    _translations.isNotEmpty
                        ? LanguageHelper.tr(_translations, 'activity.no_engagement_data')
                        : 'No engagement data yet'
                  )
                : _buildLineChart(spots, maxY, labels, context),
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyChart(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final spots = _getAccuracyChartData();
    final labels = _getAccuracyXLabels();
    final maxY = _getAccuracyMaxY();

    final percentSuffix = _translations.isNotEmpty 
        ? LanguageHelper.tr(_translations, 'activity.percent_suffix')
        : '%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _translations.isNotEmpty
                    ? '${LanguageHelper.tr(_translations, 'activity.accuracy_text')} ($percentSuffix)'
                    : 'Accuracy (%)',
                style: TextStyle(
                  fontSize: 16 * s,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              _buildTimeframeSelector(_engagementTimeframe, false, context),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.all(16 * s),
          shadow: false,
          borderColor: AppColors.borderLight,
          child: SizedBox(
            height: 180 * s,
            child: _isLoading
                ? _buildChartSkeleton(context)
                : (spots.length <= 1 && spots.first.y == 0)
                ? _buildEmptyChart(
                    context, 
                    _translations.isNotEmpty
                        ? LanguageHelper.tr(_translations, 'activity.no_accuracy_data')
                        : 'No accuracy data yet'
                  )
                : _buildAccuracyLineChart(spots, maxY, labels, context),
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyLineChart(
    List<FlSpot> spots,
    double maxY,
    List<String> xLabels,
    BuildContext context,
  ) {
    final s = AppDesignSystem.getScaleFactor(context);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.success,
            barWidth: 2 * s,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3 * s,
                    color: AppColors.success,
                    strokeWidth: 0,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.success.withValues(alpha: 0.08),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28 * s,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                context.formatNumber(value.toInt()),
                style: TextStyle(
                  fontSize: 9 * s,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24 * s,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: 6 * s),
                    child: Text(
                      xLabels[index],
                      style: TextStyle(
                        fontSize: 8.5 * s,
                        color: AppColors.success.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.borderLight, strokeWidth: 1 * s),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  Widget _buildChartSkeleton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final loadingText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'activity.loading_text')
        : 'Loading...';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24 * s,
            height: 24 * s,
            child: CircularProgressIndicator(
              strokeWidth: 2 * s,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            loadingText,
            style: TextStyle(fontSize: 11 * s, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String message) {
    final s = AppDesignSystem.getScaleFactor(context);
    return Center(
      child: Text(
        message,
        style: TextStyle(fontSize: 12 * s, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _buildTimeframeSelector(
    String current,
    bool isPages,
    BuildContext context,
  ) {
    final s = AppDesignSystem.getScaleFactor(context);
    return Row(
      children: [
        _buildSelectorButton(
          Icons.chevron_left,
          () => _changeTimeframe(current, false, isPages),
          context,
        ),
        SizedBox(width: 10 * s),
        Text(
          _getTranslatedFilterOption(current).toUpperCase(),
          style: TextStyle(
            fontSize: 12 * s,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(width: 10 * s),
        _buildSelectorButton(
          Icons.chevron_right,
          () => _changeTimeframe(current, true, isPages),
          context,
        ),
      ],
    );
  }

  Widget _buildSelectorButton(
    IconData icon,
    VoidCallback onTap,
    BuildContext context,
  ) {
    final s = AppDesignSystem.getScaleFactor(context);
    return InkWell(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(6 * s),
      child: Container(
        width: 28 * s,
        height: 28 * s,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(6 * s),
        ),
        child: Icon(icon, size: 16 * s, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildLineChart(
    List<FlSpot> spots,
    double maxY,
    List<String> xLabels,
    BuildContext context,
  ) {
    final s = AppDesignSystem.getScaleFactor(context);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2 * s,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3 * s,
                    color: AppColors.primary,
                    strokeWidth: 0,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryWithOpacity(0.08),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28 * s,
              interval: maxY / 3,
              getTitlesWidget: (value, meta) => Text(
                context.formatNumber(value.toInt()),
                style: TextStyle(
                  fontSize: 9 * s,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24 * s,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: 6 * s),
                    child: Text(
                      xLabels[index],
                      style: TextStyle(
                        fontSize: 8.5 * s,
                        color: AppColors.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.borderLight, strokeWidth: 1 * s),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  Widget _buildStatistics(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Text(
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'activity.statistics_text')
                : 'Statistics',
            style: TextStyle(
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.all(16 * s),
          shadow: false,
          borderColor: AppColors.borderLight,
          child: Column(
            children: [
              _buildStatisticsTabs(context),
              SizedBox(height: 20 * s),
              _buildStatisticsGrid(context),
            ],
          ),
        ),
      ],
    );
  }

  String _getTranslatedStatTab(String tab) {
    if (_translations.isEmpty) return tab;
    switch (tab) {
      case 'THIS DAY':
        return LanguageHelper.tr(_translations, 'activity.this_day_text');
      case 'THIS WEEK':
        return LanguageHelper.tr(_translations, 'activity.this_week_text');
      case 'THIS MONTH':
        return LanguageHelper.tr(_translations, 'activity.this_month_text');
      case 'THIS YEAR':
        return LanguageHelper.tr(_translations, 'activity.this_year_text');
      case 'ALL TIME':
        return LanguageHelper.tr(_translations, 'activity.alltime_text');
      default:
        return tab;
    }
  }

  Widget _buildStatisticsTabs(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final tabs = [
      'THIS DAY',
      'THIS WEEK',
      'THIS MONTH',
      'THIS YEAR',
      'ALL TIME',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = tab == _statisticsTimeframe;
          return Padding(
            padding: EdgeInsets.only(right: 6 * s),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  AppHaptics.light();
                  setState(() => _statisticsTimeframe = tab);
                },
                borderRadius: BorderRadius.circular(6 * s),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * s,
                    vertical: 6 * s,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6 * s),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderMedium,
                      width: 1 * s,
                    ),
                  ),
                  child: Text(
                    _getTranslatedStatTab(tab),
                    style: TextStyle(
                      fontSize: 9.5 * s,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textInverse
                          : AppColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatisticsGrid(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final periodKey = _mapTabToKey(_statisticsTimeframe);
    final data = _getStatsForPeriod(periodKey);

    final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
    final percentSuffix = _translations.isNotEmpty 
        ? LanguageHelper.tr(_translations, 'activity.percent_suffix')
        : '%';
    final accuracyStr = accuracy > 0 
        ? '${context.formatNumber(accuracy.toStringAsFixed(1))}$percentSuffix' 
        : '${context.formatNumber(0)}$percentSuffix';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                _formatEngagementWithSuffix(data['engagement'].toString()),
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.engangement_text')
                    : 'Engagement',
                Icons.access_time_rounded,
                AppColors.primary,
                context,
              ),
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: _buildStatCard(
                data['completion'].toString(),
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.completion_text')
                    : 'Completion',
                Icons.check_circle_outline_rounded,
                AppColors.success,
                context,
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * s),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context.formatNumber(data['verses']),
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.verses_recited')
                    : 'Verses Recited',
                Icons.menu_book_rounded,
                AppColors.info,
                context,
              ),
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: _buildStatCard(
                data['recitation'].toString(),
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.recitatiom_time_text')
                    : 'Recitation Time',
                Icons.timer_outlined,
                AppColors.accent,
                context,
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * s),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                accuracyStr,
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.accuracy_text')
                    : 'Accuracy',
                Icons.analytics_outlined,
                AppColors.secondary,
                context,
              ),
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: _buildStatCard(
                context.formatNumber(data['badges']),
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.earned_badges_text')
                    : 'Earned Badges',
                Icons.emoji_events_outlined,
                AppColors.warning,
                context,
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * s),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                data['deeds'].toString(),
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'activity.deeds_estimated_text')
                    : 'Deeds Estimated',
                Icons.favorite_border_rounded,
                AppColors.error,
                context,
              ),
            ),
            SizedBox(width: 10 * s),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    BuildContext context, {
    String? subtitle,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    return Container(
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: AppColors.borderLight, width: 1 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28 * s,
            height: 28 * s,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6 * s),
            ),
            child: Icon(icon, color: color, size: 16 * s),
          ),
          SizedBox(height: 10 * s),
          Text(
            _isLoading ? '...' : value,
            style: TextStyle(
              fontSize: 18 * s,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 3 * s),
          Text(
            label,
            style: TextStyle(
              fontSize: 10 * s,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2 * s),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8 * s,
                color: AppColors.textTertiary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


