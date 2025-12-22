// lib/screens/main/stt/widgets/list_view.dart
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/models/quran_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../data/models.dart';
import '../services/quran_service.dart';
import '../utils/constants.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'dart:async';

/// Optimized vertical Quran reading mode with aggressive background preloading
class QuranListView extends StatefulWidget {
  const QuranListView({Key? key}) : super(key: key);

  @override
  State<QuranListView> createState() => _QuranListViewState();
}

class _QuranListViewState extends State<QuranListView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _pageKeys = {};

  // ✅ NEW: State variables sesuai algoritma
  int _currentVisiblePage = 1;
  bool _userScrolling = false;
  bool _preloadPaused = false;
  Timer? _debounceTimer;
  bool _hasJumped = false;

  // ✅ Background preloading state
  bool _isPreloading = false;
  int _preloadProgress = 0;

  // ✅ NEW: Track visible widgets for accurate page detection
  final GlobalKey _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasJumped) return;

      final controller = context.read<SttController>();
      final targetPage = controller.listViewCurrentPage;

      print('🔍 LIST_VIEW_INIT: Jumping to saved position: $targetPage');
      _jumpToPage(targetPage);
      _currentVisiblePage = targetPage;
      _hasJumped = true;

      // ✅ Load immediate visible range (±3 pages)
      final immediateBatch = _buildPageRange(
        targetPage - 3,
        targetPage + 3,
        controller.totalPages,
      );
      _loadImmediateRange(immediateBatch);

      // ✅ Start background preload pipeline
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _startPreloadPipeline(targetPage);
      });
    });
  }

  /// ✅ UPDATED: Support batch loading dari pipeline
  Future<void> _loadImmediateRange(List<int> pageNumbers) async {
    if (!mounted || pageNumbers.isEmpty) return;

    final controller = context.read<SttController>();
    final service = context.read<QuranService>();

    // Filter pages yang belum di-cache
    final pagesToLoad = pageNumbers
        .where((page) => !controller.pageCache.containsKey(page))
        .toList();

    if (pagesToLoad.isEmpty) return;

    print('📦 IMMEDIATE: Loading ${pagesToLoad.length} pages: $pagesToLoad');

    // Load all pages in parallel
    await Future.wait(
      pagesToLoad.map((page) async {
        if (!mounted || _userScrolling) return; // Stop jika user scroll

        try {
          final lines = await service.getMushafPageLines(page);
          if (mounted && !_userScrolling) {
            controller.updatePageCache(page, lines);
          }
        } catch (e) {
          print('📦 ERROR: Page $page failed: $e');
        }
      }),
    );

    if (mounted) setState(() {});
  }

  void _jumpToPage(int pageNumber) {
    if (!mounted || !_scrollController.hasClients) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final estimatedPageHeight = screenHeight * 0.75;
    final offset = (pageNumber - 1) * estimatedPageHeight;

    _scrollController.jumpTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    // ✅ PHASE 1: Accurate Center Detection (RenderBox Based)
    // Algoritma: Loop key halaman yang aktif, cari yang paling dekat dengan titik tengah layar.
    // Ini 100% akurat karena berbasis posisi render pixel, bukan estimasi offset.

    int? bestPage;
    double closestDistance = double.infinity;
    final screenCenter = MediaQuery.of(context).size.height / 2;

    // Bersihkan key yang sudah didispose (garbage collection manual)
    _pageKeys.removeWhere((_, key) => key.currentContext == null);

    for (final entry in _pageKeys.entries) {
      final key = entry.value;
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        // Titik tengah item halaman ini
        final itemCenter = position.dy + (size.height / 2);

        // Jarak dari tengah layar (app bar diabaikan karena localToGlobal sudah global)
        final distance = (itemCenter - screenCenter).abs();

        if (distance < closestDistance) {
          closestDistance = distance;
          bestPage = entry.key;
        }
      }
    }

    // ✅ PHASE 2: Silent Update
    if (bestPage != null && bestPage != _currentVisiblePage) {
      _currentVisiblePage = bestPage!;

      // Panggil method baru yang ultra-cepat
      context.read<SttController>().updateVisiblePageQuiet(_currentVisiblePage);

      // Sync cache service
      context.read<QuranService>().updateCurrentPage(_currentVisiblePage);
    }

    // ... Logic preloading (StartSmartPreload) bisa tetap dipertahankan ...
    // ... Pastikan logic preloading tidak memanggil notifyListeners() ...

    if (!_userScrolling) {
      _userScrolling = true;
      _preloadPaused = true;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _userScrolling = false;
      _preloadPaused = false;
      // Panggil smart preload
      _startSmartPreload(_currentVisiblePage);
    });
  }

  /// ✅ ULTIMATE: Smart preload (throttled, priority-based)
  Future<void> _startSmartPreload(int centerPage) async {
    if (_preloadPaused || _userScrolling || !mounted) return;

    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;

    // ✅ PHASE 1: Immediate adjacent (±2) - HIGH PRIORITY
    final immediatePages = _buildPageRange(
      centerPage - 2,
      centerPage + 2,
      totalPages,
    );
    if (immediatePages.isNotEmpty) {
      await _loadBatchThrottled(immediatePages, delayMs: 0);
    }

    // ✅ CHECK: Stop if user scrolled again
    if (_userScrolling || !mounted) return;

    // ✅ PHASE 2: Near range (±5) - MEDIUM PRIORITY
    final nearPages = _buildPageRange(
      centerPage - 5,
      centerPage + 5,
      totalPages,
    )..removeWhere((p) => immediatePages.contains(p));
    if (nearPages.isNotEmpty) {
      await _loadBatchThrottled(nearPages, delayMs: 100);
    }

    // ✅ CHECK: Stop if user scrolled again
    if (_userScrolling || !mounted) return;

    // ✅ PHASE 3: Background expansion - LOW PRIORITY (very slow)
    final expandPages = _buildExpandingRange(centerPage, totalPages);
    if (expandPages.isNotEmpty) {
      await _loadBatchThrottled(expandPages, delayMs: 200, maxBatchSize: 5);
    }
  }

  /// ✅ NEW: Throttled batch loading (prevent database overload)
  Future<void> _loadBatchThrottled(
    List<int> pages, {
    int delayMs = 50,
    int maxBatchSize = 10,
  }) async {
    if (pages.isEmpty || !mounted) return;

    final controller = context.read<SttController>();
    final service = context.read<QuranService>();

    // ✅ CRITICAL: Load in small chunks (prevent DB lock)
    for (int i = 0; i < pages.length; i += maxBatchSize) {
      if (_userScrolling || !mounted) return; // ✅ Stop if user scrolls

      final chunk = pages.skip(i).take(maxBatchSize).toList();
      final uncachedPages = chunk
          .where((p) => !controller.pageCache.containsKey(p))
          .toList();

      if (uncachedPages.isEmpty) continue;

      // ✅ Load chunk with minimal parallelism (2-3 at a time)
      for (int j = 0; j < uncachedPages.length; j += 3) {
        if (_userScrolling || !mounted) return;

        final miniChunk = uncachedPages.skip(j).take(3).toList();
        await Future.wait(
          miniChunk.map((page) async {
            if (_userScrolling || !mounted) return;

            try {
              final lines = await service.getMushafPageLines(page);
              if (mounted && !_userScrolling) {
                controller.updatePageCache(page, lines);
              }
            } catch (e) {
              // Silent fail
            }
          }),
        );

        // ✅ Throttle between mini-chunks (give UI thread breathing room)
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  /// ✅ NEW: Calculate which page is MOST visible (bukan estimasi offset)
  int _calculateVisiblePage() {
    if (!mounted || !_scrollController.hasClients) return _currentVisiblePage;

    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✅ Viewport boundaries
    final viewportTop = _scrollController.offset;
    final viewportBottom = viewportTop + screenHeight;

    // ✅ Estimated page height (same as item builder)
    final estimatedPageHeight = screenHeight * 0.75;

    // ✅ Check pages within visible range (current ± 1)
    final centerPage = (viewportTop / estimatedPageHeight).round() + 1;
    final candidatePages = [
      centerPage - 1,
      centerPage,
      centerPage + 1,
    ].where((p) => p >= 1 && p <= totalPages).toList();

    // ✅ Find page with largest visible portion
    int bestPage = _currentVisiblePage;
    double maxVisibleHeight = 0;

    for (final pageNum in candidatePages) {
      final pageTop = (pageNum - 1) * estimatedPageHeight;
      final pageBottom = pageTop + estimatedPageHeight;

      // ✅ Calculate visible portion (intersection)
      final visibleHeight = _calculateVisiblePortion(
        pageTop,
        pageBottom,
        viewportTop,
        viewportBottom,
      );

      if (visibleHeight > maxVisibleHeight) {
        maxVisibleHeight = visibleHeight;
        bestPage = pageNum;
      }
    }

    return bestPage.clamp(1, totalPages);
  }

  /// ✅ NEW: Calculate visible portion of a page
  double _calculateVisiblePortion(
    double pageTop,
    double pageBottom,
    double viewportTop,
    double viewportBottom,
  ) {
    final visibleTop = pageTop > viewportTop ? pageTop : viewportTop;
    final visibleBottom = pageBottom < viewportBottom
        ? pageBottom
        : viewportBottom;

    return (visibleBottom - visibleTop).clamp(0.0, double.infinity);
  }

  /// ✅ NEW: Start preload pipeline dengan prioritas (ALGORITMA BARU)
  Future<void> _startPreloadPipeline(int centerPage) async {
    if (_preloadPaused || _userScrolling || !mounted) return;

    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;

    // ✅ PRIORITY LIST sesuai algoritma
    final List<List<int>> priorityBatches = [
      // Priority 1: Immediate adjacent (±2 pages)
      _buildPageRange(centerPage - 2, centerPage + 2, totalPages),

      // Priority 2: Near range (±5 pages)
      _buildPageRange(centerPage - 5, centerPage + 5, totalPages),

      // Priority 3: Expanding outward (remaining pages)
      _buildExpandingRange(centerPage, totalPages),
    ];

    // ✅ Load each batch (max 10 pages per batch)
    for (final batch in priorityBatches) {
      if (_userScrolling || !mounted) return; // Stop jika user scroll lagi

      // Split batch into chunks of 10
      for (int i = 0; i < batch.length; i += 10) {
        if (_userScrolling || !mounted) return;

        final chunk = batch.skip(i).take(10).toList();
        await _loadImmediateRange(chunk);

        // ✅ Beri nafas ke UI thread
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// ✅ NEW: Build page range (filter already cached)
  List<int> _buildPageRange(int start, int end, int totalPages) {
    final controller = context.read<SttController>();
    final pages = <int>[];

    for (int p = start; p <= end; p++) {
      if (p >= 1 && p <= totalPages && !controller.pageCache.containsKey(p)) {
        pages.add(p);
      }
    }

    return pages;
  }

  /// ✅ NEW: Build expanding range (spiral outward dari center)
  List<int> _buildExpandingRange(int centerPage, int totalPages) {
    final controller = context.read<SttController>();
    final pages = <int>[];

    // Expand in both directions
    for (int distance = 6; distance < totalPages; distance++) {
      final prevPage = centerPage - distance;
      final nextPage = centerPage + distance;

      if (prevPage >= 1 && !controller.pageCache.containsKey(prevPage)) {
        pages.add(prevPage);
      }
      if (nextPage <= totalPages &&
          !controller.pageCache.containsKey(nextPage)) {
        pages.add(nextPage);
      }
    }

    return pages;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // ✅ UBAH: dari _scrollEndTimer
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;

    return ListView.builder(
      controller: _scrollController,
      itemCount: totalPages,
      cacheExtent: 2000,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final pageNumber = index + 1;

        // ✅ Pasang GlobalKey unik ke map registry
        // Key hanya dibuat sekali per halaman
        final pageKey = _pageKeys.putIfAbsent(pageNumber, () => GlobalKey());

        return RepaintBoundary(
          // Gunakan GlobalKey ini untuk tracking posisi
          key: pageKey,
          child: _VerticalPageWidget(
            pageNumber: pageNumber,
            currentPage: _currentVisiblePage,
          ),
        );
      },
    );
  }
}

/// Single vertical page widget - uses cached mushaf data ONLY
class _VerticalPageWidget extends StatelessWidget {
  final int pageNumber;
  final int currentPage;

  const _VerticalPageWidget({
    required this.pageNumber,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    final cachedLines = controller.pageCache[pageNumber];

    if (cachedLines != null && cachedLines.isNotEmpty) {
      return _VerticalPageContent(
        pageNumber: pageNumber,
        pageLines: cachedLines,
      );
    }

    // ✅ Minimal loading placeholder
    final screenHeight = MediaQuery.of(context).size.height;
    final distance = (pageNumber - currentPage).abs();

    return SizedBox(
      height: screenHeight * 0.75,
      child: Center(
        child: distance <= 5
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.getTextTertiary(context),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Text(
                    'Loading page $pageNumber...',
                    style: TextStyle(
                      color: AppColors.getTextTertiary(context),
                      fontSize: screenHeight * 0.016,
                    ),
                  ),
                ],
              )
            : Text(
                'Page $pageNumber',
                style: TextStyle(
                  color: AppColors.getTextTertiary(context),
                  fontSize: screenHeight * 0.02,
                  fontWeight: FontWeight.w300,
                ),
              ),
      ),
    );
  }
}

/// Renders page content with optimized vertical layout
class _VerticalPageContent extends StatelessWidget {
  final int pageNumber;
  final List<MushafPageLine> pageLines;

  const _VerticalPageContent({
    required this.pageNumber,
    required this.pageLines,
  });

  @override
  Widget build(BuildContext context) {
    final juz = _calculateJuzForPage();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      constraints: BoxConstraints(minHeight: screenHeight * 0.75),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.015,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PageHeader(pageNumber: pageNumber, juzNumber: juz),
          ..._buildLinesInOrder(context),
          SizedBox(height: screenHeight * 0.025),
        ],
      ),
    );
  }

  List<Widget> _buildLinesInOrder(BuildContext context) {
    final widgets = <Widget>[];
    final renderedAyahs = <String>{};
    final controller = context.read<SttController>();
    final fontFamily = controller.mushafLayout.isGlyphBased
        ? 'p$pageNumber'
        : 'IndoPak-Nastaleeq';

    // Pre-aggregate complete ayahs
    final Map<String, List<WordData>> completeAyahs = {};
    final Map<String, AyahSegment> ayahMetadata = {};

    for (final line in pageLines) {
      if (line.lineType == 'ayah' && line.ayahSegments != null) {
        for (final segment in line.ayahSegments!) {
          final key = '${segment.surahId}:${segment.ayahNumber}';
          completeAyahs.putIfAbsent(key, () => []).addAll(segment.words);
          if (!ayahMetadata.containsKey(key)) {
            ayahMetadata[key] = segment;
          }
        }
      }
    }

    // Sort words in each ayah
    for (final words in completeAyahs.values) {
      words.sort((a, b) => a.wordNumber.compareTo(b.wordNumber));
    }

    // Render in database order
    for (final line in pageLines) {
      switch (line.lineType) {
        case 'surah_name':
          widgets.add(_SurahHeader(line: line));
          break;

        case 'basmallah':
          widgets.add(const _Basmallah());
          break;

        case 'ayah':
          if (line.ayahSegments != null) {
            for (final segment in line.ayahSegments!) {
              final key = '${segment.surahId}:${segment.ayahNumber}';

              if (!renderedAyahs.contains(key)) {
                renderedAyahs.add(key);

                final allWords = completeAyahs[key]!;
                final metadata = ayahMetadata[key]!;

                final completeSegment = AyahSegment(
                  surahId: metadata.surahId,
                  ayahNumber: metadata.ayahNumber,
                  words: allWords,
                  isStartOfAyah: true,
                  isEndOfAyah: true,
                );

                widgets.add(
                  _CompleteAyahWidget(
                    segment: completeSegment,
                    fontFamily: fontFamily, // ✅ Dynamic based on layout
                  ),
                );
              }
            }
          }
          break;
      }
    }

    return widgets;
  }

  int _calculateJuzForPage() {
    if (pageLines.isEmpty) return 1;

    for (final line in pageLines) {
      if (line.ayahSegments != null && line.ayahSegments!.isNotEmpty) {
        final segment = line.ayahSegments!.first;
        return QuranService().calculateJuzAccurate(
          segment.surahId,
          segment.ayahNumber,
        );
      }
    }
    return 1;
  }
}

