// lib/screens/main/stt/widgets/list_view.dart
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/models/quran_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import '../data/models.dart';
import '../services/quran_service.dart';
import '../utils/constants.dart';
import 'dart:async';

/// Optimized vertical Quran reading mode with aggressive background preloading
class QuranListView extends StatefulWidget {
  const QuranListView({Key? key}) : super(key: key);

  @override
  State<QuranListView> createState() => _QuranListViewState();
}

class _QuranListViewState extends State<QuranListView> {
  final ScrollController _scrollController = ScrollController();
  int _currentVisiblePage = 1;
  Timer? _scrollEndTimer;
  bool _hasJumped = false;

  // ✅ Background preloading state
  bool _isPreloading = false;
  int _preloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasJumped) return;

      final controller = context.read<SttController>();
      final targetPage = controller.listViewCurrentPage;

      print('📍 LIST_VIEW_INIT: Jumping to saved position: $targetPage');
      _jumpToPage(targetPage);
      _currentVisiblePage = targetPage;
      _hasJumped = true;

      // ✅ Load immediate visible range
      _loadImmediateRange(targetPage);

      // ✅ Start aggressive background preloading
      _startBackgroundPreload(targetPage);
    });
  }

  /// ✅ PHASE 1: Load visible range INSTANTLY (±3 pages)
  Future<void> _loadImmediateRange(int centerPage) async {
    if (!mounted) return;

    final controller = context.read<SttController>();
    final service = context.read<QuranService>();
    final totalPages = controller.totalPages;

    final immediatePage = <int>[];
    for (int offset = -3; offset <= 3; offset++) {
      final page = centerPage + offset;
      // ✅ UBAH: Validate against dynamic total pages
      if (page >= 1 &&
          page <= totalPages &&
          !controller.pageCache.containsKey(page)) {
        immediatePage.add(page);
      }
    }

    if (immediatePage.isEmpty) return;

    print(
      '📍 IMMEDIATE: Loading ${immediatePage.length} visible pages around $centerPage',
    );

    // Load all visible pages in parallel
    await Future.wait(
      immediatePage.map((page) async {
        try {
          final lines = await service.getMushafPageLines(page);
          if (mounted) {
            controller.updatePageCache(page, lines);
            print('📍 VISIBLE: Page $page ready');
          }
        } catch (e) {
          print('📍 ERROR: Page $page failed: $e');
        }
      }),
    );

    if (mounted) setState(() {});
    print(
      '📍 IMMEDIATE: All visible pages loaded, cache=${controller.pageCache.length}',
    );
  }

  /// ✅ PHASE 2: Aggressive background preload (ALL remaining pages)
  Future<void> _startBackgroundPreload(int startPage) async {
    if (_isPreloading || !mounted) return;

    _isPreloading = true;
    final controller = context.read<SttController>();
    final service = context.read<QuranService>();
    final totalPages = controller.totalPages; // ✅ TAMBAH

    print('📍 PRELOAD: Starting background load of all 604 pages');

    // ✅ Strategy: Load in expanding circles from current page
    final pagesToLoad = <int>[];

    // ✅ UBAH: Dynamic total pages
    for (int distance = 4; distance < totalPages; distance++) {
      final prevPage = startPage - distance;
      final nextPage = startPage + distance;

      if (prevPage >= 1 && !controller.pageCache.containsKey(prevPage)) {
        pagesToLoad.add(prevPage);
      }
      if (nextPage <= totalPages &&
          !controller.pageCache.containsKey(nextPage)) {
        pagesToLoad.add(nextPage);
      }
    }
    print(
      '📍 PRELOAD: ${pagesToLoad.length} pages queued for background loading',
    );

    // ✅ Load in batches of 10 pages (parallel within batch)
    const batchSize = 10;
    for (int i = 0; i < pagesToLoad.length; i += batchSize) {
      if (!mounted) break;

      final batch = pagesToLoad.skip(i).take(batchSize).toList();

      await Future.wait(
        batch.map((page) async {
          if (!mounted || controller.pageCache.containsKey(page)) return;

          try {
            final lines = await service.getMushafPageLines(page);
            if (mounted) {
              controller.updatePageCache(page, lines);
              _preloadProgress++;
            }
          } catch (e) {
            print('📍 PRELOAD ERROR: Page $page: $e');
          }
        }),
      );

      // Small delay between batches to avoid blocking UI
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted && _preloadProgress % 50 == 0) {
        print('📍 PRELOAD: Progress ${controller.pageCache.length}/604 pages');
        setState(() {}); // Refresh UI occasionally
      }
    }

    if (mounted) {
      print('📍 PRELOAD: ✅ Complete! All 604 pages cached');
      setState(() {});
    }
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

    final offset = _scrollController.offset;
    final screenHeight = MediaQuery.of(context).size.height;
    final estimatedPageHeight = screenHeight * 0.75;
    final pageNumber = (offset / estimatedPageHeight).floor() + 1;
    // ✅ TAMBAHKAN: Get total pages from controller
    final totalPages = context.read<SttController>().totalPages;
    final clampedPage = pageNumber.clamp(1, totalPages);

    if (clampedPage != _currentVisiblePage) {
      _currentVisiblePage = clampedPage;

      _scrollEndTimer?.cancel();
      _scrollEndTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        print(
          '📍 SCROLL: Settled at page $_currentVisiblePage (cache: ${context.read<SttController>().pageCache.length}/604)',
        );

        // Load nearby pages if not cached yet
        _loadImmediateRange(_currentVisiblePage);
      });
    }
  }

  @override
  void dispose() {
    _scrollEndTimer?.cancel();
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
      itemCount: totalPages, // ✅ UBAH: dari 604 jadi dynamic
      cacheExtent: 2000,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        return RepaintBoundary(
          key: ValueKey('vertical_page_$pageNumber'),
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
                      color: Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Text(
                    'Loading page $pageNumber...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: screenHeight * 0.016,
                    ),
                  ),
                ],
              )
            : Text(
                'Page $pageNumber',
                style: TextStyle(
                  color: Colors.grey[300],
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
              color: Colors.black,
              fontWeight: FontWeight.w100,
            ),
          ),
          Text(
            '$pageNumber',
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black,
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
              color: Colors.black87,
            ),
          ),
          Text(
            surahGlyphCode,
            style: TextStyle(
              fontSize: screenHeight * 0.0475,
              fontFamily: 'surah-name-v2',
              color: Colors.black,
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
          color: Colors.black87,
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
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
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
                              ? primaryColor
                              : Colors.black54,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${segment.surahId}:${segment.ayahNumber}',
                        style: TextStyle(
                          color: state.isCurrentAyat
                              ? primaryColor
                              : Colors.black87,
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
            wordBg = correctColor.withValues(alpha: 0.4);
            break;
          case WordStatus.mismatched:
          case WordStatus.skipped:
            wordBg = errorColor.withValues(alpha: 0.4);
            break;
          case WordStatus.processing:
            wordBg = state.isListeningMode
                ? Colors.grey.withValues(alpha: 0.5)
                : listeningColor.withValues(alpha: 0.3);
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
                    color: Colors.black.withValues(alpha: 0.15),
                    width: 0.3,
                  ),
                )
              : null,
        ),
        child: Opacity(
          opacity: opacity,
          child: _buildWordText(
            word.text,
            fontFamily,
            state.isCurrentAyat,
            screenWidth,
          ),
        ),
      );
    }).toList();
  }

  // ✅ FIX: Helper method untuk render text dengan setting yang berbeda per layout
  Widget _buildWordText(
    String text,
    String fontFamily,
    bool isCurrentAyat,
    double screenWidth,
  ) {
    // ✅ CRITICAL: Deteksi layout dari fontFamily
    final isIndopak = fontFamily == 'IndoPak-Nastaleeq';

    return Text(
      text,
      style: TextStyle(
        fontSize: isIndopak
            ? screenWidth * 0.070 // ← Sedikit lebih besar untuk Indopak
            : screenWidth * 0.0625, // ← Original untuk QPC
        fontFamily: fontFamily,
        color: isCurrentAyat ? listeningColor : Colors.black87,
        fontWeight: FontWeight.w400,
        height: 1.7,
        letterSpacing: isIndopak
            ? 0 // ← PENTING: Tidak ada overlap untuk Indopak!
            : -5, // ← Overlap untuk QPC glyph fonts
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
