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
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'dart:async';

/// ✅ PHASE 7: Atomic Ayah Architecture
/// Uses CustomScrollView with center key for pixel-perfect navigation.
/// The anchor page is always placed at offset 0.0 by construction.
class QuranListView extends StatefulWidget {
  const QuranListView({Key? key}) : super(key: key);

  @override
  State<QuranListView> createState() => _QuranListViewState();
}

class _QuranListViewState extends State<QuranListView> {
  late ScrollController _scrollController;
  final Map<int, GlobalKey> _verseKeys = {};

  // ✅ PHASE 7: Anchor page — the page placed at offset 0.0
  int _anchorPage = 1;

  // State tracking
  int _currentVisiblePage = 1;
  bool _userScrolling = false;
  bool _preloadPaused = false;
  Timer? _debounceTimer;
  bool _hasJumped = false;

  // ✅ PHASE 7: Center key for the forward sliver
  final GlobalKey _forwardListKey = GlobalKey(debugLabel: 'forward_sliver');

  @override
  void initState() {
    super.initState();

    final controller = context.read<SttController>();
    final targetPage = controller.listViewCurrentPage;

    _anchorPage = targetPage;
    _currentVisiblePage = targetPage;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasJumped) return;
      _hasJumped = true;

      // ✅ PHASE 7: No jump needed! The anchor page is already at offset 0.
      // Just start preloading adjacent pages.
      _startSmartPreload(targetPage);
    });
  }

  /// ✅ PHASE 7: Jump = Rebuild with new anchor
  /// No scroll estimation. No correction. Just rebuild.
  void _jumpToPage(int pageNumber) {
    if (!mounted) return;

    final controller = context.read<SttController>();
    if (controller.isTransitioningMode) return;

    final totalPages = controller.totalPages;
    final clampedPage = pageNumber.clamp(1, totalPages);

    if (clampedPage == _anchorPage) return;

    print('🚀 PHASE7_JUMP: Anchor $clampedPage (was $_anchorPage)');

    setState(() {
      _anchorPage = clampedPage;
      _currentVisiblePage = clampedPage;
      // Reset scroll to 0 since anchor changes
      _scrollController.dispose();
      _scrollController = ScrollController();
      _scrollController.addListener(_onScroll);
    });

    _preloadPaused = false;
    _startSmartPreload(clampedPage);
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final bestPage = _calculateVisiblePage();

    if (bestPage != _currentVisiblePage) {
      _currentVisiblePage = bestPage;
      context.read<SttController>().updateVisiblePageQuiet(_currentVisiblePage);
      context.read<QuranService>().updateCurrentPage(_currentVisiblePage);
    }

    if (!_userScrolling) {
      _userScrolling = true;
      _preloadPaused = true;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _userScrolling = false;
      _preloadPaused = false;
      _detectTopVerseAndUpdateController();
      _startSmartPreload(_currentVisiblePage);
    });
  }

  /// Detects which verse is at the top of the viewport.
  void _detectTopVerseAndUpdateController() {
    if (!mounted) return;

    final controller = context.read<SttController>();
    for (int p in [
      _currentVisiblePage,
      _currentVisiblePage + 1,
      _currentVisiblePage - 1,
    ]) {
      final pageLines = controller.pageCache[p];
      if (pageLines == null) continue;

      for (var line in pageLines) {
        final segments = line.ayahSegments;
        if (segments == null) continue;

        for (var ayah in segments) {
          final key = _verseKeys[ayah.id];
          final renderBox =
              key?.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero).dy;
            if (position >= -100 && position <= 50) {
              controller.updateTopVerse(ayah.id, p);
              return;
            }
          }
        }
      }
    }
  }

  /// Calculates the most visible page by checking render objects.
  int _calculateVisiblePage() {
    if (!mounted || !_scrollController.hasClients) return _currentVisiblePage;

    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✅ PHASE 7.1: Dynamic Scan Center
    // Scan around the LAST KNOWN visible page to handle continuous scrolls
    // that move far away from the initial anchor.
    int scanCenter = _currentVisiblePage;
    int bestPage = _currentVisiblePage;
    double maxVisible = 0.0;

    for (
      int page = (scanCenter - 10).clamp(1, totalPages);
      page <= (scanCenter + 10).clamp(1, totalPages);
      page++
    ) {
      // Check the first verse of each page
      final renderModel = controller.getRenderModel(page);
      if (renderModel == null) continue;

      for (final lineModel in renderModel.lines) {
        if (lineModel is AyahLineModel) {
          final verseKey = _verseKeys[lineModel.segment.id];
          if (verseKey?.currentContext != null) {
            final renderBox =
                verseKey!.currentContext!.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final top = renderBox.localToGlobal(Offset.zero).dy;
              if (top >= -screenHeight && top <= screenHeight * 2) {
                // Determine visibility in viewport (0 to screenHeight)
                final visibleTop = top < 0 ? 0 : top;
                final visibleBottom =
                    (top + renderBox.size.height) > screenHeight
                    ? screenHeight
                    : (top + renderBox.size.height);
                final visibleHeight = (visibleBottom - visibleTop).clamp(
                  0.0,
                  screenHeight,
                );

                if (visibleHeight > maxVisible) {
                  maxVisible = visibleHeight;
                  bestPage = page;
                }
              }
            }
          }
          break; // Only check first verse benchmark for page identification
        }
      }
    }

    return bestPage.clamp(1, totalPages);
  }

  /// Preloads pages around the center.
  Future<void> _startSmartPreload(int centerPage) async {
    if (_preloadPaused || _userScrolling || !mounted) return;

    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;

    // PHASE 1: Immediate adjacent (±2)
    final immediatePages = _buildPageRange(
      centerPage - 2,
      centerPage + 2,
      totalPages,
    );
    if (immediatePages.isNotEmpty) {
      await _loadBatchThrottled(immediatePages, delayMs: 0);
    }

    if (_userScrolling || !mounted) return;

    // PHASE 2: Near range (±5)
    final nearPages = _buildPageRange(
      centerPage - 5,
      centerPage + 5,
      totalPages,
    )..removeWhere((p) => immediatePages.contains(p));
    if (nearPages.isNotEmpty) {
      await _loadBatchThrottled(nearPages, delayMs: 100);
    }

    if (_userScrolling || !mounted) return;

    // PHASE 3: Background expansion
    final expandPages = _buildExpandingRange(centerPage, totalPages);
    if (expandPages.isNotEmpty) {
      await _loadBatchThrottled(expandPages, delayMs: 200, maxBatchSize: 5);
    }
  }

  Future<void> _loadBatchThrottled(
    List<int> pages, {
    int delayMs = 50,
    int maxBatchSize = 10,
  }) async {
    if (pages.isEmpty || !mounted) return;

    final controller = context.read<SttController>();
    final service = context.read<QuranService>();

    for (int i = 0; i < pages.length; i += maxBatchSize) {
      if (_userScrolling || !mounted) return;

      final chunk = pages.skip(i).take(maxBatchSize).toList();
      final uncachedPages = chunk
          .where((p) => !controller.pageCache.containsKey(p))
          .toList();

      if (uncachedPages.isEmpty) continue;

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

        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

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

  List<int> _buildExpandingRange(int centerPage, int totalPages) {
    final controller = context.read<SttController>();
    final pages = <int>[];
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
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;

    // ✅ Handle external navigation (Menu/Juz Jump)
    final targetPage = controller.listViewCurrentPage;
    if (targetPage != _anchorPage &&
        !_userScrolling &&
        !controller.isTransitioningMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_anchorPage != targetPage && !controller.isTransitioningMode) {
          _jumpToPage(targetPage);
        }
      });
    }

    // ✅ PHASE 7: CustomScrollView with center key
    // The forward sliver starts at _anchorPage (placed at offset 0.0).
    // The reverse sliver renders pages before the anchor (scrolling up).
    return CustomScrollView(
      controller: _scrollController,
      center: _forwardListKey,
      physics: const BouncingScrollPhysics(),
      cacheExtent: 800,
      slivers: [
        // ═══════════════════════════════════════════
        // REVERSE SLIVER: Pages before anchor (scroll UP)
        // ═══════════════════════════════════════════
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // index 0 = anchorPage - 1, index 1 = anchorPage - 2, ...
              final pageNum = _anchorPage - 1 - index;
              if (pageNum < 1) return null;

              return _VerticalPageWidget(
                key: ValueKey('page_$pageNum'),
                pageNumber: pageNum,
                verseKeys: _verseKeys,
              );
            },
            // Max items in reverse = anchorPage - 1
            childCount: (_anchorPage - 1).clamp(0, totalPages),
          ),
        ),

        // ═══════════════════════════════════════════
        // FORWARD SLIVER: Pages from anchor onward (scroll DOWN)
        // This sliver is the center — its first item is at offset 0.0
        // ═══════════════════════════════════════════
        SliverList(
          key: _forwardListKey,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // index 0 = anchorPage, index 1 = anchorPage + 1, ...
              final pageNum = _anchorPage + index;
              if (pageNum > totalPages) return null;

              return _VerticalPageWidget(
                key: ValueKey('page_$pageNum'),
                pageNumber: pageNum,
                verseKeys: _verseKeys,
              );
            },
            // Max items forward = totalPages - anchorPage + 1
            childCount: (totalPages - _anchorPage + 1).clamp(0, totalPages),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RENDER WIDGETS (preserved from previous architecture)
