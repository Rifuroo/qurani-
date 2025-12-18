// lib/screens/main/home/screens/completion_page.dart

import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/screens/main/stt/stt_page.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';

// ==================== MODELS ====================

class SurahCompletion {
  final int surahId;
  final String? surahName;
  final int versesRead;
  final int totalVerses;
  final double percentage;
  final int? lastAyah;
  final DateTime? lastSessionAt;

  SurahCompletion({
    required this.surahId,
    this.surahName,
    required this.versesRead,
    required this.totalVerses,
    required this.percentage,
    this.lastAyah,
    this.lastSessionAt,
  });

  factory SurahCompletion.fromJson(Map<String, dynamic> json) {
    return SurahCompletion(
      surahId: json['surah_id'] as int,
      surahName: json['surah_name'] as String?,
      versesRead: json['verses_read'] as int? ?? 0,
      totalVerses: json['total_ayahs'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      lastAyah: json['last_ayah'] as int?,
      lastSessionAt: json['last_session_at'] != null
          ? DateTime.tryParse(json['last_session_at'].toString())
          : null,
    );
  }

  bool get isComplete => percentage >= 100;
  bool get isStarted => percentage > 0;
  bool get isIncomplete => percentage > 0 && percentage < 100;
}

class CompletionStats {
  final int completedSurahs;
  final int inProgressSurahs;
  final int totalVersesRead;
  final int totalQuranVerses;
  final double overallPercentage;

  CompletionStats({
    required this.completedSurahs,
    required this.inProgressSurahs,
    required this.totalVersesRead,
    required this.totalQuranVerses,
    required this.overallPercentage,
  });

  factory CompletionStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CompletionStats(
        completedSurahs: 0,
        inProgressSurahs: 0,
        totalVersesRead: 0,
        totalQuranVerses: 6236,
        overallPercentage: 0.0,
      );
    }
    return CompletionStats(
      completedSurahs: json['completed_surahs'] as int? ?? 0,
      inProgressSurahs: json['in_progress_surahs'] as int? ?? 0,
      totalVersesRead: json['total_verses_read'] as int? ?? 0,
      totalQuranVerses: json['total_quran_verses'] as int? ?? 6236,
      overallPercentage:
          (json['overall_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LastReadPosition {
  final int surahId;
  final String surahName;
  final int ayah;
  final DateTime? lastSessionAt;

  LastReadPosition({
    required this.surahId,
    required this.surahName,
    required this.ayah,
    this.lastSessionAt,
  });

  factory LastReadPosition.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LastReadPosition(surahId: 1, surahName: 'Al-Fatihah', ayah: 1);
    }
    return LastReadPosition(
      surahId: json['surah_id'] as int? ?? 1,
      surahName: json['surah_name'] as String? ?? 'Al-Fatihah',
      ayah: json['ayah'] as int? ?? 1,
      lastSessionAt: json['last_session_at'] != null
          ? DateTime.tryParse(json['last_session_at'].toString())
          : null,
    );
  }
}

// ==================== COMPLETION PAGE ====================

class CompletionPage extends StatefulWidget {
  const CompletionPage({super.key});

  @override
  State<CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends State<CompletionPage> {
  Map<String, dynamic> _translations = {};
  bool _isRTL = false;

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('home/completion');
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    setState(() {
      _translations = trans;
      _isRTL = languageProvider.currentLanguageCode == 'ar';
    });
  }

  final MetadataCacheService _cache = MetadataCacheService();
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  String _searchQuery = '';

  // Filter states
  bool _filterComplete = true;
  bool _filterIncomplete = true;
  bool _filterStarted = true;

  // Data
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _filteredSurahs = [];
  Map<int, SurahCompletion> _completionData = {};
  CompletionStats _stats = CompletionStats.fromJson(null);
  LastReadPosition _lastRead = LastReadPosition.fromJson(null);

  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load surah metadata
      if (!_cache.isInitialized) {
        await _cache.initialize();
      }
      _allSurahs = _cache.allSurahs;

