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

/// Optimized vertical Quran reading mode with aggressive background preloading
class QuranListView extends StatefulWidget {
  const QuranListView({Key? key}) : super(key: key);

  @override
  State<QuranListView> createState() => _QuranListViewState();
}

class _QuranListViewState extends State<QuranListView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _pageKeys = {}; // ✅ NEW: Track pages
  final Map<int, GlobalKey> _verseKeys = {}; // ✅ NEW: Map for each verse GlobalKey

  // ✅ NEW: State variables sesuai algoritma
  int _currentVisiblePage = 1;
  bool _userScrolling = false;
  bool _preloadPaused = false;
  Timer? _debounceTimer;
  bool _hasJumped = false;
  bool _isJumping = false;
  
  // ✅ NEW: Constant for consistent estimation 
  // List view pages are usually a bit shorter than screen height due to wrapping.
  // 0.88x is a better initial baseline for seeking.
  static const double _estimatedHeightFactor = 0.88;

  // ✅ Background preloading state
  bool _isPreloading = false;
  int _preloadProgress = 0;

  // ✅ NEW: Track visible widgets for accurate page detection
  final GlobalKey _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // ✅ PHASE 1: Immediate Jump & Setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasJumped) return;

      final controller = context.read<SttController>();
      final targetPage = controller.listViewCurrentPage;

      print('🔍 LIST_VIEW_INIT: Starting at page: $targetPage');
      _jumpToPage(targetPage);
      _currentVisiblePage = targetPage;
      _hasJumped = true;

      // ✅ PHASE 2: Start Smart Preload system (debounced)
      _startSmartPreload(targetPage);
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

  void _jumpToPage(int pageNumber, {int retryCount = 0}) {
    if (!mounted) return;
    if (retryCount > 10) { // ✅ INCREASED: More retries for high page numbers
      print('⚠️ JUMP_FAIL: Max retries reached for Page $pageNumber');
      _finalizeJump(pageNumber);
      return;
    }

    _isJumping = true;
    _preloadPaused = true;

    final controller = context.read<SttController>();
    final targetAyahId = controller.topVerseId;
    final totalPages = controller.totalPages;
    final clampedPage = pageNumber.clamp(1, totalPages);
    final currentPos = _scrollController.offset;
    final screenHeight = MediaQuery.of(context).size.height;
    
    print('🚀 SEEK_STEP [v$retryCount]: Target $clampedPage (Current Offset: ${currentPos.round()})');

    // 1️⃣ PHASE 1: CHECK IF ALREADY THERE (Precision check)
    if (targetAyahId != null) {
      final verseKey = _verseKeys[targetAyahId];
      if (verseKey != null && verseKey.currentContext != null) {
        print('🎯 JUMP_REFINE: Precision jump to VERSE $targetAyahId');
        Scrollable.ensureVisible(verseKey.currentContext!, alignment: 0.0, duration: Duration.zero);
        _finalizeJump(clampedPage);
        return;
      }
    }

    // 2️⃣ PHASE 2: CHECK IF PAGE KEY IS VISIBLE
    final pageKey = _pageKeys[clampedPage];
    if (pageKey != null && pageKey.currentContext != null) {
      print('🎯 JUMP_REFINE: Precision jump to PAGE $clampedPage');
      Scrollable.ensureVisible(pageKey.currentContext!, alignment: 0.0, duration: Duration.zero);
      _finalizeJump(clampedPage);
      return;
    }

    // 3️⃣ PHASE 3: CALCULATE CORRECTIVE JUMP
    // Find ANY visible page key to use as a beacon
    int? beaconPage;
    double? beaconPos;
    for (int p in _pageKeys.keys) {
      final key = _pageKeys[p];
      final rBox = key?.currentContext?.findRenderObject() as RenderBox?;
      if (rBox != null) {
        beaconPage = p;
        beaconPos = rBox.localToGlobal(Offset.zero).dy;
        break; 
      }
    }

    double nextOffset;
    if (beaconPage != null && beaconPos != null) {
      // We know where beaconPage is. Use it to find clampedPage.
      final pageDelta = clampedPage - beaconPage;
      final estimatedDelta = pageDelta * (screenHeight * _estimatedHeightFactor);
      nextOffset = (currentPos + beaconPos + estimatedDelta).clamp(0, _scrollController.position.maxScrollExtent);
      print('📍 SEEK_DELTA: Found Page $beaconPage at $beaconPos dy. Jumping ${estimatedDelta.round()} to reach $clampedPage');
    } else {
      // Total blackout. Use absolute estimate.
      nextOffset = ((clampedPage - 1) * (screenHeight * _estimatedHeightFactor)).clamp(0, _scrollController.position.maxScrollExtent);
      print('📍 SEEK_ESTIMATE: No beacon. Jumping to absolute $nextOffset');
    }

    _scrollController.jumpTo(nextOffset);

    // 4️⃣ RECURSE: Wait for build then check again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToPage(clampedPage, retryCount: retryCount + 1);
    });
  }

  void _finalizeJump(int page) {
    _isJumping = false;
    _preloadPaused = false;
    _startSmartPreload(page);
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients || _isJumping) return;

    // ✅ PHASE 1: Fast math estimate for zero-latency AppBar update
    final bestPage = _calculateVisiblePage();

    // ✅ PHASE 2: Silent Update to Controller
    if (bestPage != _currentVisiblePage) {
      _currentVisiblePage = bestPage;
      
      // Update AppBar notifier instantly
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

      // ✅ CONTEXT SYNC: Detect top verse when scroll stops
      _detectTopVerseAndUpdateController();

      // Panggil smart preload
      _startSmartPreload(_currentVisiblePage);
    });
  }

  void _detectTopVerseAndUpdateController() {
    if (!mounted) return;
    
    // Low-cost detection of the top verse once scrolling stops
    final controller = context.read<SttController>();
    for (int p in [_currentVisiblePage, _currentVisiblePage + 1, _currentVisiblePage - 1]) {
      final pageLines = controller.pageCache[p];
      if (pageLines == null) continue;

      for (var line in pageLines) {
        final segments = line.ayahSegments;
        if (segments == null) continue;
        
        for (var ayah in segments) {
          final key = _verseKeys[ayah.id];
          final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero).dy;
            // If the verse is at or above the viewport top (but not too far above)
            if (position >= -100 && position <= 50) { 
              controller.updateTopVerse(ayah.id, p);
              return;
            }
          }
        }
      }
    }
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

  /// ✅ NEW: Calculate which page is MOST visible using GlobalKeys (Beacon)
  int _calculateVisiblePage() {
    if (!mounted || !_scrollController.hasClients) return _currentVisiblePage;

    final screenHeight = MediaQuery.of(context).size.height;
    final viewportTop = _scrollController.offset; // Not strictly used for localToGlobal
    
    int bestPage = _currentVisiblePage;
    double maxVisibleRatio = 0.0;

    // Scan all registered page keys
    for (final entry in _pageKeys.entries) {
      final pageNum = entry.key;
      final key = entry.value;
      final context = key.currentContext;
      
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          // Get position relative to viewport
          final offset = renderBox.localToGlobal(Offset.zero);
          final top = offset.dy;
          final bottom = top + renderBox.size.height;

          // Check intersection with viewport (0 to screenHeight)
          final visibleTop = top < 0 ? 0.0 : top;
          final visibleBottom = bottom > screenHeight ? screenHeight : bottom;
          final visibleHeight = visibleBottom - visibleTop;

          if (visibleHeight > 0) {
            final ratio = visibleHeight / screenHeight; // How much of screen does it take?
            // Or absolute height if we prefer
            
            if (visibleHeight > maxVisibleRatio) {
               maxVisibleRatio = visibleHeight;
               bestPage = pageNum;
            }
          }
        }
      }
    }

    // Fallback if no keys found (e.g. very fast scroll or init) - use math estimate relative to known beacon if possible
    // For now, if maxVisibleRatio is 0, keep current.
    if (maxVisibleRatio == 0 && _pageKeys.isEmpty) {
       // Only fallback to pure math if we have NO keys (unlikely in builder)
       // logic from original can stay as extreme fallback, but usually we prefer current
       return _currentVisiblePage; 
    }

    return bestPage.clamp(1, context.read<SttController>().totalPages);
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

    // ✅ FIX: Handle navigasi eksternal (Menu/Juz Jump)
    // Karena kita sudah tidak me-reset widget via Key, kita perlu mendeteksi
    // jika controller meminta pindah halaman secara eksplisit.
    final targetPage = controller.listViewCurrentPage;

    // Cek jika target page beda dengan posisi sekarang DAN user sedang tidak scroll
    if (targetPage != _currentVisiblePage && !_userScrolling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double check mounted & state untuk mencegah loop
        if (mounted && _currentVisiblePage != targetPage) {
          print('📍 ListView Auto-Jump: $_currentVisiblePage -> $targetPage');
          _jumpToPage(targetPage);
          _currentVisiblePage = targetPage; // Sync segera
        }
      });
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: totalPages,
      cacheExtent: 2000,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        return _VerticalPageWidget(
          key: _pageKeys[pageNum] ??= GlobalKey(debugLabel: 'page_$pageNum'),
          pageNumber: pageNum,
          verseKeys: _verseKeys, // ✅ Pass map to children
        );
      },
    );
  }
}