class _PageHeader extends StatelessWidget {
  final int pageNumber;
  final int juzNumber;

  const _PageHeader({required this.pageNumber, required this.juzNumber});

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.of(context).size.width * 0.03;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Juz $juzNumber',
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w100,
            ),
          ),
          Text(
            '$pageNumber',
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w100,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  final MushafPageLine line;

  const _SurahHeader({required this.line});

  @override
  Widget build(BuildContext context) {
    final surahId = line.surahNumber ?? 1;
    final surahGlyphCode = _formatSurahGlyph(surahId);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'header',
            style: TextStyle(
              fontSize: screenHeight * 0.056,
              fontFamily: 'Quran-Common',
              color: AppColors.getTextPrimary(context),
            ),
          ),
          Text(
            surahGlyphCode,
            style: TextStyle(
              fontSize: screenHeight * 0.0475,
              fontFamily: 'surah-name-v2',
              color: AppColors.getTextPrimary(context),
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  String _formatSurahGlyph(int surahId) {
    if (surahId <= 9) return 'surah00$surahId';
    if (surahId <= 99) return 'surah0$surahId';
    return 'surah$surahId';
  }
}

class _Basmallah extends StatelessWidget {
  const _Basmallah();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
      child: Text(
        '﷽',
        style: TextStyle(
          fontSize: screenHeight * 0.04,
          fontFamily: 'Quran-Common',
          color: AppColors.getTextPrimary(context),
        ),
      ),
    );
  }
}

