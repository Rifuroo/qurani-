// lib\screens\main\stt\widgets\mushaf_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/models/quran_models.dart';

import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import '../data/models.dart';
import '../services/quran_service.dart';
import '../services/mushaf_widget_cache.dart';
import '../utils/constants.dart';
import '../utils/ayah_char_mapper.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/mushaf_paper_background.dart';



class MushafRenderer {
  static double pageHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.85; // 85% screen height
  }

  static double lineHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.050; // Reverted to default 5.0%
  }

  static const double PAGE_PADDING =
      0.0; // Reduced side padding for less crowding
  static const double WORD_SPACING_MIN = 0.0; // Minimum gap between words
  static const double WORD_SPACING_MAX =
      0.0; // Maximum gap to prevent huge spaces

  // Render justified text for ayah lines
  static Widget renderJustifiedLine({
    required List<InlineSpan> wordSpans,
    required bool isCentered,
    required double availableWidth,
    required BuildContext context,
    bool allowOverflow = false,
    double? customLineHeight,
    bool useFittedBox = false, // ✅ ADDED
    required double baseFontSize, // Not used in flex layout but kept for signature compatibility
  }) {
    if (wordSpans.isEmpty) return const SizedBox.shrink();

    final lineH = customLineHeight ?? lineHeight(context);

    if (isCentered) {
      return SizedBox(
        height: lineH,
        width: availableWidth,
        child: Center(
          child: RichText(
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            overflow: TextOverflow.visible,
            text: TextSpan(children: wordSpans),
          ),
        ),
      );
    }

    return SizedBox(
      height: lineH,
      width: availableWidth,
      child: _usText(
        wordSpans: wordSpans,
        maxWidth: availableWidth,
        allowOverflow: allowOverflow,
        context: context,
        customLineHeight: lineH,
        useFittedBox: useFittedBox,
      ),
    );
  }

  static Widget _usText({
    required List<InlineSpan> wordSpans,
    required double maxWidth,
    bool allowOverflow = false,
    required BuildContext context,
    double? customLineHeight,
    required bool useFittedBox,
  }) {
    if (wordSpans.isEmpty) return const SizedBox.shrink();

    final lineH = customLineHeight ?? lineHeight(context);

    // Single word case
    if (wordSpans.length == 1) {
      final child = SizedBox(
        width: maxWidth,
        child: RichText(
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          text: TextSpan(
            children: [wordSpans.first],
          ),
        ),
      );

      return useFittedBox 
        ? FittedBox(fit: BoxFit.scaleDown, child: child)
        : child;
    }

    // ✅ ROBUST FALLBACK: Use a single unified Row with SpaceBetween
    // and wrap the entire thing in a FittedBox with scaleDown.
    // This provides "Lurus" (straight) edges whenever possible
    // and invisible scaling for tiny overflows (like 1.7px).
    return SizedBox(
      width: maxWidth,
      height: lineH,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: SizedBox(
          width: maxWidth,
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < wordSpans.length; i++) 
                RichText(
                  textDirection: TextDirection.rtl,
                  text: TextSpan(children: [wordSpans[i]]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Centralized layout configuration for consistency
  static MushafLayoutConfig calculateLayoutConfig(
    BuildContext context,
    int pageNumber,
    bool isIndopak,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double horizontalPadding = 0.0;
    double fontSizeMultiplier = 0.055; // Default declaration
    double scaleX = 1.0;
    double scaleY = 1.0;
    double targetLineHeight = lineHeight(context); // Default
    bool useFittedBox = false; // Default

    // 1. Determine Padding & Scale based on layout/page
    if (isIndopak) {
      if (pageNumber == 1 || pageNumber == 2) {
         // Page 1 & 2: Replicating "Relaxed Density" (Step 60)
         horizontalPadding = screenWidth * 0.05;
         fontSizeMultiplier = 0.070; // Good balance
         scaleY = 1.0;
         scaleX = 1.0;
         targetLineHeight = screenHeight * 0.060; // "Golden" Value
         useFittedBox = false; // Disable to trust natural layout
      } else {
        // Normal pages: Tighter layout (Reverted)
        horizontalPadding = 0.0;
        fontSizeMultiplier = 0.0630; // Standard font
        scaleY = 1.150;
        scaleX = 0.98;
        targetLineHeight = screenHeight * 0.050; // Standard line
        useFittedBox = false;
      }
    } else {
      // QPC / Standard
      if (pageNumber == 1 || pageNumber == 2) {
        horizontalPadding = screenWidth * 0.05;
        fontSizeMultiplier = 0.062; // Good balance
        targetLineHeight = screenHeight * 0.060; // "Golden" Value
        useFittedBox = false; // Disable
      } else {
        horizontalPadding = 0.0;
        fontSizeMultiplier = 0.060;
      }
    }

    // ✅ SAFETY: Subtract 2 pixels total for rounding safety
    final availableWidth = screenWidth - (horizontalPadding * 2) - 2.0;

    // 2. Calculate Responsive Font Size
    // Removed strict height constraint to restore original behavior for normal pages
    double calculatedFontSize = screenWidth * fontSizeMultiplier;
    
    // ✅ RESTORED: Constraint enabled ONLY for normal pages (without FittedBox)
    // This ensures Page 3+ don't have overflowing text, restoring original look.
    if (!useFittedBox) {
      final maxFontSizeByHeight = targetLineHeight * 0.85; 
      if (calculatedFontSize > maxFontSizeByHeight) {
        calculatedFontSize = maxFontSizeByHeight;
      }
    }

    return MushafLayoutConfig(
      horizontalPadding: horizontalPadding,
      availableWidth: availableWidth,
      fontSize: calculatedFontSize,
      scaleX: scaleX,
      scaleY: scaleY,
      lineHeight: targetLineHeight,
      useFittedBox: useFittedBox,
    );
  }
}

// ✅ STANDALONE CONFIG CLASS
class MushafLayoutConfig {
  final double horizontalPadding;
  final double availableWidth;
  final double fontSize;
  final double scaleX;
  final double scaleY;
  final double lineHeight;
  final bool useFittedBox; // ✅ ADDED

  MushafLayoutConfig({
    required this.horizontalPadding,
    required this.availableWidth,
    required this.fontSize,
    required this.scaleX,
    required this.scaleY,
    required this.lineHeight,
    required this.useFittedBox, // ✅ ADDED
  });
}

class MushafDisplay extends StatefulWidget {
  const MushafDisplay({Key? key}) : super(key: key); // ✅ Already OK

  @override
  State<MushafDisplay> createState() => _MushafDisplayState();
}

class _MushafDisplayState extends State<MushafDisplay> {
  bool _isSwipeInProgress = false;
  double _dragStartPosition = 0;
  bool _isUpdating = false; // âœ… FIX: Prevent concurrent updates

  late PageController _pageController; // ✅ PERSIST CONTROLLER

  @override
  void initState() {
    super.initState();
    // ✅ Initialize once to avoid "patah-patah" on rebuild
    final controller = context.read<SttController>();
    _pageController = PageController(initialPage: controller.currentPage - 1);
    
    // ✅ REAL-TIME MONITOR: Update AppBar quietly during fast swipe
    _pageController.addListener(() {
       if (_pageController.hasClients && _pageController.page != null) {
         // Report to controller quietly (NO rebuild of MushafView)
         final pageNum = _pageController.page!.round() + 1;
         controller.updateVisiblePageQuiet(pageNum);
       }
    });

    // ✅ SYNC LISTENER: Handle external page changes (e.g. from Surah Picker)
    controller.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (!mounted) return;
    final controller = context.read<SttController>();
    
    // ✅ SYNC: Only jump if page actually differs and we ARE NOT swiping
    // This prevents "fighting" between PageView and Controller
    if (_pageController.hasClients) {
      final currentViewPage = (_pageController.page?.round() ?? _pageController.initialPage) + 1;
      if (controller.currentPage != currentViewPage) {
         // Only jump if not currently being manipulated by user
         if (!_pageController.position.isScrollingNotifier.value) {
           _pageController.animateToPage(
             controller.currentPage - 1,
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeInOut,
           );
         }
      }
    }
  }

  @override
  void dispose() {
    // ✅ Clean up listener
    try {
      context.read<SttController>().removeListener(_handleControllerChange);
    } catch (_) {}
    _pageController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // âœ… OPTIMIZATION: Read controller once
    final controller = context.read<SttController>();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            controller.setIsSwiping(true);
          } else if (notification is ScrollEndNotification) {
            controller.setIsSwiping(false);
          }
          return false;
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: controller.totalPages,
          reverse: true, // Arabic direction
          physics: const BouncingScrollPhysics(),
          onPageChanged: (newIndex) {
            final newPage = newIndex + 1;
            // Debounce or only update if changed
            if (newPage != controller.currentPage) {
              controller.navigateToPage(newPage);
            }
          },
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
  
            // ðŸ”¥ GRANULAR REBUILD: Only this part rebuilds when isSwiping changes
            // This prevents the entire PageView from being affected by swipe status
            return Selector<SttController, bool>(
              selector: (_, c) => c.isSwiping,
              builder: (ctx, isSwiping, _) {
                // âœ… OPTIMIZATION: Bypass permanent cache during swipe to show ultra-fast static rendering
                if (isSwiping) {
                  return _buildMushafPageOptimized(ctx, pageNumber);
                }
  
                // âœ… ULTIMATE CACHING: Render once, keep forever in LRU cache
                return CachedMushafPage(
                  pageNumber: pageNumber,
                  layout: controller.mushafLayout,
                  builder: () => _buildMushafPageOptimized(ctx, pageNumber),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // âœ… CRITICAL: Track emergency loads to prevent duplicates
  static final Set<int> _emergencyLoadingPages = {};

  Widget _buildMushafPageOptimized(BuildContext context, int pageNumber) {
    //  ✅ OPTIMIZATION: Use granular selects for cache
    // We only care if the cache for THIS SPECIFIC page updates.
    var cachedLines = context.select<SttController, List<MushafPageLine>?>((c) => c.pageCache[pageNumber]);
    final controller = context.read<SttController>(); 

    // âœ… CRITICAL: Also check QuranService cache (shared singleton)
    if (cachedLines == null || cachedLines.isEmpty) {
      final service = context.read<QuranService>();
      final serviceCache = service.getCachedPage(pageNumber);
      if (serviceCache != null && serviceCache.isNotEmpty) {
        // âœ… Sync cache immediately
        controller.updatePageCache(pageNumber, serviceCache);
        cachedLines = serviceCache;
      }
    }

    // âœ… FAST PATH: If page is cached, render immediately (NO LOADING)
    if (cachedLines != null && cachedLines.isNotEmpty) {
      // âœ… OPTIMIZED: Use RepaintBoundary to prevent unnecessary repaints
      return RepaintBoundary(
        key: ValueKey('mushaf_page_$pageNumber'),
        child: MushafPageContent(
          pageLines: cachedLines,
          pageNumber: pageNumber,
        ),
      );
    }



    // âš ï¸ FALLBACK: Emergency load only if not already loading
    if (!_emergencyLoadingPages.contains(pageNumber)) {
      final service = context.read<QuranService>();

      // âœ… CRITICAL: Check if page is already being loaded in QuranService
      if (service.isPageLoading(pageNumber)) {
        // Wait for existing load instead of creating duplicate
        final loadingFuture = service.getLoadingFuture(pageNumber);
        if (loadingFuture != null) {
          loadingFuture
              .then((lines) {
                controller.updatePageCache(pageNumber, lines);
              })
              .catchError((e) {
                print('âŒ Waiting for page $pageNumber load failed: $e');
              });
          // Show loading indicator while waiting
        }
      } else {
        // Only trigger new emergency load if not already loading
        _emergencyLoadingPages.add(pageNumber);
        print(
          'âš ï¸ CACHE MISS: Page $pageNumber not cached, emergency loading...',
        );

        // âœ… CRITICAL: Trigger emergency load and sync cache
        Future.microtask(() async {
          try {
            final lines = await service.getMushafPageLines(pageNumber);

            // âœ… CRITICAL: Sync cache to controller immediately
            controller.updatePageCache(pageNumber, lines);
          } catch (e) {
            print('âŒ Emergency load failed: $e');
          } finally {
            _emergencyLoadingPages.remove(pageNumber);
          }
        });
      }
    }

    // Show ultra-minimal loading (should be < 100ms)
    return SizedBox(
      height: MushafRenderer.pageHeight(context),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.03,
          height: MediaQuery.of(context).size.width * 0.03,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.getTextTertiary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class MushafPageContent extends StatelessWidget {
  final List<MushafPageLine> pageLines;
  final int pageNumber;
  const MushafPageContent({
    super.key,
    required this.pageLines,
    required this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    final appBarHeight = kToolbarHeight * 0.95;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSpecialPage = pageNumber == 1 || pageNumber == 2;

    // ✅ CALCULATE LAYOUT CONFIG ONCE PER PAGE
    final controller = context.read<SttController>();
    final isIndopak = context.select<SttController, bool>((c) => c.mushafLayout == MushafLayout.indopak);
    final layoutConfig = MushafRenderer.calculateLayoutConfig(context, pageNumber, isIndopak);

    // ✅ HARDENING: Record viewport width for coordinate mapping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        controller.setViewportWidth(layoutConfig.availableWidth);
      }
    });

    final linesContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: pageLines
          .map((line) => _buildMushafLine(line, context, layoutConfig))
          .toList(),
    );

    // ✅ CRITICAL: Clip page to prevent bleeding into adjacent pages during swipe
    // ✅ Use ClipRect with explicit size for efficient clipping
    return SizedBox(
      width: screenWidth,
      child: ClipRect(
        child: Column(
          children: [
            // Header tanpa padding horizontal
            Padding(
              padding: EdgeInsets.only(top: appBarHeight),
              child: const MushafPageHeader(),
            ),

            // ✅ KHUSUS HALAMAN 1 & 2: Tambahkan ruang kosong di atas Surah Header
            if (isSpecialPage)
              SizedBox(height: screenHeight * 0.15),

            const SizedBox(height: 0),

            // Page lines dengan padding horizontal yang bisa diatur terpisah
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.0,
              ),
              child: linesContent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMushafLine(MushafPageLine line, BuildContext context, MushafLayoutConfig layoutConfig) {
    // ✅ OPTIMIZATION: Use read/select instead of watch to prevent full page rebuilds on highlight
    
    Widget lineWidget;

    switch (line.lineType) {
      case 'surah_name':
        lineWidget = _SurahNameLine(line: line);
        // ✅ KHUSUS HALAMAN 1 & 2: Tambahkan padding bawah sedikit biar nggak kedeketan sama Basmallah/Ayat
        if (pageNumber == 1 || pageNumber == 2) {
          lineWidget = Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.04),
            child: lineWidget,
          );
        }
        break;

      case 'basmallah':
        lineWidget = _BasmallahLine();
        break;

      case 'ayah':
        // ✅ Pass config to line
        lineWidget = _JustifiedAyahLine(
            line: line, 
            pageNumber: pageNumber,
            layoutConfig: layoutConfig,
        );

        // ✅ Apply Scale if needed (Indopak)
        if (layoutConfig.scaleX != 1.0 || layoutConfig.scaleY != 1.0) {
          lineWidget = Transform.scale(
            scaleX: layoutConfig.scaleX,
            scaleY: layoutConfig.scaleY,
            alignment: Alignment.center,
            child: lineWidget,
          );
        }

        // ✅ Apply Padding if needed
        if (layoutConfig.horizontalPadding > 0) {
           lineWidget = Padding(
            padding: EdgeInsets.symmetric(
              horizontal: layoutConfig.horizontalPadding,
            ),
            child: lineWidget,
          );
        }
        break;

      default:
        lineWidget = const SizedBox.shrink();
    }

    // ✅ WRAP EACH LINE IN REPAINT BOUNDARY TO MINIMIZE GPU WORK
    return RepaintBoundary(child: lineWidget);
  }
}

class _SurahNameLine extends StatelessWidget {
  final MushafPageLine line;
  const _SurahNameLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final headerSize = screenHeight * 0.040;
    final surahNameSize = screenHeight * 0.045; // 👈 Ubah angka ini untuk mengatur besar Nama Surah (0.050 -> 0.040)

    final controller = context.read<SttController>();
    final isIndopak = context.select<SttController, bool>((c) => c.mushafLayout == MushafLayout.indopak);

    final surahGlyphCode = line.surahNumber != null
        ? controller.formatSurahHeaderName(line.surahNumber!)
        : '';

    final ornamentOffset = isIndopak
        ? -screenWidth *
              0.005 // indopak
        : -screenWidth * 0.004; // qpc


    return Center(
      key: ValueKey(
        'surah_ornament_${isIndopak ? "indopak" : "qpc"}_${line.surahNumber}',
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // PNG Header Frame - SCALES DIRECTLY WITH headerSize
            Image.asset(
              'assets/surah-header/chapter_hdr.png',
              height: headerSize * 1.5, // Control this via headerSize
              fit: BoxFit.contain,
              color: AppColors.getAyahNumber(context),
              colorBlendMode: BlendMode.srcIn,
            ),
            // Surah Name Text
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Text(
                surahGlyphCode,
                key: ValueKey(
                  'surah_name_${isIndopak ? "indopak" : "qpc"}_${line.surahNumber}',
                ),
                style: TextStyle(
                  fontSize: surahNameSize - 1,
                  fontFamily: 'surah-name-v2', // ✅ Use V2 for all (V4 removed)
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

class _BasmallahLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final basmallahSize = screenHeight * 0.040;
    final isIndopak = context.select<SttController, bool>((c) => c.mushafLayout == MushafLayout.indopak);

    return Container(
      height: MushafRenderer.lineHeight(context),
      alignment: Alignment.center,
      child: Text(
        '﷽',
        style: TextStyle(
          fontSize: isIndopak ? basmallahSize * 0.85 : basmallahSize,
          fontFamily: isIndopak ? 'IndoPak-Nastaleeq' : 'Quran-Common',
          color: AppColors.getTextPrimary(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _JustifiedAyahLine extends StatelessWidget {
  final MushafPageLine line;
  final int pageNumber;
  final MushafLayoutConfig layoutConfig; // ✅ Use Config

  // ✅ OPTIMIZATION: Pre-compile RegExp to avoid recreation inside loop
  static final RegExp _arabicNumberRegExp = RegExp(r'[٠-٩0-9]');

  const _JustifiedAyahLine({
    required this.line,
    required this.pageNumber,
    required this.layoutConfig,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ OPTIMIZATION: Use granular selects to avoid full page rebuilds
    final mushafLayout = context.select<SttController, MushafLayout>((c) => c.mushafLayout);
    final isIndopak = mushafLayout == MushafLayout.indopak;
    final currentAyatIndex = context.select<SttController, int>((c) => c.currentAyatIndex);
    final isListeningMode = context.select<SttController, bool>((c) => c.isListeningMode);
    final isRecording = context.select<SttController, bool>((c) => c.isRecording);
    final isSwiping = context.select<SttController, bool>((c) => c.isSwiping);
    final hideUnreadAyat = context.select<SttController, bool>((c) => c.hideUnreadAyat);
    
    // Select ONLY the word status for the current active highlight if it belongs to this line
    final lineAyahKeys = line.ayahSegments?.map((s) => '${s.surahId}:${s.ayahNumber}').toSet() ?? {};
    final isSpecialPage = pageNumber == 1 || pageNumber == 2;
    
    // ⚡️ ULTIMATE OPTIMIZATION: Rebuild ONLY if the active highlight is on THIS line
    final lineHighlightState = context.select<SttController, String>((c) {
      if (c.currentHighlightKey == null || !lineAyahKeys.contains(c.currentHighlightKey)) {
        final hasAnyActive = lineAyahKeys.any((key) => 
          c.wordStatusMap[key]?.values.any((s) => s != WordStatus.pending) ?? false
        );
        return hasAnyActive ? 'has_status' : 'none';
      }
      return '${c.currentHighlightKey}:${c.currentHighlightWordIdx}';
    });

    final controller = context.read<SttController>();
    final baseFontSize = layoutConfig.fontSize;
    final fontFamily = mushafLayout.isGlyphBased ? 'p$pageNumber' : 'IndoPak-Nastaleeq';

    if (line.ayahSegments == null || line.ayahSegments!.isEmpty) {
      return SizedBox(height: MushafRenderer.lineHeight(context));
    }

    // ðŸ“ THE TARTEEL WAY: ALWAYS use static rendering (ultra-fast)
    // We no longer switch to word-by-word TextSpans after swiping.
    // Instead, we use a single permanent static block and draw highlights as an OVERLAY.
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true, // Absorb scrolls
      child: Stack(
        children: [
          // Layer 1: Static Text (Independently cached as a bitmap)
          RepaintBoundary(
            key: ValueKey('static_line_${pageNumber}_${line.lineNumber}'),
            child: _buildStaticLine(context, layoutConfig, pageNumber, fontFamily),
          ),

          // Layer 2: Highlight Overlay (Drawn on separate Canvas)
          Positioned.fill(
            child: RepaintBoundary(
              child: _WordHighlightOverlay(
                line: line,
                pageNumber: pageNumber,
                layoutConfig: layoutConfig,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticLine(BuildContext context, MushafLayoutConfig layoutConfig, int pageNumber, String fontFamily) {
    final controller = context.read<SttController>();
    final key = 'p${pageNumber}_l${line.lineNumber}'; 
    final baseFontSize = layoutConfig.fontSize;
    final textColor = AppColors.getTextPrimary(context);

    // ✅ PRIORITY 1: Use pre-built spans from controller cache (FASTEST)
    final prebuilt = controller.prebuiltSpans[key];
    
    List<InlineSpan> spans;
    if (prebuilt != null) {
      spans = prebuilt;
    } else {
      // ✅ FALLBACK: Build using AyahCharMapper (matches prebuilt logic)
      spans = AyahCharMapper.buildStaticLineSpans(
        line, 
        fontFamily, 
        baseFontSize: baseFontSize,
        textColor: textColor,
      );
    }

    return MushafRenderer.renderJustifiedLine(
      wordSpans: spans,
      isCentered: line.isCentered,
      availableWidth: layoutConfig.availableWidth,
      context: context,
      customLineHeight: layoutConfig.lineHeight,
      useFittedBox: false,
      baseFontSize: baseFontSize,
    );
  }
}


/// ✅ Canvas-Based Highlighting Overlay
class _WordHighlightOverlay extends StatelessWidget {
  final MushafPageLine line;
  final int pageNumber;
  final MushafLayoutConfig layoutConfig;

  const _WordHighlightOverlay({
    required this.line,
    required this.pageNumber,
    required this.layoutConfig,
  });

  @override
  Widget build(BuildContext context) {
    // ⚡️ ULTIMATE OPTIMIZATION: Only rebuild the overlay when relevant state changes
    final lineAyahKeys = line.ayahSegments?.map((s) => '${s.surahId}:${s.ayahNumber}').toSet() ?? {};
    final mushafLayout = context.select<SttController, MushafLayout>((c) => c.mushafLayout);
    final fontFamily = mushafLayout.isGlyphBased ? 'p$pageNumber' : 'IndoPak-Nastaleeq';

    // Select the aggregate state for this line
    final overlayState = context.select<SttController, String>((c) {
      if (c.currentHighlightKey != null && lineAyahKeys.contains(c.currentHighlightKey)) {
        return 'active:${c.currentHighlightKey}:${c.currentHighlightWordIdx}';
      }
      
      // Also check if any words on this line have a special status
      final hasStatus = lineAyahKeys.any((key) {
        final map = c.wordStatusMap[key];
        return map != null && map.values.any((s) => s != WordStatus.pending);
      });
      
      return hasStatus ? 'data' : 'none';
    });

    if (overlayState == 'none') return const SizedBox.shrink();

    return CustomPaint(
      painter: _WordHighlightPainter(
        line: line,
        pageNumber: pageNumber,
        controller: context.read<SttController>(),
        layoutConfig: layoutConfig,
        fontFamily: fontFamily,
        // ✅ Pre-fetch colors to stay away from context in paint()
        correctColor: AppColors.getCorrect(context).withValues(alpha: 0.4),
        incorrectColor: AppColors.getIncorrect(context).withValues(alpha: 0.4),
        infoColor: AppColors.getInfo(context).withValues(alpha: 0.4),
        primaryColor: AppColors.getPrimary(context).withValues(alpha: 0.1),
      ),
    );
  }
}

class _WordHighlightPainter extends CustomPainter {
  final MushafPageLine line;
  final int pageNumber;
  final SttController controller;
  final MushafLayoutConfig layoutConfig;
  final String fontFamily;
  final Color correctColor;
  final Color incorrectColor;
  final Color infoColor;
  final Color primaryColor;

  _WordHighlightPainter({
    required this.line,
    required this.pageNumber,
    required this.controller,
    required this.layoutConfig,
    required this.fontFamily,
    required this.correctColor,
    required this.incorrectColor,
    required this.infoColor,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (line.ayahSegments == null) return;

    final geometry = controller.geometryCache[pageNumber];
    if (geometry == null) return; // Wait for precomputation

    final wordStatusMap = controller.wordStatusMap;
    final isCurrentAyat = controller.currentHighlightKey != null && 
                          line.ayahSegments!.any((s) => s.verseKey == controller.currentHighlightKey);

    for (final segment in line.ayahSegments!) {
      final key = segment.verseKey;
      
      for (final word in segment.words) {
         final wordIdx = word.wordNumber - 1;
         final status = wordStatusMap[key]?[wordIdx];
         
         // 1. Determine Color
         Color? highlightColor;
         if (status != null && status != WordStatus.pending) {
           highlightColor = _getHighlightColor(status);
         } else if (key == controller.currentHighlightKey && controller.currentHighlightWordIdx == wordIdx) {
           highlightColor = primaryColor;
         }

         if (highlightColor != null) {
           // 2. O(1) LOOKUP: No TextPainter.layout() or getBoxesForSelection() here!
           final geometryKey = PageGeometry.getWordKey(segment.surahId, segment.ayahNumber, word.wordNumber);
           final rects = geometry.wordBounds[geometryKey];

           if (rects != null) {
             final paint = Paint()..color = highlightColor;
             for (final rect in rects) {
               // ✅ HARDENING: Ensure coordinate alignment with current size
               // Scale factor if view size differs from computation size
               canvas.drawRRect(
                 RRect.fromRectAndRadius(rect, const Radius.circular(4)),
                 paint,
               );
             }
           }
         }
      }
    }
  }

  // ✅ REMOVED: _createTextPainter - No measurement logic allowed in paint()

  Color _getHighlightColor(WordStatus status) {
    switch (status) {
      case WordStatus.matched:
      case WordStatus.correct:
        return correctColor;
      case WordStatus.mismatched:
      case WordStatus.incorrect:
      case WordStatus.skipped:
        return incorrectColor;
      case WordStatus.processing:
        return infoColor;
      default:
        return Colors.transparent;
    }
  }

  @override
  bool shouldRepaint(covariant _WordHighlightPainter oldDelegate) {
    // Re-paint if anything in the controller's highlight state changed
    return controller.currentHighlightKey != oldDelegate.controller.currentHighlightKey ||
           controller.currentHighlightWordIdx != oldDelegate.controller.currentHighlightWordIdx ||
           controller.wordStatusMap != oldDelegate.controller.wordStatusMap;
  }
}


// Methods tetap sama
Color _getWordColor(bool isCurrentWord, BuildContext context) {
  return AppColors.getTextPrimary(context);
}

Color getCorrectColor(BuildContext context) {
  return AppColors.getCorrect(context);
}

Color getErrorColor(BuildContext context) {
  return AppColors.getIncorrect(context);
}

class MushafPageHeader extends StatefulWidget {
  const MushafPageHeader({super.key});

  @override
  State<MushafPageHeader> createState() => _MushafPageHeaderState();
}

class _MushafPageHeaderState extends State<MushafPageHeader> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('stt');
    setState(() {
      _translations = trans;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✅ OPTIMIZATION: Use select to only rebuild when RELEVANT state changes
    final mushafLayout = context.select<SttController, MushafLayout>((c) => c.mushafLayout);
    final currentPageAyats = context.select<SttController, List<AyatData>>((c) => c.currentPageAyats);
    final isIndopak = mushafLayout == MushafLayout.indopak;

    final controller = context.read<SttController>(); 
    final headerFontSize = screenWidth * 0.035;
    final headerHeight = screenHeight * 0.035;
    final juzText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'mushaf_view.juz_text')
        : 'Juz';

    final juzNumber = currentPageAyats.isNotEmpty
        ? controller.calculateJuz(
            currentPageAyats.first.surah_id,
            currentPageAyats.first.ayah,
          )
        : 1;

    return Container(
      height: headerHeight,
      // ✅ FIX: Hapus background color sama sekali
      padding: EdgeInsets.symmetric(
        horizontal: isIndopak
            ? screenWidth *
                  0.035 // indopak
            : screenWidth * 0.010, // qpc,
      ), // ✅ CHANGE: Minimal horizontal padding (was screenWidth * 0.005)
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$juzText ${context.formatNumber(juzNumber)}',
            style: TextStyle(
              fontSize: headerFontSize,
              color: AppColors.getTextPrimary(context).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textDirection: TextDirection.rtl,
          ),
          Text(
            '${context.formatNumber(controller.currentPage)}',
            style: TextStyle(
              fontSize: headerFontSize,
              color: AppColors.getTextPrimary(context).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