/// Single vertical page widget - uses cached mushaf data ONLY
class _VerticalPageWidget extends StatelessWidget {
  final int pageNumber;
  final Map<int, GlobalKey> verseKeys; // ✅ NEW

  const _VerticalPageWidget({
    super.key,
    required this.pageNumber,
    required this.verseKeys,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    final cachedLines = controller.pageCache[pageNumber];

    if (cachedLines != null && cachedLines.isNotEmpty) {
      return _VerticalPageContent(
        pageNumber: pageNumber,
        pageLines: cachedLines,
        verseKeys: verseKeys, // ✅ Pass down
      );
    }

    // ✅ Minimal loading placeholder
    final screenHeight = MediaQuery.of(context).size.height;
    final distance = (pageNumber - controller.listViewCurrentPage).abs(); // Use controller's current page

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
  final Map<int, GlobalKey> verseKeys; // ✅ NEW

  const _VerticalPageContent({
    required this.pageNumber,
    required this.pageLines,
    required this.verseKeys,
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
                    key: verseKeys[completeSegment.id] ??= GlobalKey(debugLabel: 'verse_${completeSegment.id}'),
                    segment: completeSegment,
                    fontFamily: fontFamily,
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
              fontSize: screenHeight * 0.055,
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

  const _CompleteAyahWidget({
    super.key,
    required this.segment,
    required this.fontFamily,
  });

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

      // ✅ NEW: DEEP LINK HIGHLIGHT - subtle background for current ayah
      if (state.isCurrentAyat && wordBg == Colors.transparent) {
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

      // If it is the last word (Ayah Marker), we render a special Stack
      // Otherwise we render the normal text
      if (isLastWordInAyah) {
         // Special Stack for Ayah Marker
         final baseFontSize = screenWidth * 0.0625; // Base font size used in list view
         
         return Container(
            padding: EdgeInsets.symmetric(
              horizontal: 0, 
              vertical: screenHeight * 0.00125,
            ),
             child: Container(
                  width: baseFontSize, // Match base font size (tight fit)
                  height: baseFontSize,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Lingkaran Marker (Scaled & Translated)
                      Transform.translate(
                         offset: Offset(0, -baseFontSize * 0.15),
                         child: Transform.scale(
                           scale: 1.3, // Standard scale for list view (matches Mushaf non-p1/p2)
                           child: Text(
                             '\u06DD',
                             style: TextStyle(
                               fontSize: baseFontSize, 
                               fontFamily: 'IndoPak-Nastaleeq',
                               color: state.isCurrentAyat
                                   ? AppColors.getInfo(context)
                                   : AppColors.getTextPrimary(context),
                                height: 1.0,
                             ),
                             textDirection: TextDirection.rtl,
                           ),
                         ),
                      ),
                      
                      // 2. Angka
                       Center(
                         child: Text(
                          LanguageHelper.toIndoPakDigits(segment.ayahNumber),
                          style: TextStyle(
                            fontSize: baseFontSize * 0.60, 
                            fontFamily: 'Quran-Common', 
                            color: state.isCurrentAyat
                                ? AppColors.getInfo(context)
                                : AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w800,
                             height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                       ),
                    ],
                  ),
            )
         );
      } else {
        // Normal Word
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
            ? screenWidth *
                  0.0625 // IndoPak lebih besar
            : screenWidth * 0.0625, // QPC
        fontFamily: fontFamily,
        color: isCurrentAyat
            ? AppColors.getInfo(context)
            : AppColors.getTextPrimary(context),
        fontWeight: FontWeight.w400,
        height: effectiveIsIndopak ? 1.8 : 1.7,
        letterSpacing: effectiveIsIndopak ? 0 : -5,
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
