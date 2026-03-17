// lib/screens/main/stt/widgets/list_view.dart
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/models/quran_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../data/models.dart';
import '../services/quran_service.dart';
import '../utils/constants.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/services/global_ayat_services.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/ayah_translation_widget.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/ayah_tafsir_widget.dart';
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

  bool _hasJumped = false;
  int? _lastScrolledAyahId;

  // State tracking
  int _currentVisiblePage = 1;
  bool _userScrolling = false;
  bool _preloadPaused = false;
  Timer? _debounceTimer;

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

      // ✅ Scroll to verse if needed on initial jump
      if (controller.navigatedAyahId != null) {
        _scrollToVerse(controller.navigatedAyahId!);
      }
    });
  }

  Future<void> _scrollToVerse(int globalId, {int retryCount = 0}) async {
    if (!mounted || _userScrolling) return;

    final key = _verseKeys[globalId];
    if (key != null && key.currentContext != null) {
      _lastScrolledAyahId = globalId;
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.15, // Land slightly below the top
      );
    } else if (retryCount < 10) {
      // If we jumped to a new page, slivers might take a frame to populate keys
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        _scrollToVerse(globalId, retryCount: retryCount + 1);
      }
    }
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
      _pruneVerseKeys();
    });
  }

  /// Prunes GlobalKeys for ayahs that are far from the viewport.
  void _pruneVerseKeys() {
    if (!mounted) return;

    final controller = context.read<SttController>();
    final totalPages = controller.totalPages;

    // Radius of pages to keep keys for
    const keepRadius = 5;
    final minPage = (_currentVisiblePage - keepRadius).clamp(1, totalPages);
    final maxPage = (_currentVisiblePage + keepRadius).clamp(1, totalPages);

    final Set<int> keysToKeep = {};

    for (int p = minPage; p <= maxPage; p++) {
      final lines = controller.pageCache[p];
      if (lines == null) continue;

      for (var line in lines) {
        if (line.ayahSegments != null) {
          for (var ayah in line.ayahSegments!) {
            final globalId = GlobalAyatService.toGlobalAyat(
              ayah.surahId,
              ayah.ayahNumber,
            );
            keysToKeep.add(globalId);
          }
        }
      }
    }

    _verseKeys.removeWhere((id, _) => !keysToKeep.contains(id));
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
          final globalId = GlobalAyatService.toGlobalAyat(
            ayah.surahId,
            ayah.ayahNumber,
          );
          final key = _verseKeys[globalId];
          final renderBox =
              key?.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero).dy;
            if (position >= -100 && position <= 50) {
              controller.updateTopVerse(globalId, p);
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
      int page = (scanCenter - 3).clamp(1, totalPages);
      page <= (scanCenter + 3).clamp(1, totalPages);
      page++
    ) {
      // Check the first verse of each page
      final renderModel = controller.getRenderModel(page);
      if (renderModel == null) continue;

      for (final lineModel in renderModel.lines) {
        if (lineModel is AyahLineModel) {
          final globalId = GlobalAyatService.toGlobalAyat(
            lineModel.segment.surahId,
            lineModel.segment.ayahNumber,
          );
          final verseKey = _verseKeys[globalId];
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

                // Early exit: if visibility > 80% screen, this is definitely the best page
                if (visibleHeight > screenHeight * 0.8) return page;
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

    // ✅ Handle pinpoint navigation (Scroll to Verse)
    if (controller.navigatedAyahId != null &&
        controller.navigatedAyahId != _lastScrolledAyahId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(controller.navigatedAyahId!);
      });
    }

    // ✅ PHASE 7: CustomScrollView with center key
    // The forward sliver starts at _anchorPage (placed at offset 0.0).
    // The reverse sliver renders pages before the anchor (scrolling up).
    return CustomScrollView(
      controller: _scrollController,
      center: _forwardListKey,
      physics: const BouncingScrollPhysics(),
      cacheExtent: 2000,
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

    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return Container(
      constraints: BoxConstraints(minHeight: screenHeight * 0.75),
      padding: EdgeInsets.only(
        left: isLandscape ? screenWidth * 0.12 : screenWidth * 0.04,
        right: isLandscape ? screenWidth * 0.12 : screenWidth * 0.04,
        top: isLandscape ? 20 : kToolbarHeight + 10,
        bottom: screenHeight * 0.015,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PageHeader(pageNumber: pageNumber, juzNumber: renderModel.juzNumber),
          ..._buildLinesInOrder(context, screenWidth, screenHeight),
          SizedBox(height: screenHeight * 0.025),
        ],
      ),
    );
  }

  List<Widget> _buildLinesInOrder(
    BuildContext context,
    double screenWidth,
    double screenHeight,
  ) {
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
        final globalId = GlobalAyatService.toGlobalAyat(
          segment.surahId,
          segment.ayahNumber,
        );
        widgets.add(
          _CompleteAyahWidget(
            key: verseKeys[globalId] ??= GlobalKey(
              debugLabel: 'verse_$globalId',
            ),
            segment: segment,
            fontFamily: fontFamily,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
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
  final double screenWidth;
  final double screenHeight;

  const _CompleteAyahWidget({
    super.key,
    required this.segment,
    required this.fontFamily,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    final wordStatusKey = '${segment.surahId}:${segment.ayahNumber}';

    return GestureDetector(
      onLongPress: () => controller.handleListViewLongPress(context, segment),
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: Container(
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
            bottom: screenHeight * 0.006,
            top: screenHeight * 0.005,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.isStartOfAyah)
                _AyahHeader(
                  segment: segment,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),

              // Arabic Text & Background Highlight
              Selector<SttController, _AyahLayoutState>(
                selector: (_, ctrl) {
                  final ayatIndex = ctrl.ayahIndexMap[wordStatusKey] ?? -1;
                  final isCurrentAyat =
                      ayatIndex >= 0 && ayatIndex == ctrl.currentAyatIndex;
                  final isNavigatedHighlight =
                      ctrl.navigatedAyahId ==
                      GlobalAyatService.toGlobalAyat(
                        segment.surahId,
                        segment.ayahNumber,
                      );
                  final isSelected =
                      ctrl.selectedAyahForOptions?.surahId == segment.surahId &&
                      ctrl.selectedAyahForOptions?.ayahNumber ==
                          segment.ayahNumber;
                  final isHighlighted =
                      ctrl.currentHighlightKey == wordStatusKey;

                  return _AyahLayoutState(
                    isCurrentAyat: isCurrentAyat,
                    isNavigatedHighlight: isNavigatedHighlight,
                    isSelected: isSelected,
                    isHighlighted: isHighlighted,
                  );
                },
                builder: (context, layoutState, _) {
                  return Directionality(
                    textDirection: TextDirection.rtl,
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            (layoutState.isSelected ||
                                layoutState.isCurrentAyat ||
                                layoutState.isHighlighted ||
                                layoutState.isNavigatedHighlight)
                            ? AppColors.getPrimary(
                                context,
                              ).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Selector<SttController, _AyahContentState>(
                        selector: (_, ctrl) => _AyahContentState(
                          wordStatusMap:
                              layoutState.isCurrentAyat ||
                                  layoutState.isSelected
                              ? ctrl.wordStatusMap[wordStatusKey]
                              : null,
                          wordStatusRevision: ctrl.wordStatusRevision,
                          isListeningMode: ctrl.isListeningMode,
                          isHighlighted: layoutState.isHighlighted,
                          isCurrentAyat: layoutState.isCurrentAyat,
                        ),
                        builder: (context, contentState, _) {
                          return _buildAyahArabic(
                            context,
                            segment,
                            contentState,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              // Translation & Tafsir
              Selector<SttController, _AyahExtraState>(
                selector: (_, ctrl) => _AyahExtraState(
                  showTranslation: ctrl.showTranslationInListView,
                  showTafsir: ctrl.showTafsirInListView,
                ),
                builder: (context, extraState, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (segment.isStartOfAyah &&
                          extraState.showTranslation) ...[
                        const SizedBox(height: 6),
                        AyahTranslationWidget(
                          key: ValueKey(
                            'trans_${segment.surahId}_${segment.ayahNumber}',
                          ),
                          surahId: segment.surahId,
                          ayahNumber: segment.ayahNumber,
                        ),
                      ],
                      if (segment.isStartOfAyah && extraState.showTafsir) ...[
                        const SizedBox(height: 8),
                        AyahTafsirWidget(
                          key: ValueKey(
                            'tafsir_${segment.surahId}_${segment.ayahNumber}',
                          ),
                          surahId: segment.surahId,
                          ayahNumber: segment.ayahNumber,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAyahArabic(
    BuildContext context,
    AyahSegment segment,
    _AyahContentState state,
  ) {
    final controller = context.read<SttController>();
    final isIndopak =
        controller.mushafLayout == MushafLayout.indopak ||
        fontFamily == 'IndoPak-Nastaleeq';

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final baseFontSize = screenWidth * 0.0625;

        final wordStyle = TextStyle(
          fontSize: baseFontSize,
          fontFamily: fontFamily,
          height: isIndopak ? 1.5 : 1.6,
          color: AppColors.getTextPrimary(context),
        );

        // 1. Build TWO span lists:
        //    - displaySpans: for RichText (includes WidgetSpan end marker)
        //    - measureSpans: for TextPainter measurement (text-only, no WidgetSpan)
        final List<InlineSpan> displaySpans = [];
        final List<InlineSpan> measureSpans = [];

        for (int i = 0; i < segment.words.length; i++) {
          final word = segment.words[i];
          final isLastWord =
              segment.isEndOfAyah && i == segment.words.length - 1;

          if (isLastWord) {
            // Display: WidgetSpan for visual end marker
            displaySpans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _buildAyahEndMarker(context, segment, baseFontSize),
              ),
            );
            // Measure: placeholder text (won't need highlight on end marker)
            measureSpans.add(TextSpan(text: ' ', style: wordStyle));
          } else {
            final span = TextSpan(text: word.text, style: wordStyle);
            displaySpans.add(span);
            measureSpans.add(span);
            // Non-breaking space between words
            const spacer = TextSpan(text: '\u00A0');
            displaySpans.add(spacer);
            measureSpans.add(spacer);
          }
        }

        // TextPainter for highlight measurement (text-only, safe to layout)
        final textPainter = TextPainter(
          text: TextSpan(children: measureSpans),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
        )..layout(maxWidth: availableWidth);

        // 2. Wrap in a Stack for highlight overlay
        return Stack(
          children: [
            // Highlight Layer (only when needed)
            if (state.isHighlighted ||
                (state.wordStatusMap?.isNotEmpty ?? false))
              Positioned.fill(
                child: CustomPaint(
                  painter: _AyatHighlightPainter(
                    context: context,
                    segment: segment,
                    state: state,
                    textPainter: textPainter,
                    maxWidth: availableWidth,
                  ),
                ),
              ),

            // Text Layer (uses displaySpans with WidgetSpan)
            RichText(
              text: TextSpan(children: displaySpans),
              textDirection: TextDirection.rtl,
              textAlign: isIndopak ? TextAlign.justify : TextAlign.start,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAyahEndMarker(
    BuildContext context,
    AyahSegment segment,
    double baseFontSize,
  ) {
    return Container(
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
                  color: AppColors.getAyahNumber(context),
                  height: 1.0,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
          Center(
            child: Text(
              LanguageHelper.toIndoPakDigits(segment.ayahNumber),
              style: TextStyle(
                fontSize: baseFontSize * 0.45,
                fontFamily: 'Quran-Common',
                color: AppColors.getAyahNumber(context),
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

class _AyatHighlightPainter extends CustomPainter {
  final BuildContext context;
  final AyahSegment segment;
  final _AyahContentState state;
  final TextPainter textPainter;
  final double maxWidth;

  _AyatHighlightPainter({
    required this.context,
    required this.segment,
    required this.state,
    required this.textPainter,
    required this.maxWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (state.wordStatusMap == null && !state.isHighlighted) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final primaryColor = AppColors.getPrimary(context);

    for (int i = 0; i < segment.words.length; i++) {
      final word = segment.words[i];
      final wordStatus = state.wordStatusMap?[word.id];

      if (wordStatus == null && !state.isHighlighted) continue;

      int startOffset = 0;
      for (int j = 0; j < i; j++) {
        startOffset += segment.words[j].text.length + 1;
      }
      final endOffset = startOffset + word.text.length;

      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: startOffset, extentOffset: endOffset),
      );

      if (wordStatus != null) {
        paint.color = primaryColor.withValues(alpha: 0.25);
      } else {
        paint.color = primaryColor.withValues(alpha: 0.12);
      }

      for (final box in boxes) {
        final rect = box.toRect();
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(4)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AyatHighlightPainter oldDelegate) {
    return oldDelegate.state.wordStatusRevision != state.wordStatusRevision ||
        oldDelegate.state.isHighlighted != state.isHighlighted ||
        oldDelegate.state.isCurrentAyat != state.isCurrentAyat ||
        oldDelegate.state.wordStatusMap != state.wordStatusMap;
  }
}

class _AyahLayoutState {
  final bool isCurrentAyat;
  final bool isNavigatedHighlight;
  final bool isSelected;
  final bool isHighlighted;

  const _AyahLayoutState({
    required this.isCurrentAyat,
    required this.isNavigatedHighlight,
    required this.isSelected,
    required this.isHighlighted,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AyahLayoutState &&
          isCurrentAyat == other.isCurrentAyat &&
          isNavigatedHighlight == other.isNavigatedHighlight &&
          isSelected == other.isSelected &&
          isHighlighted == other.isHighlighted;

  @override
  int get hashCode => Object.hash(
    isCurrentAyat,
    isNavigatedHighlight,
    isSelected,
    isHighlighted,
  );
}

class _AyahContentState {
  final Map<int, WordStatus>? wordStatusMap;
  final int wordStatusRevision;
  final bool isListeningMode;
  final bool isHighlighted;
  final bool isCurrentAyat;

  const _AyahContentState({
    required this.wordStatusMap,
    required this.wordStatusRevision,
    required this.isListeningMode,
    required this.isHighlighted,
    required this.isCurrentAyat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AyahContentState &&
          wordStatusRevision == other.wordStatusRevision &&
          isListeningMode == other.isListeningMode &&
          isHighlighted == other.isHighlighted &&
          isCurrentAyat == other.isCurrentAyat &&
          _mapEquals(wordStatusMap, other.wordStatusMap);

  @override
  int get hashCode => Object.hash(
    wordStatusRevision,
    isListeningMode,
    isHighlighted,
    isCurrentAyat,
    wordStatusMap,
  );

  static bool _mapEquals(Map<int, WordStatus>? a, Map<int, WordStatus>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

class _AyahExtraState {
  final bool showTranslation;
  final bool showTafsir;

  const _AyahExtraState({
    required this.showTranslation,
    required this.showTafsir,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AyahExtraState &&
          showTranslation == other.showTranslation &&
          showTafsir == other.showTafsir;

  @override
  int get hashCode => Object.hash(showTranslation, showTafsir);
}

class _AyahHeader extends StatelessWidget {
  final AyahSegment segment;
  final double screenWidth;
  final double screenHeight;
  const _AyahHeader({
    super.key,
    required this.segment,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentAyat = context.select<SttController, bool>((ctrl) {
      final wordStatusKey = '${segment.surahId}:${segment.ayahNumber}';
      final ayatIndex = ctrl.ayahIndexMap[wordStatusKey] ?? -1;
      return ayatIndex >= 0 && ayatIndex == ctrl.currentAyatIndex;
    });

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.008),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.02,
          vertical: screenHeight * 0.005,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: isCurrentAyat
                ? AppColors.getPrimary(context)
                : AppColors.getTextSecondary(context),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${segment.surahId}:${segment.ayahNumber}',
          style: TextStyle(
            color: isCurrentAyat
                ? AppColors.getPrimary(context)
                : AppColors.getTextPrimary(context),
            fontSize: screenWidth * 0.0275,
          ),
        ),
      ),
    );
  }
}