class _CompleteAyahWidget extends StatelessWidget {
  final AyahSegment segment;
  final String fontFamily;

  const _CompleteAyahWidget({required this.segment, required this.fontFamily});

  @override
  Widget build(BuildContext context) {
    return Selector<SttController, _AyahState>(
      selector: (_, controller) {
        final ayatIndex = controller.ayatList.indexWhere(
          (a) => a.surah_id == segment.surahId && a.ayah == segment.ayahNumber,
        );
        final isCurrentAyat =
            ayatIndex >= 0 && ayatIndex == controller.currentAyatIndex;
        final wordStatusKey = '${segment.surahId}:${segment.ayahNumber}';

        return _AyahState(
          isCurrentAyat: isCurrentAyat,
          wordStatusMap: controller.wordStatusMap[wordStatusKey],
          hideUnreadAyat: controller.hideUnreadAyat,
          isListeningMode: controller.isListeningMode,
        );
      },
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, state, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.getBorderLight(context),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: screenHeight * 0.015,
            top: screenHeight * 0.005,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.isStartOfAyah)
                Padding(
                  padding: EdgeInsets.only(bottom: screenHeight * 0.01),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenHeight * 0.005,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: state.isCurrentAyat
                              ? AppColors.getPrimary(context)
                              : AppColors.getTextSecondary(context),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${segment.surahId}:${segment.ayahNumber}',
                        style: TextStyle(
                          color: state.isCurrentAyat
                              ? AppColors.getPrimary(context)
                              : AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: screenWidth * 0.0275,
                        ),
                      ),
                    ),
                  ),
                ),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 1,
                  runSpacing: 4,
                  children: _buildWords(
                    context,
                    segment,
                    state,
                    screenWidth,
                    screenHeight,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildWords(
    BuildContext context,
    AyahSegment segment,
    _AyahState state,
    double screenWidth,
    double screenHeight,
  ) {
    return segment.words.map((word) {
      // FIX: Ensure wordIndex is never negative
      final rawIndex = word.wordNumber - 1;
      final wordIndex = rawIndex < 0
          ? 0
          : (rawIndex >= segment.words.length
                ? segment.words.length - 1
                : rawIndex);
      final wordStatus = state.wordStatusMap?[wordIndex];
      Color wordBg = Colors.transparent;
      double opacity = 1.0;

      final isLastWordInAyah =
          segment.isEndOfAyah && wordIndex == (segment.words.length - 1);
      final hasNumber = RegExp(r'[٠-٩0-9]').hasMatch(word.text);

      if (wordStatus != null) {
        switch (wordStatus) {
          case WordStatus.matched:
            wordBg = getCorrectColor(context).withValues(alpha: 0.4);
            break;
          case WordStatus.mismatched:
          case WordStatus.skipped:
            wordBg = getErrorColor(context).withValues(alpha: 0.4);
            break;
          case WordStatus.processing:
            wordBg = state.isListeningMode
                ? AppColors.getTextTertiary(context).withValues(alpha: 0.5)
                : AppColors.getInfo(context).withValues(alpha: 0.3);
            break;
          default:
            break;
        }
      }

      if (state.hideUnreadAyat) {
        if (wordStatus != null && wordStatus != WordStatus.pending) {
          opacity = 1.0;
        } else if (state.isCurrentAyat) {
          opacity = (hasNumber || isLastWordInAyah) ? 1.0 : 0.0;
        } else {
          opacity = (hasNumber || isLastWordInAyah) ? 1.0 : 0.0;
        }
      }

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.005,
          vertical: screenHeight * 0.00125,
        ),
        decoration: BoxDecoration(
          color: wordBg,
          borderRadius: BorderRadius.circular(3),
          border: (state.hideUnreadAyat && !isLastWordInAyah)
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.getTextPrimary(
                      context,
                    ).withValues(alpha: 0.15),
                    width: 0.3,
                  ),
                )
              : null,
        ),
        child: Opacity(
          opacity: opacity,
          child: _buildWordText(
            context,
            word.text,
            fontFamily,
            state.isCurrentAyat,
            screenWidth,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildWordText(
    BuildContext context,
    String text,
    String fontFamily,
    bool isCurrentAyat,
    double screenWidth,
  ) {
    final controller = context.read<SttController>();
    final isIndopak = controller.mushafLayout == MushafLayout.indopak;

    return Text(
      text,
      style: TextStyle(
        fontSize: isIndopak
            ? screenWidth *
                  0.0625 // IndoPak lebih besar
            : screenWidth * 0.0625, // QPC
        fontFamily: fontFamily,
        color: isCurrentAyat
            ? AppColors.getInfo(context)
            : AppColors.getTextPrimary(context),
        fontWeight: FontWeight.w400,
        height: isIndopak ? 1.8 : 1.7,
        letterSpacing: isIndopak ? 0 : -5,
      ),
      textDirection: TextDirection.rtl,
    );
  }
}

class _AyahState {
  final bool isCurrentAyat;
  final Map<int, WordStatus>? wordStatusMap;
  final bool hideUnreadAyat;
  final bool isListeningMode;

  const _AyahState({
    required this.isCurrentAyat,
    required this.wordStatusMap,
    required this.hideUnreadAyat,
    required this.isListeningMode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AyahState &&
          isCurrentAyat == other.isCurrentAyat &&
          hideUnreadAyat == other.hideUnreadAyat &&
          isListeningMode == other.isListeningMode &&
          _mapEquals(wordStatusMap, other.wordStatusMap);

  @override
  int get hashCode => Object.hash(
    isCurrentAyat,
    hideUnreadAyat,
    isListeningMode,
    wordStatusMap,
  );

  bool _mapEquals(Map<int, WordStatus>? a, Map<int, WordStatus>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
