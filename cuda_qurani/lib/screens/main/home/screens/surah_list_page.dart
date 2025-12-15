// lib/screens/main/home/screens/surah_list_page.dart

import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/screens/main/home/services/juz_service.dart';
import 'package:cuda_qurani/screens/main/stt/stt_page.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'dart:async';

enum TabType { surah, juz, page }

enum SlideDirection { leftToRight, rightToLeft }

class SurahListPage extends StatefulWidget {
  const SurahListPage({super.key});

  @override
  State<SurahListPage> createState() => _SurahListPageState();
}

class _SurahListPageState extends State<SurahListPage> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('home/surah_list');
    setState(() {
      _translations = trans;
    });
  }

  TabType _currentTab = TabType.surah;
  final TextEditingController _searchController = TextEditingController();
  final MetadataCacheService _cache = MetadataCacheService();

  TabType _previousTab = TabType.surah;

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchLoading = false;
  Timer? _searchDebounce;

  // ✅ Data langsung dari cache (NO LOADING)
  late List<Map<String, dynamic>> _surahs;
  late List<Map<String, dynamic>> _juz;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _searchController.addListener(_onSearchChanged);

    // ✅ Load dari cache (instant)
    _loadFromCache();
  }

  void _loadFromCache() {
    if (_cache.isInitialized) {
      setState(() {
        _surahs = _cache.allSurahs;
        _juz = _cache.allJuz;
        _isInitialized = true;
      });
      print(
        '[SurahList] ✅ Loaded ${_surahs.length} surahs + ${_juz.length} juz from cache (INSTANT)',
      );
    } else {
      // Fallback: initialize cache on-demand
      print('[SurahList] ⚠️ Cache not ready, initializing...');
      _cache.initialize().then((_) {
        if (mounted) {
          _loadFromCache();
        }
      });
    }
  }

  SlideDirection _getSlideDirection(TabType from, TabType to) {
    final tabs = [TabType.surah, TabType.juz, TabType.page];
    final fromIndex = tabs.indexOf(from);
    final toIndex = tabs.indexOf(to);

    return toIndex > fromIndex
        ? SlideDirection.leftToRight
        : SlideDirection.rightToLeft;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty && _isSearching) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isSearchLoading = true;
    });

    try {
      final results = <Map<String, dynamic>>[];
      final numQuery = int.tryParse(query.trim());

      // Search Juz by number (from cache)
      if (numQuery != null && numQuery >= 1 && numQuery <= 30) {
        final juzData = _cache.getJuz(numQuery);
        if (juzData != null) {
          results.add({'type': 'juz', ...juzData});
        }
      }

      // Search Page by number
      // Search Page by number (dynamic based on active layout)
      final maxPages = MushafSettingsService().getMushafLayout().then(
        (layout) => layout.totalPages,
      );
      if (numQuery != null && numQuery >= 1 && numQuery <= 610) {
        // Max possible pages
        results.add({'type': 'page', 'page_number': numQuery});
      }

      // Search Surah by number (from cache)
      if (numQuery != null && numQuery >= 1 && numQuery <= 114) {
        final surahMeta = _cache.getSurah(numQuery);
        if (surahMeta != null) {
          results.add({'type': 'surah', ...surahMeta});
        }
      }

      // Search by text (database query for verses)
      final textResults = await LocalDatabaseService.searchVerses(query);
      for (final result in textResults) {
        if (result['match_type'] == 'surah_name') {
          final surahNum = result['surah_number'] as int;
          if (!results.any(
            (r) => r['type'] == 'surah' && r['id'] == surahNum,
          )) {
            final surahMeta = _cache.getSurah(surahNum);
            if (surahMeta != null) {
              results.add({'type': 'surah', ...surahMeta});
            }
          }
        } else {
          results.add({'type': 'verse', ...result});
        }
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Search] Error: $e');
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
    }
  }

  // ==================== NAVIGATION ====================

  Future<void> _openSurah(BuildContext context, int surahId) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SttPage(suratId: surahId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.02),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _openPage(BuildContext context, int pageNumber) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SttPage(pageId: pageNumber),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.02),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _openSurahAtAyah(
    BuildContext context,
    int surahId,
    int ayahNumber,
  ) async {
    final page = await LocalDatabaseService.getPageNumber(surahId, ayahNumber);
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SttPage(pageId: page),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.02),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _openJuz(
    BuildContext context,
    int juzNumber,
    String firstVerseKey,
  ) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SttPage(juzId: juzNumber),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.02),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    // ✅ Show loading ONLY if cache not ready yet
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.surfaceVariant,
        appBar: MenuAppBar(selectedIndex: 1),
        body: const AppLoadingIndicator(message: 'Loading metadata...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: MenuAppBar(selectedIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (!_isSearching) _buildTabBar(),
            Expanded(child: _buildBodyContent()),
          ],
        ),
      ),
    );
  }

  // ==================== SEARCH BAR ====================
  Widget _buildSearchBar() {
    final s = AppDesignSystem.getScaleFactor(context);
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space20 * s,
        vertical: AppDesignSystem.space20 * s,
      ),
      child: Container(
        height: 38 * s,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
          border: Border.all(
            color: _searchController.text.isNotEmpty
                ? AppColors.borderFocus
                : Colors.transparent,
            width: AppDesignSystem.borderThick * s,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          children: [
            // PREFIX ICON
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.space12 * s,
              ),
              child: Icon(
                Icons.search_rounded,
                color: _searchController.text.isNotEmpty
                    ? AppColors.primary
                    : AppColors.textTertiary,
                size: AppDesignSystem.iconMedium * s,
              ),
            ),

            // TEXT FIELD
            Expanded(
              child: TextField(
                controller: _searchController,
                style: AppTypography.body(
                  context,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintText: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'surah_list.search_text',
                        )
                      : 'Search surah, juz, or page...',
                  hintStyle: AppTypography.body(
                    context,
                    color: AppColors.textHint,
                    weight: AppTypography.regular,
                  ),
                ),
              ),
            ),

            // SUFFIX ICON
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textTertiary,
                  size: AppDesignSystem.iconMedium * s,
                ),
                onPressed: () {
                  AppHaptics.light();
                  _searchController.clear();
                  setState(() {
                    _isSearching = false;
                    _searchResults = [];
                  });
                },
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.space12 * s,
                ),
                constraints: BoxConstraints(),
                splashRadius: 20 * s,
              )
            else
              SizedBox(width: AppDesignSystem.space12 * s),
          ],
        ),
      ),
    );
  }

  // ==================== SEGMENTED BUTTON TAB BAR ====================

  Widget _buildTabBar() {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.space20 * s),
      child: Column(
        children: [
          // Segmented Button
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(
                AppDesignSystem.radiusSmall * s,
              ),
            ),
            padding: EdgeInsets.all(AppDesignSystem.space4 * s),
            child: Row(
              children: [
                _buildSegmentButton(
                  context: context,
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(
                          _translations,
                          'surah_list.surah_text',
                        )
                      : 'Surah',
                  isSelected: _currentTab == TabType.surah,
                  onTap: () {
                    AppHaptics.light();
                    setState(() {
                      _previousTab = _currentTab;
                      _currentTab = TabType.surah;
                    });
                  },
                  s: s,
                ),
                SizedBox(width: AppDesignSystem.space4 * s),
                _buildSegmentButton(
                  context: context,
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(_translations, 'surah_list.juz_text')
                      : 'Juz',
                  isSelected: _currentTab == TabType.juz,
                  onTap: () {
                    AppHaptics.light();
                    setState(() {
                      _previousTab = _currentTab;
                      _currentTab = TabType.juz;
                    });
                  },
                  s: s,
                ),
                SizedBox(width: AppDesignSystem.space4 * s),
                _buildSegmentButton(
                  context: context,
                  label: _translations.isNotEmpty
                      ? LanguageHelper.tr(_translations, 'surah_list.page_text')
                      : 'Page',
                  isSelected: _currentTab == TabType.page,
                  onTap: () {
                    AppHaptics.light();
                    setState(() {
                      _previousTab = _currentTab;
                      _currentTab = TabType.page;
                    });
                  },
                  s: s,
                ),
              ],
            ),
          ),

          // Bottom divider
          SizedBox(height: AppDesignSystem.space12 * s),
          Container(height: 1 * s, color: AppColors.borderLight),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required double s,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDesignSystem.durationFast,
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: AppDesignSystem.space10 * s),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(
              AppDesignSystem.radiusSmall * s,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.label(
              context,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
              weight: isSelected
                  ? AppTypography.semiBold
                  : AppTypography.medium,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BODY CONTENT ====================

  Widget _buildBodyContent() {
    if (_isSearching) {
      return _buildSearchResults();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(
        key: ValueKey<TabType>(_currentTab),
        child: Builder(
          builder: (context) {
            switch (_currentTab) {
              case TabType.surah:
                return _buildSurahList();
              case TabType.juz:
                return _buildJuzList();
              case TabType.page:
                return _buildPageList();
            }
          },
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    // Key unik agar AnimatedSwitcher detect perubahan
    return KeyedSubtree(
      key: ValueKey<TabType>(_currentTab),
      child: Builder(
        builder: (context) {
          switch (_currentTab) {
            case TabType.surah:
              return _buildSurahList();
            case TabType.juz:
              return _buildJuzList();
            case TabType.page:
              return _buildPageList();
          }
        },
      ),
    );
  }

  // ==================== SURAH LIST ====================

  Widget _buildSurahList() {
    final s = AppDesignSystem.getScaleFactor(context);
    // ✅ Check if current language is Arabic
    final isArabic = context.currentLanguage == 'ar';

    return _OptimizedList(
      itemCount: _surahs.length,
      totalItems: 114,
      onItemTap: (index) => _openSurah(context, _surahs[index]['id'] as int),
      itemBuilder: (context, index) {
        final surah = _surahs[index];
        final int id = surah['id'] as int;
        // ✅ Use name_arabic if language is Arabic, otherwise use name_simple
        final String name = isArabic
            ? (surah['name_arabic'] ?? surah['name_simple'] ?? 'Surah $id')
            : (surah['name_simple'] ?? 'Surah $id');
        final int ayat = surah['verses_count'] ?? 0;
        final String place = (surah['revelation_place'] ?? '')
            .toString()
            .toLowerCase();
        final String type = place == 'makkah' || place == 'mecca'
            ? _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'surah_list.makkah_text')
                  : 'Makkiyah'
            : place == 'madinah' || place == 'medina'
            ? _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'surah_list.madinah_text')
                  : 'Madaniyah'
            : (id < 90
                  ? _translations.isNotEmpty
                        ? LanguageHelper.tr(
                            _translations,
                            'surah_list.makkah_text',
                          )
                        : 'Makkiyah'
                  : _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'surah_list.madinah_text')
                  : 'Madinah');
        final ayahText = _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'surah_list.ayah_text')
            : 'Ayat';

        return AppListTile(
          leading: AppNumberBadge(number: context.formatNumber(id)),
          title: name,
          subtitle: '$type · ${context.formatNumber(ayat)} $ayahText',
          trailing: Text(
            'surah${id.toString().padLeft(3, '0')}',
            style: AppTypography.surahName(context),
          ),
        );
      },
    );
  }

  // ==================== JUZ LIST ====================

  Widget _buildJuzList() {
    return _OptimizedList(
      itemCount: _juz.length,
      totalItems: 30,
      onItemTap: (index) {
        final juz = _juz[index];
        _openJuz(
          context,
          juz['juz_number'] as int,
          juz['first_verse_key'] as String,
        );
      },
      itemBuilder: (context, index) {
        final juz = _juz[index];
        final int juzNum = juz['juz_number'] as int;
        final String firstVerse = juz['first_verse_key'] as String;
        final String lastVerse = juz['last_verse_key'] as String;
        final int verseCount = juz['verses_count'] as int;
        final juzText = _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, "surah_list.juz_text")
            : "Juz";
        final ayatText = _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, "surah_list.ayah_text")
            : "Ayah";

        return AppListTile(
          leading: AppNumberBadge(number: context.formatNumber(juzNum)),

          title: '$juzText ${context.formatNumber(juzNum)}',

          subtitle:
              '${context.formatNumber(firstVerse)} - ${context.formatNumber(lastVerse)}',
          trailing: AppChip(
            label: '${context.formatNumber(verseCount)} $ayatText',
          ),
        );
      },
    );
  }

  // ==================== PAGE LIST ====================

  Widget _buildPageList() {
    return _OptimizedPageList(
      onPageTap: (pageNum) => _openPage(context, pageNum),
      cache: _cache,
    );
  }

  // ==================== SEARCH RESULTS ====================

  Widget _buildSearchResults() {
    final s = AppDesignSystem.getScaleFactor(context);

    if (_isSearchLoading) {
      return const AppLoadingIndicator();
    }

    if (_searchResults.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'surah_list.null_result_text')
            : 'No Results Found',
        subtitle: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'surah_list.null_result_desc')
            : 'Try searching with different keywords',
      );
    }

    final juzResults = _searchResults.where((r) => r['type'] == 'juz').toList();
    final pageResults = _searchResults
        .where((r) => r['type'] == 'page')
        .toList();
    final surahResults = _searchResults
        .where((r) => r['type'] == 'surah')
        .toList();
    final verseResults = _searchResults
        .where((r) => r['type'] == 'verse')
        .toList();

    return ListView(
      padding: EdgeInsets.only(
        top: AppDesignSystem.space12 * s,
        bottom: AppDesignSystem.space32 * s,
      ),
      children: [
        if (juzResults.isNotEmpty) ...[
          AppCategoryHeader(
            title: _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'surah_list.juz_text',
                  ).toUpperCase()
                : 'JUZ',
            count: context.formatNumber(juzResults.length), // ✅ Tanpa ${}
          ),
          ...juzResults.map((r) => _buildJuzSearchTile(r)),
          SizedBox(height: AppDesignSystem.space12 * s),
        ],
        if (pageResults.isNotEmpty) ...[
          AppCategoryHeader(
            title: _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'surah_list.page_text',
                  ).toUpperCase()
                : 'PAGE',
            count: context.formatNumber(pageResults.length), // ✅ Tanpa ${}
          ),
          ...pageResults.map((r) => _buildPageSearchTile(r)),
          SizedBox(height: AppDesignSystem.space12 * s),
        ],
        if (surahResults.isNotEmpty) ...[
          AppCategoryHeader(
            title: _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'surah_list.surah_text',
                  ).toUpperCase()
                : 'SURAH',
            count: context.formatNumber(surahResults.length), // ✅ Tanpa ${}
          ),
          ...surahResults.map((r) => _buildSurahSearchTile(r)),
          SizedBox(height: AppDesignSystem.space12 * s),
        ],
        if (verseResults.isNotEmpty) ...[
          AppCategoryHeader(
            title: _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'surah_list.ayah_text',
                  ).toUpperCase()
                : 'VERSES',
            count: context.formatNumber(verseResults.length), // ✅ Tanpa ${}
          ),
          ...verseResults.map((r) => _buildVerseSearchTile(r)),
        ],
      ],
    );
  }

  Widget _buildJuzSearchTile(Map<String, dynamic> r) {
    final juzText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, "surah_list.juz_text")
        : "Juz";
    final ayahText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'surah_list.ayah_text')
        : 'Ayat';
    return AppListTile(
      onTap: () => _openJuz(
        context,
        r['juz_number'] as int,
        r['first_verse_key'] as String,
      ),
      leading: AppIconContainer(icon: Icons.auto_stories_rounded),
      title: '$juzText ${context.formatNumber(r['juz_number'])}',
      subtitle:
          '${context.formatNumber(r['first_verse_key'])} - ${context.formatNumber(r['last_verse_key'])} · ${context.formatNumber(r['verses_count'])} $ayahText',

      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.borderDark,
        size: AppDesignSystem.iconMedium,
      ),
    );
  }

  Widget _buildPageSearchTile(Map<String, dynamic> r) {
    final pageNum = r['page_number'] as int;
    // ✅ Check if current language is Arabic
    final isArabic = context.currentLanguage == 'ar';

    // ✅ Get surah IDs for this page
    final surahIds = _cache.getSurahIdsForPage(pageNum);
    String surahName = 'Unknown Surah';

    if (surahIds.isNotEmpty) {
      final surahData = _cache.getSurah(surahIds.first);
      if (surahData != null) {
        // ✅ Use name_arabic if language is Arabic, otherwise use name_simple
        surahName = isArabic
            ? (surahData['name_arabic'] ??
                  surahData['name_simple'] ??
                  'Unknown Surah')
            : (surahData['name_simple'] ?? 'Unknown Surah');
      }
    }

    final pageText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, "surah_list.page_text")
        : "Page";

    return AppListTile(
      onTap: () => _openPage(context, pageNum),
      leading: AppIconContainer(icon: Icons.description_rounded),
      title: '$pageText ${context.formatNumber(pageNum)}',
      subtitle: surahName,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.borderDark,
        size: AppDesignSystem.iconMedium,
      ),
    );
  }

  Widget _buildSurahSearchTile(Map<String, dynamic> r) {
    final surahId = r['id'] as int;
    // ✅ Check if current language is Arabic
    final isArabic = context.currentLanguage == 'ar';
    // ✅ Use name_arabic if language is Arabic, otherwise use name_simple
    final surahName = isArabic
        ? (r['name_arabic'] ?? r['name_simple'] ?? 'Surah $surahId')
        : (r['name_simple'] as String? ?? 'Surah $surahId');
    final ayahText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'surah_list.ayah_text')
        : 'Ayat';

    return AppListTile(
      onTap: () => _openSurah(context, surahId),
      leading: AppIconContainer(icon: Icons.menu_book_rounded),
      title: '$surahName (${context.formatNumber(surahId)})',
      subtitle: r['verses_count'] != null
          ? '${context.formatNumber(r['verses_count'])} ${ayahText}'
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.borderDark,
        size: AppDesignSystem.iconMedium,
      ),
    );
  }

  Widget _buildVerseSearchTile(Map<String, dynamic> r) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSurahAtAyah(
          context,
          r['surah_number'] as int,
          r['ayah_number'] as int,
        ),
        splashColor: AppComponentStyles.rippleColor,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space20 * s,
            vertical: AppDesignSystem.space16 * s,
          ),
          decoration: AppComponentStyles.divider(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppChip(label: '${r['surah_name']} : ${r['ayah_number']}'),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.borderDark,
                    size: AppDesignSystem.iconMedium * s,
                  ),
                ],
              ),
              SizedBox(height: AppDesignSystem.space12 * s),
              Text(
                r['text'] as String,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: AppTypography.arabic(context),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== OPTIMIZED LIST WITH SLIDER ====================

class _OptimizedList extends StatefulWidget {
  final int itemCount;
  final int totalItems;
  final Function(int) onItemTap;
  final Widget Function(BuildContext, int) itemBuilder;

  const _OptimizedList({
    required this.itemCount,
    required this.totalItems,
    required this.onItemTap,
    required this.itemBuilder,
  });

  @override
  State<_OptimizedList> createState() => _OptimizedListState();
}

class _OptimizedListState extends State<_OptimizedList> {
  final ScrollController _scrollController = ScrollController();
  bool _isJumping = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToItem(int itemNumber) {
    if (_isJumping) return;

    setState(() => _isJumping = true);

    final itemHeight = 70.0;
    final targetOffset = (itemNumber - 1) * itemHeight;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isJumping = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: AppDesignSystem.space4 * s,
            bottom: AppDesignSystem.space32 * s,
            right: 30 * s,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () => widget.onItemTap(index),
              child: widget.itemBuilder(context, index),
            );
          },
        ),

        // ✅ Global Slider
        Positioned(
          right: 8 * s,
          top: 8 * s,
          bottom: 8 * s,
          child: _GlobalSlider(
            totalItems: widget.totalItems,
            onItemSelected: _jumpToItem,
          ),
        ),
      ],
    );
  }
}