      // Get current user
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Fetch completion data from Supabase (1 call)
        final data = await _supabaseService.getCompletionData(user.id);

        if (data != null) {
          // Parse progress data
          final progressList = data['progress'] as List? ?? [];
          _completionData = {};
          for (final item in progressList) {
            final completion = SurahCompletion.fromJson(
              item as Map<String, dynamic>,
            );
            _completionData[completion.surahId] = completion;
          }

          // Parse stats
          _stats = CompletionStats.fromJson(
            data['stats'] as Map<String, dynamic>?,
          );

          // Parse last read
          _lastRead = LastReadPosition.fromJson(
            data['last_read'] as Map<String, dynamic>?,
          );
        }
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data: $e';
          _isInitialized = true;
          _applyFilters();
        });
      }
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  SurahCompletion? _getCompletion(int surahId) {
    return _completionData[surahId];
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allSurahs);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((surah) {
        final name = (surah['name_simple'] as String? ?? '').toLowerCase();
        final nameArabic = surah['name_arabic'] as String? ?? '';
        final id = surah['id'].toString();

        return name.contains(_searchQuery) ||
            nameArabic.contains(_searchQuery) ||
            id.contains(_searchQuery);
      }).toList();
    }

    // Apply completion filters
    filtered = filtered.where((surah) {
      final completion = _getCompletion(surah['id'] as int);

      // If no completion data, treat as not started
      if (completion == null) {
        return _filterIncomplete; // Show in incomplete if filter is on
      }

      final isComplete = completion.isComplete;
      final isStarted = completion.isStarted;
      final isIncomplete = completion.isIncomplete;

      if (_filterComplete && _filterIncomplete && _filterStarted) return true;

      if (_filterComplete && isComplete) return true;
      if (_filterIncomplete && !isStarted)
        return true; // Not started = incomplete
      if (_filterStarted && isIncomplete)
        return true; // Started but not complete

      return false;
    }).toList();

    setState(() {
      _filteredSurahs = filtered;
    });
  }

  void _toggleFilter(String filterType) {
    AppHaptics.light();
    setState(() {
      switch (filterType) {
        case 'complete':
          _filterComplete = !_filterComplete;
          break;
        case 'incomplete':
          _filterIncomplete = !_filterIncomplete;
          break;
        case 'started':
          _filterStarted = !_filterStarted;
          break;
      }
      _applyFilters();
    });
  }

  Future<void> _navigateToSurah(int surahId) async {
    AppHaptics.light();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SttPage(suratId: surahId)));
  }

  Future<void> _continueReading() async {
    AppHaptics.medium();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SttPage(suratId: _lastRead.surahId)),
    );
  }

  // Helper: Get surah name berdasarkan bahasa
  String _getSurahName(Map<String, dynamic> surah) {
    if (_isRTL) {
      return surah['name_arabic'] as String? ??
          surah['name_simple'] as String? ??
          '';
    }
    return surah['name_simple'] as String? ?? '';
  }

  // Helper: Format angka dengan separator untuk RTL
  String _formatRTLNumber(
    dynamic num1,
    dynamic num2, {
    String separator = '/',
  }) {
    if (_isRTL) {
      // RTL: 10/1 bukan 1/10
      return '${context.formatNumber(num2)}$separator${context.formatNumber(num1)}';
    }
    // LTR: 1/10
    return '${context.formatNumber(num1)}$separator${context.formatNumber(num2)}';
  }

  // Helper: Format range untuk RTL
  String _formatRTLRange(dynamic start, dynamic end) {
    if (_isRTL) {
      // RTL: 10-1 bukan 1-10
      return '${context.formatNumber(end)}-${context.formatNumber(start)}';
    }
    // LTR: 1-10
    return '${context.formatNumber(start)}-${context.formatNumber(end)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getSurfaceVariant(context),
        appBar: MenuAppBar(selectedIndex: 2),
        body: AppLoadingIndicator(
          message: _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'completion.loading_text')
              : 'Loading completion data...',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getSurfaceVariant(context),
      appBar: MenuAppBar(selectedIndex: 2),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Error message if any
              if (_errorMessage != null)
                SliverToBoxAdapter(child: _buildErrorBanner()),

              // Top Section: Progress Circle + Stats
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProgressSection(),
                    _buildContinueReading(),
                    _buildFilterSection(),
                  ],
                ),
              ),

              // List Section: Surah Completion List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return _buildSectionHeader();
                  }

                  final surah = _filteredSurahs[index - 1];
                  return _buildSurahCompletionTile(surah);
                }, childCount: _filteredSurahs.length + 1),
              ),

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: AppDesignSystem.space32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SECTION HEADER ====================

  Widget _buildSectionHeader() {
    final s = AppDesignSystem.getScaleFactor(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDesignSystem.space16 * s,
        AppDesignSystem.space8 * s,
        AppDesignSystem.space16 * s,
        AppDesignSystem.space8 * s,
      ),
      child: Text(
        (_translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'completion.completion_by_chapter_text',
                  )
                : 'COMPLETION BY CHAPTER')
            .toUpperCase(),
        style: AppTypography.overline(context),
      ),
    );
  }

  // ==================== SURAH COMPLETION TILE ====================

  Widget _buildSurahCompletionTile(Map<String, dynamic> surah) {
    final s = AppDesignSystem.getScaleFactor(context);
    final int id = surah['id'] as int;
    final String name = _getSurahName(surah);
    final int totalVerses = surah['verses_count'] ?? 0;

    final completion = _getCompletion(id);
    final percentage = completion?.percentage ?? 0.0;
    final versesRead = completion?.versesRead ?? 0;

    // Calculate remaining ranges
    String remainingText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'completion.not_started_text')
        : 'Not started';

    if (versesRead > 0 && versesRead < totalVerses) {
      final remLabel = _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'completion.remaining_text')
          : 'Remaining';
      // RTL: 10-1 bukan 1-10
      remainingText =
          '$remLabel: ${_formatRTLRange(versesRead + 1, totalVerses)}';
    } else if (versesRead >= totalVerses) {
      remainingText = _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'completion.none_remaining_text')
          : 'Completed';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToSurah(id),
        splashColor: AppComponentStyles.rippleColor,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space16 * s,
            vertical: AppDesignSystem.space12 * s,
          ),
          decoration: AppComponentStyles.divider(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: _isRTL
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            '$name - ${context.formatNumber(percentage.toStringAsFixed(0))}% (${_formatRTLNumber(versesRead, totalVerses)})',
                            style: AppTypography.body(
                              context,
                              weight: AppTypography.semiBold,
                            ),
                          ),
                        ),
                        SizedBox(height: AppDesignSystem.space2 * s),
                        Directionality(
                          textDirection: _isRTL
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            remainingText,
                            style: AppTypography.captionSmall(
                              context,
                              color: AppColors.getTextTertiary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isRTL
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: AppColors.getBorderMedium(context),
                    size: AppDesignSystem.iconMedium * s,
                  ),
                ],
              ),

              SizedBox(height: AppDesignSystem.space8 * s),

              // Progress Bar
              Directionality(
                textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusRound * s,
                  ),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 6 * s,
                    backgroundColor: AppColors.getSurfaceContainerLowest(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage >= 100
                          ? AppColors.getSuccess(context)
                          : percentage >= 50
                          ? AppColors.getPrimary(context)
                          : percentage > 0
                          ? AppColors.getWarning(context)
                          : AppColors.getBorderMedium(context),
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

  // ==================== ERROR BANNER ====================

  Widget _buildErrorBanner() {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      margin: EdgeInsets.all(AppDesignSystem.space16 * s),
      padding: EdgeInsets.all(AppDesignSystem.space12 * s),
      decoration: BoxDecoration(
        color: AppColors.getError(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
        border: Border.all(color: AppColors.getError(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppColors.getError(context), size: 20 * s),
          SizedBox(width: AppDesignSystem.space8 * s),
          Expanded(
            child: Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(
                      _translations,
                      'completion.error_offline_text',
                    )
                  : 'Using offline data. Pull to refresh.',
              style: AppTypography.caption(context, color: AppColors.getError(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PROGRESS CIRCLE SECTION ====================

  Widget _buildProgressSection() {
    final s = AppDesignSystem.getScaleFactor(context);
    final percentage = _stats.overallPercentage;

    return Container(
      margin: EdgeInsets.all(AppDesignSystem.space16 * s),
      padding: EdgeInsets.all(AppDesignSystem.space16 * s),
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
          // Circular Progress Chart
          SizedBox(
            height: 160 * s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: percentage > 0 ? percentage : 0.1,
                        color: AppColors.getPrimary(context),
                        radius: 24 * s,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: percentage < 100 ? (100 - percentage) : 0.1,
                        color: AppColors.getPrimary(context).withValues(alpha: 0.15),
                        radius: 24 * s,
                        showTitle: false,
                      ),
                    ],
                    sectionsSpace: 0,
                    centerSpaceRadius: 56 * s,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${context.formatNumber(percentage.toStringAsFixed(1))}%',
                      style: AppTypography.h2(
                        context,
                        weight: AppTypography.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: AppDesignSystem.space12 * s),

          Column(
            children: [
              Text(
                _translations.isNotEmpty
                    ? LanguageHelper.tr(
                        _translations,
                        'completion.completeion_banner',
                      )
                    : 'Complete the Quran',
                style: AppTypography.title(
                  context,
                  weight: AppTypography.semiBold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              Text(
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'completion.khatm_text')
                    : '(khatm)',
                style: AppTypography.body(
                  context,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),

          SizedBox(height: AppDesignSystem.space16 * s),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'completion.total_pages_text',
                        )
                      : 'Verses Read',
                  value: context.formatNumber(_stats.totalVersesRead),
                ),
              ),
              SizedBox(width: AppDesignSystem.space8 * s),
              Expanded(
                child: _buildStatCard(
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'completion.Remaining_pages_textq',
                        )
                      : 'Remaining',
                  value: context.formatNumber(
                    _stats.totalQuranVerses - _stats.totalVersesRead,
                  ),
                ),
              ),
              SizedBox(width: AppDesignSystem.space8 * s),
              Expanded(
                child: _buildStatCard(
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'completion.completions_text',
                        )
                      : 'Completed',
                  value:
                      '${context.formatNumber(_stats.completedSurahs)} ${_translations.isNotEmpty ? LanguageHelper.tr(_translations, 'completion.surah_text') : 'Surah'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String label, required String value}) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space8 * s,
        vertical: AppDesignSystem.space12 * s,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLowest(context),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.captionSmall(
              context,
              color: AppColors.getTextTertiary(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppDesignSystem.space4 * s),
          Directionality(
            textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: Text(
              value,
              style: AppTypography.titleLarge(
                context,
                weight: AppTypography.bold,
                color: AppColors.getTextPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONTINUE READING BUTTON ====================

  Widget _buildContinueReading() {
    final s = AppDesignSystem.getScaleFactor(context);

    // Don't show if no reading history
    if (_completionData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space16 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'completion.continue_reading_text',
                  )
                : 'Continue Reading',
            style: AppTypography.title(
              context, 
              weight: AppTypography.semiBold,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          SizedBox(height: AppDesignSystem.space8 * s),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _continueReading,
              borderRadius: BorderRadius.circular(
                AppDesignSystem.radiusMedium * s,
              ),
              child: Container(
                padding: EdgeInsets.all(AppDesignSystem.space16 * s),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(context),
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusMedium * s,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_stories,
                      color: AppColors.getTextInverse(context),
                      size: AppDesignSystem.iconXLarge * s,
                    ),
                    SizedBox(width: AppDesignSystem.space12 * s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Directionality(
                            textDirection: _isRTL
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            child: Text(
                              '${_lastRead.surahName}, ${_translations.isNotEmpty ? LanguageHelper.tr(_translations, 'completion.page_text') : 'Ayah'} ${context.formatNumber(_lastRead.ayah)}',
                              style: AppTypography.body(
                                context,
                                color: AppColors.getTextInverse(context),
                                weight: AppTypography.semiBold,
                              ),
                            ),
                          ),
                          SizedBox(height: AppDesignSystem.space2 * s),
                          Directionality(
                            textDirection: _isRTL
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            child: Text(
                              '${_translations.isNotEmpty ? LanguageHelper.tr(_translations, 'completion.surah_text') : 'Surah'} ${context.formatNumber(_lastRead.surahId)}',
                              style: AppTypography.captionSmall(
                                context,
                                color: AppColors.getTextInverse(context).withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isRTL
                          ? Icons.arrow_back_ios_rounded
                          : Icons.arrow_forward_ios_rounded,
                      color: AppColors.getTextInverse(context),
                      size: AppDesignSystem.iconSmall * s,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: AppDesignSystem.space16 * s),
        ],
      ),
    );
  }

  // ==================== FILTER SECTION ====================

  Widget _buildFilterSection() {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space16 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(
                AppDesignSystem.radiusMedium * s,
              ),
              border: Border.all(
                color: _searchController.text.isNotEmpty
                    ? AppColors.getBorderFocus(context)
                    : AppColors.getBorderMedium(context),
                width: AppDesignSystem.borderNormal * s,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: AppTypography.body(context),
              textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                hintText: _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'completion.search_text')
                    : 'Search by surah',
                hintStyle: AppTypography.body(
                  context,
                  color: AppColors.getTextSecondary(context),
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(
                    left: _isRTL ? 0 : AppDesignSystem.space12 * s,
                    right: _isRTL
                        ? AppDesignSystem.space12 * s
                        : AppDesignSystem.space8 * s,
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: _searchController.text.isNotEmpty
                        ? AppColors.getPrimary(context)
                        : AppColors.getTextTertiary(context),
                    size: AppDesignSystem.iconMedium * s,
                  ),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: AppDesignSystem.iconMedium * s,
                        ),
                        onPressed: () {
                          AppHaptics.light();
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: AppDesignSystem.space12 * s,
                  horizontal: AppDesignSystem.space4 * s,
                ),
              ),
            ),
          ),

          SizedBox(height: AppDesignSystem.space12 * s),

          // Filter Toggles
          Directionality(
            textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: Row(
              children: [
                _buildFilterToggle(
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'completion.complete_text',
                        )
                      : 'Complete',
                  isSelected: _filterComplete,
                  onTap: () => _toggleFilter('complete'),
                ),
                SizedBox(width: AppDesignSystem.space8 * s),
                _buildFilterToggle(
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'completion.started_text',
                        )
                      : 'In Progress',
                  isSelected: _filterStarted,
                  onTap: () => _toggleFilter('started'),
                ),
                SizedBox(width: AppDesignSystem.space8 * s),
                _buildFilterToggle(
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'completion.incomplete_text',
                        )
                      : 'Not Started',
                  isSelected: _filterIncomplete,
                  onTap: () => _toggleFilter('incomplete'),
                ),
              ],
            ),
          ),

          SizedBox(height: AppDesignSystem.space16 * s),
        ],
      ),
    );
  }

  Widget _buildFilterToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
        child: AnimatedContainer(
          duration: AppDesignSystem.durationFast,
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space10 * s,
            vertical: AppDesignSystem.space6 * s,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.getPrimary(context)
                : AppColors.getSurfaceContainerLowest(context),
            borderRadius: BorderRadius.circular(
              AppDesignSystem.radiusSmall * s,
            ),
            border: Border.all(
              color: isSelected ? AppColors.getPrimary(context) : AppColors.getBorderMedium(context),
              width: AppDesignSystem.borderNormal * s,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: AppDesignSystem.iconSmall * s,
                color: isSelected ? AppColors.getTextInverse(context) : AppColors.getTextTertiary(context),
              ),
              SizedBox(width: AppDesignSystem.space4 * s),
              Text(
                label,
                style: AppTypography.labelSmall(
                  context,
                  color: isSelected ? AppColors.getTextInverse(context) : AppColors.getTextSecondary(context),
                  weight: AppTypography.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