// ════════════════════════════════════════════════════════════════

/// Single vertical page widget - uses cached mushaf data ONLY
class _VerticalPageWidget extends StatelessWidget {
  final int pageNumber;
  final Map<int, GlobalKey> verseKeys;

  const _VerticalPageWidget({
    super.key,
    required this.pageNumber,
    required this.verseKeys,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    final renderModel = controller.getRenderModel(pageNumber);

    if (renderModel == null) {
      final screenHeight = MediaQuery.of(context).size.height;
      final distance = (pageNumber - controller.listViewCurrentPage).abs();

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

    return _VerticalPageContent(
      pageNumber: pageNumber,
      renderModel: renderModel,
      verseKeys: verseKeys,
    );
  }
}

class _VerticalPageContent extends StatelessWidget {
  final int pageNumber;
  final QuranPageRenderModel renderModel;
  final Map<int, GlobalKey> verseKeys;

  const _VerticalPageContent({
    required this.pageNumber,
    required this.renderModel,
    required this.verseKeys,
  });

  @override
  Widget build(BuildContext context) {
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
          _PageHeader(pageNumber: pageNumber, juzNumber: renderModel.juzNumber),
          ..._buildLinesInOrder(context),
          SizedBox(height: screenHeight * 0.025),
        ],
      ),
    );
  }

  List<Widget> _buildLinesInOrder(BuildContext context) {
    final widgets = <Widget>[];
    final controller = context.read<SttController>();
    final fontFamily = controller.mushafLayout.isGlyphBased
        ? 'p$pageNumber'
        : 'IndoPak-Nastaleeq';

    for (final lineModel in renderModel.lines) {
      if (lineModel is SurahNameLineModel) {
        widgets.add(_SurahHeader(line: lineModel.line));
      } else if (lineModel is BasmallahLineModel) {
        widgets.add(const _Basmallah());
      } else if (lineModel is AyahLineModel) {
        final segment = lineModel.segment;
        widgets.add(
          _CompleteAyahWidget(
            key: verseKeys[segment.id] ??= GlobalKey(
              debugLabel: 'verse_${segment.id}',
            ),
            segment: segment,
            fontFamily: fontFamily,
          ),
        );
      }
    }
    return widgets;
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
    final controller = context.read<SttController>();

    final surahId = line.surahNumber ?? 1;
    final surahGlyphCode = controller.formatSurahHeaderName(surahId);
    final screenHeight = MediaQuery.of(context).size.height;
    final headerSize = screenHeight * 0.060;
    final surahNameSize = screenHeight * 0.045;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/surah-header/chapter_hdr.png',
              height: headerSize * 1.5,
              fit: BoxFit.contain,
              color: AppColors.getAyahNumber(context),
              colorBlendMode: BlendMode.srcIn,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Text(
                surahGlyphCode,
                style: TextStyle(
                  fontSize: surahNameSize - 1,
                  fontFamily: 'surah-name-v2',
                  color: AppColors.getTextPrimary(context),
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
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

  const _CompleteAyahWidget({
    super.key,
    required this.segment,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    return GestureDetector(
      onLongPress: () => controller.handleListViewLongPress(context, segment),
      behavior: HitTestBehavior.opaque,
      child: Selector<SttController, _AyahState>(
        selector: (_, controller) {
          final wordStatusKey = '${segment.surahId}:${segment.ayahNumber}';

          final ayatIndex = controller.ayahIndexMap[wordStatusKey] ?? -1;
          final isCurrentAyat =
              ayatIndex >= 0 && ayatIndex == controller.currentAyatIndex;

          return _AyahState(
            isCurrentAyat: isCurrentAyat,
            wordStatusMap: controller.wordStatusMap[wordStatusKey],
            hideUnreadAyat: controller.hideUnreadAyat,
            isListeningMode: controller.isListeningMode,
            isHighlighted: controller.currentHighlightKey == wordStatusKey,
            isNavigatedHighlight: controller.navigatedAyahId == segment.id,
            isSelected: controller.selectedAyahForOptions?.id == segment.id,
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
                            fontSize: screenWidth * 0.0275,
                          ),
                        ),
                      ),
                    ),
                  ),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    decoration: BoxDecoration(
                      color: (state.isNavigatedHighlight || state.isSelected)
                          ? AppColors.getPrimary(context).withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: (state.isNavigatedHighlight || state.isSelected)
                        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                        : EdgeInsets.zero,
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
                ),
              ],
            ),
          );
        },
      ),
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
      final hasNumber = word.hasDigit;

      if (wordStatus != null) {
        switch (wordStatus) {
          case WordStatus.matched:
          case WordStatus.correct:
            wordBg = getCorrectColor(context).withValues(alpha: 0.4);
            break;
          case WordStatus.mismatched:
          case WordStatus.incorrect:
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

      if ((state.isCurrentAyat || state.isHighlighted) &&
          wordBg == Colors.transparent) {
        wordBg = AppColors.getPrimary(context).withValues(alpha: 0.1);
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

      if (isLastWordInAyah) {
        final baseFontSize = screenWidth * 0.0625;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 0,
            vertical: screenHeight * 0.00125,
          ),
          child: Container(
            width: baseFontSize * 1.2,
            height: baseFontSize,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, -baseFontSize * 0.15),
                  child: Transform.scale(
                    scale: 1.2,
                    child: Text(
                      '\u06DD',
                      style: TextStyle(
                        fontSize: baseFontSize,
                        fontFamily: 'IndoPak-Nastaleeq',
                        foreground: Paint()
                          ..color = AppColors.getAyahNumber(context)
                          ..colorFilter = ColorFilter.mode(
                            AppColors.getAyahNumber(context),
                            BlendMode.srcIn,
                          ),
                        height: 1.0,
                      ),
                      textDirection: TextDirection.rtl,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    LanguageHelper.toIndoPakDigits(segment.ayahNumber),
                    style: TextStyle(
                      fontSize: baseFontSize * 0.45,
                      fontFamily: 'Quran-Common',
                      foreground: Paint()
                        ..color = AppColors.getAyahNumber(context)
                        ..colorFilter = ColorFilter.mode(
                          AppColors.getAyahNumber(context),
                          BlendMode.srcIn,
                        ),
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.005,
            vertical: 0,
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
      }
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
    final isIndopakLayout = controller.mushafLayout == MushafLayout.indopak;
    final isIndopakFont = fontFamily == 'IndoPak-Nastaleeq';
    final effectiveIsIndopak = isIndopakLayout || isIndopakFont;

    return Text(
      text,
      style: TextStyle(
        fontSize: effectiveIsIndopak
            ? screenWidth * 0.0625
            : screenWidth * 0.0625,
        fontFamily: fontFamily,
        color: effectiveIsIndopak ? AppColors.getTextPrimary(context) : null,
        foreground: effectiveIsIndopak
            ? null
            : (Paint()
                ..color = AppColors.getTextPrimary(context)
                ..colorFilter = ColorFilter.mode(
                  AppColors.getTextPrimary(context),
                  BlendMode.srcIn,
                )),
        fontWeight: FontWeight.normal,
        height: effectiveIsIndopak ? 1.5 : 1.6,
        letterSpacing: effectiveIsIndopak ? 0 : 0.0,
        shadows: effectiveIsIndopak
            ? null
            : [
                Shadow(
                  color: AppColors.getTextPrimary(
                    context,
                  ).withValues(alpha: 0.7),
                  offset: const Offset(0.0, 0.0),
                  blurRadius: 0.2,
                ),
              ],
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
  final bool isHighlighted;
  final bool isNavigatedHighlight;
  final bool isSelected;

  const _AyahState({
    required this.isCurrentAyat,
    required this.wordStatusMap,
    required this.hideUnreadAyat,
    required this.isListeningMode,
    required this.isHighlighted,
    required this.isNavigatedHighlight,
    required this.isSelected,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AyahState &&
          isCurrentAyat == other.isCurrentAyat &&
          hideUnreadAyat == other.hideUnreadAyat &&
          isListeningMode == other.isListeningMode &&
          isHighlighted == other.isHighlighted &&
          isNavigatedHighlight == other.isNavigatedHighlight &&
          isSelected == other.isSelected &&
          _mapEquals(wordStatusMap, other.wordStatusMap);

  @override
  int get hashCode => Object.hash(
    isCurrentAyat,
    hideUnreadAyat,
    isListeningMode,
    isHighlighted,
    isNavigatedHighlight,
    isSelected,
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