// ==================== OPTIMIZED PAGE LIST ====================

class _OptimizedPageList extends StatefulWidget {
  final Function(int) onPageTap;
  final MetadataCacheService cache;

  const _OptimizedPageList({required this.onPageTap, required this.cache});

  @override
  State<_OptimizedPageList> createState() => _OptimizedPageListState();
}

class _OptimizedPageListState extends State<_OptimizedPageList> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('home/surah_list');
    setState(() {
      _translations = trans;
    });
  }

  final ScrollController _scrollController = ScrollController();
  late int totalPages;

  int _visibleStart = 0;
  int _visibleEnd = 100;
  bool _isJumping = false;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _scrollController.addListener(_onScroll);
    _loadTotalPages(); // ✅ ADD: Load dynamic total pages
  }

  Future<void> _loadTotalPages() async {
    final layout = await MushafSettingsService().getMushafLayout();
    setState(() {
      totalPages = layout.totalPages;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isJumping) return;

    final position = _scrollController.position;
    final itemHeight = 70.0;
    final screenHeight = MediaQuery.of(context).size.height;

    final firstVisible = (position.pixels / itemHeight).floor();
    final lastVisible = ((position.pixels + screenHeight) / itemHeight).ceil();

    const buffer = 50;
    final newStart = (firstVisible - buffer).clamp(0, totalPages);
    final newEnd = (lastVisible + buffer).clamp(0, totalPages);

    if (newStart != _visibleStart || newEnd != _visibleEnd) {
      setState(() {
        _visibleStart = newStart;
        _visibleEnd = newEnd;
      });
    }
  }

  void _jumpToPage(int pageNumber) {
    setState(() => _isJumping = true);

    final itemHeight = 70.0;
    final targetOffset = (pageNumber - 1) * itemHeight;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isJumping = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    // ✅ Check if current language is Arabic
    final isArabic = context.currentLanguage == 'ar';

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: AppDesignSystem.space4 * s,
            bottom: AppDesignSystem.space32 * s,
            right: 30 * s,
          ),
          itemCount: totalPages,
          itemBuilder: (context, index) {
            final pageNum = index + 1;

            // Virtual scrolling
            if (pageNum < _visibleStart || pageNum > _visibleEnd) {
              return SizedBox(height: 70 * s);
            }

            // ✅ Get surah IDs for this page
            final surahIds = widget.cache.getSurahIdsForPage(pageNum);
            String surahName = 'Unknown Surah';

            if (surahIds.isNotEmpty) {
              final surahData = widget.cache.getSurah(surahIds.first);
              if (surahData != null) {
                // ✅ Use name_arabic if language is Arabic, otherwise use name_simple
                surahName = isArabic
                    ? (surahData['name_arabic'] ??
                          surahData['name_simple'] ??
                          'Unknown Surah')
                    : (surahData['name_simple'] ?? 'Unknown Surah');
              }
            }

            final pageText = _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, "surah_list.page_text")
                : "Page";

            return AppListTile(
              onTap: () => widget.onPageTap(pageNum),
              leading: AppNumberBadge(number: context.formatNumber(pageNum)),
              title: '$pageText ${context.formatNumber(pageNum)}',
              subtitle: surahName,
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.borderDark,
                size: AppDesignSystem.iconMedium,
              ),
            );
          },
        ),

        // ✅ Global Slider
        Positioned(
          right: 8 * s,
          top: 8 * s,
          bottom: 8 * s,
          child: _GlobalSlider(
            totalItems: totalPages,
            onItemSelected: _jumpToPage,
          ),
        ),
      ],
    );
  }
}

// ==================== GLOBAL SLIDER COMPONENT ====================

class _GlobalSlider extends StatefulWidget {
  final int totalItems;
  final Function(int) onItemSelected;

  const _GlobalSlider({required this.totalItems, required this.onItemSelected});

  @override
  State<_GlobalSlider> createState() => _GlobalSliderState();
}

class _GlobalSliderState extends State<_GlobalSlider> {
  double _dragPosition = 0.0;
  bool _isDragging = false;
  int? _currentItem;

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderHeight = constraints.maxHeight;

        return GestureDetector(
          onVerticalDragStart: (details) {
            setState(() => _isDragging = true);
            _updateItem(details.localPosition.dy, sliderHeight);
          },
          onVerticalDragUpdate: (details) {
            _updateItem(details.localPosition.dy, sliderHeight);
          },
          onVerticalDragEnd: (_) {
            if (_currentItem != null) {
              widget.onItemSelected(_currentItem!);
            }
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _isDragging = false;
                  _currentItem = null;
                });
              }
            });
          },
          child: Container(
            width: 25 * s,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(
                AppDesignSystem.radiusXLarge * s,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track
                Container(
                  width: 4 * s,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2 * s),
                  ),
                ),

                // Current item indicator
                if (_isDragging && _currentItem != null)
                  Positioned(
                    top: _dragPosition - 15 * s,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * s,
                        vertical: 4 * s,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(
                          AppDesignSystem.radiusSmall * s,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowDark,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _currentItem.toString(),
                        style: AppTypography.labelSmall(
                          context,
                          color: Colors.white,
                          weight: AppTypography.bold,
                        ),
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

  void _updateItem(double position, double sliderHeight) {
    final clampedPosition = position.clamp(0.0, sliderHeight);
    final ratio = clampedPosition / sliderHeight;
    final item = (ratio * widget.totalItems).round() + 1;

    setState(() {
      _dragPosition = clampedPosition;
      _currentItem = item.clamp(1, widget.totalItems);
    });
  }
}
