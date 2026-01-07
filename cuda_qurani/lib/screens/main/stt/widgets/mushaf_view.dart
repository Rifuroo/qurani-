// lib\screens\main\stt\widgets\mushaf_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/models/quran_models.dart';

import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../services/quran_service.dart';
import '../utils/constants.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

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
  }) {
    if (wordSpans.isEmpty) return const SizedBox.shrink();

    final lineH = customLineHeight ?? lineHeight(context); // ✅ USE CUSTOM OR DEFAULT

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
        customLineHeight: lineH, // ✅ PASS DOWN
        useFittedBox: useFittedBox, // ✅ ADDED
      ),
    );
  }

  static Widget _usText({
    required List<InlineSpan> wordSpans,
    required double maxWidth,
    bool allowOverflow = false,
    required BuildContext context,
    double? customLineHeight, // ✅ ADDED
    required bool useFittedBox, // ✅ ADDED
  }) {
    if (wordSpans.isEmpty) return const SizedBox.shrink();

    final lineH = customLineHeight ?? lineHeight(context); // ✅ USE CUSTOM OR DEFAULT

    // Single word case
    if (wordSpans.length == 1) {
      final child = SizedBox(
        width: maxWidth,
        child: RichText(
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          text: TextSpan(
            children: [wordSpans.first],
          ), // ✅ UBAH: wrap dalam children
        ),
      );
      
      return useFittedBox 
        ? FittedBox(fit: BoxFit.scaleDown, child: child)
        : child;
    }

    // Calculate total text width WITHOUT spacing
    double totalTextWidth = 0;
    final List<double> wordWidths = [];

    for (final span in wordSpans) {
      final textPainter = TextPainter(
        text: span is TextSpan
            ? span
            : TextSpan(children: [span]), // ✅ UBAH: handle InlineSpan
        textDirection: TextDirection.rtl,
      );
      textPainter.layout();
      final width = textPainter.width;
      wordWidths.add(width);
      totalTextWidth += width;
    }

    // Build justified row with proper centering and tight spacing
    final rowContent = SizedBox(
      width: maxWidth,
      height: useFittedBox ? null : lineH, // ✅ Remove height constraint for FittedBox
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < wordSpans.length; i++) ...[
            RichText(
              textDirection: TextDirection.rtl,
              overflow: TextOverflow.visible,
              maxLines: 1,
              text: TextSpan(
                children: [wordSpans[i]],
              ), // ✅ UBAH: wrap dalam children, hapus casting
            ),
            if (i < wordSpans.length - 1) const SizedBox(width: 0.0),
          ],
        ],
      ),
    );

    return useFittedBox
        ? SizedBox(
            width: maxWidth,
            height: lineH,
            child: FittedBox(
               fit: BoxFit.scaleDown,
               child: SizedBox(
                 width: maxWidth,
                 child: rowContent,
               )
            )
          )
        : rowContent;
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
        fontSizeMultiplier = 0.090; // Good balance
        targetLineHeight = screenHeight * 0.060; // "Golden" Value
        useFittedBox = false; // Disable
      } else {
        horizontalPadding = 0.0;
        fontSizeMultiplier = 0.0690;
      }
    }

    final availableWidth = screenWidth - (horizontalPadding * 2);

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
      useFittedBox: useFittedBox, // ✅ ADDED
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();

    return GestureDetector(
      behavior: HitTestBehavior
          .translucent, // âœ… FIX: Ganti dari opaque ke translucent
      onHorizontalDragStart: (details) {
        if (!mounted) return; // âœ… FIX: Check mounted state
        _dragStartPosition = details.globalPosition.dx;
        _isSwipeInProgress = false;
      },
      onHorizontalDragUpdate: (details) {
        if (!mounted) return; // âœ… FIX: Check mounted state
        // Detect significant horizontal movement
        final dragDistance = (details.globalPosition.dx - _dragStartPosition)
            .abs();
        if (dragDistance > 50 && !_isSwipeInProgress) {
          _isSwipeInProgress = true;
        }
      },
      onHorizontalDragEnd: (details) {
        if (!mounted || !_isSwipeInProgress)
          return; // âœ… FIX: Check mounted state

        final velocity = details.primaryVelocity ?? 0;

        // Swipe threshold: 500 pixels per second
        if (velocity > 500) {
          // Swipe RIGHT = go to NEXT page (Arabic reading direction)
          controller.navigateToPage(controller.currentPage + 1);
        } else if (velocity < -500) {
          // Swipe LEFT = go to PREVIOUS page
          controller.navigateToPage(controller.currentPage - 1);
        }

        // Reset swipe state dengan safety check dan debouncing
        if (!_isUpdating) {
          _isUpdating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isSwipeInProgress = false;
                _isUpdating = false;
              });
            }
          });
        }
      },
      child: SizedBox.expand(
        // âœ… Fill entire screen for gesture detection
        child: SingleChildScrollView(
          // âœ… Allow scrolling if content exceeds screen
          physics:
              const NeverScrollableScrollPhysics(), // âœ… Disable scroll (only swipe)
          child: RepaintBoundary(
            // âœ… FIX: Isolate repaints to prevent MouseTracker conflicts
            child: _buildMushafPageOptimized(context),
          ),
        ),
      ),
    );
  }

  // âœ… CRITICAL: Track emergency loads to prevent duplicates
  static final Set<int> _emergencyLoadingPages = {};

  Widget _buildMushafPageOptimized(BuildContext context) {
    final controller = context.watch<SttController>();
    final pageNumber = controller.currentPage;
    var cachedLines = controller.pageCache[pageNumber];

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

    return Column(
      children: [
        // Header tanpa padding horizontal
        Padding(
          padding: EdgeInsets.only(top: appBarHeight),
          child: const MushafPageHeader(),
        ),

        const SizedBox(height: 0),

        // Page lines dengan padding horizontal yang bisa diatur terpisah
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal:
                screenWidth *
                0.00, // âœ… UBAH nilai ini untuk adjust padding pageLines
          ),
          child: Column(
            children: pageLines
                .map((line) => _buildMushafLine(line, context))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMushafLine(MushafPageLine line, BuildContext context) {
    final controller = context.watch<SttController>();
    final isIndopak = controller.mushafLayout == MushafLayout.indopak;
    final screenWidth = MediaQuery.of(context).size.width;

    Widget lineWidget;
    
    // ✅ Calculate config once
    final layoutConfig = MushafRenderer.calculateLayoutConfig(context, pageNumber, isIndopak);

    switch (line.lineType) {
      case 'surah_name':
        lineWidget = _SurahNameLine(line: line);
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

    return lineWidget;
  }
}

class _SurahNameLine extends StatelessWidget {
  final MushafPageLine line;
  const _SurahNameLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final headerSize = screenHeight * 0.060;
    final surahNameSize = screenHeight * 0.050;

    final controller = context.watch<SttController>();
    final isIndopak = controller.mushafLayout == MushafLayout.indopak;
    final surahGlyphCode = line.surahNumber != null
        ? controller.formatSurahIdForGlyph(line.surahNumber!)
        : '';

    final ornamentOffset = isIndopak
        ? -screenWidth *
              0.005 // indopak
        : -screenWidth * 0.005; // qpc

    print(
      '🎨 SurahNameLine - Layout: ${isIndopak ? "IndoPak" : "QPC"}, Offset: $ornamentOffset',
    );

    return Container(
      // ✅ FIX: Tambahkan key unik per layout
      key: ValueKey(
        'surah_ornament_${isIndopak ? "indopak" : "qpc"}_${line.surahNumber}',
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            // ✅ FIX: Tambahkan key pada Transform juga
            key: ValueKey(
              'ornament_transform_${isIndopak ? "indopak" : "qpc"}',
            ),
            offset: Offset(ornamentOffset, 0),
            child: Text(
              'header',
              key: ValueKey(
                'ornament_text_${isIndopak ? "indopak" : "qpc"}',
              ), // ✅ Key pada Text
              style: TextStyle(
                fontSize: headerSize - 1.5,
                fontFamily: 'Quran-Common',
                color: AppColors.getTextPrimary(context),
                height: screenHeight * 0.0010,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            surahGlyphCode,
            key: ValueKey(
              'surah_name_${isIndopak ? "indopak" : "qpc"}_${line.surahNumber}',
            ), // ✅ Key pada nama surah
            style: TextStyle(
              fontSize: surahNameSize - 1,
              fontFamily: 'surah-name-v2',
              color: AppColors.getTextPrimary(context),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

class _BasmallahLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final basmallahSize = screenHeight * 0.040;
    final controller = context.watch<SttController>();
    final isIndopakFontFamily = controller.mushafLayout == MushafLayout.indopak;
    final isIndopakFontSize = controller.mushafLayout == MushafLayout.indopak;

    return Container(
      height: MushafRenderer.lineHeight(context),
      alignment: Alignment.center,
      child: Text(
        '﷽',
        style: TextStyle(
          fontSize: isIndopakFontSize ? basmallahSize * 0.85 : basmallahSize,
          fontFamily: isIndopakFontFamily
              ? 'IndoPak-Nastaleeq'
              : 'Quran-Common',
          color: AppColors.getTextPrimary(context),
          fontWeight: FontWeight.normal,
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

  const _JustifiedAyahLine({
    required this.line,
    required this.pageNumber,
    required this.layoutConfig,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SttController>();
    final isIndopak = controller.mushafLayout == MushafLayout.indopak;

    // ✅ Use Calculated Font Size
    final baseFontSize = layoutConfig.fontSize;
    final lastWordFontMultiplier = 0.850;

    if (line.ayahSegments == null || line.ayahSegments!.isEmpty) {
      return SizedBox(height: MushafRenderer.lineHeight(context));
    }

    List<InlineSpan> spans = [];

    final fontFamily = controller.mushafLayout.isGlyphBased
        ? 'p$pageNumber' // QPC: p1, p2, p3, etc.
        : 'IndoPak-Nastaleeq'; // IndoPak: single font for all pages

    for (final segment in line.ayahSegments!) {
      final ayatIndex = controller.ayatList.indexWhere(
        (a) => a.surah_id == segment.surahId && a.ayah == segment.ayahNumber,
      );
      final isCurrentAyat =
          ayatIndex >= 0 && ayatIndex == controller.currentAyatIndex;

      for (int i = 0; i < segment.words.length; i++) {
        final word = segment.words[i];
        final wordIndex = word.wordNumber - 1;

        // ✅ CRITICAL FIX: Use ACTUAL surah:ayah from segment, not hardcoded
        final wordStatusKey = '${segment.surahId}:${segment.ayahNumber}';
        final wordStatus = controller.wordStatusMap[wordStatusKey]?[wordIndex];

        // 🎥 DEBUG: Only log if listening mode is active
        if (controller.isListeningMode && isCurrentAyat) {
          // print('🎨 UI RENDER: ...'); 
        }

        final wordSegments = controller.segmentText(word.text);
        final hasArabicNumber = wordSegments.any((s) => s.isArabicNumber);

        Color wordBg = Colors.transparent;
        double wordOpacity = 1.0;

        final isLastWordInAyah =
            segment.isEndOfAyah && i == (segment.words.length - 1);

        // ========== PRIORITAS 1: Background color dari wordStatus ==========
        // SKIP highlighting for Arabic numbers (ayah end markers)
        if (wordStatus != null && !hasArabicNumber) {
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
              if (controller.isRecording || controller.isListeningMode) {
                wordBg = AppColors.getInfo(context).withValues(alpha: 0.4);
              } else {
                wordBg = Colors.transparent;
              }
              break;
            case WordStatus.pending:
              wordBg = Colors.transparent;
              break;
          }
        }

        // ✅ NEW: DEEP LINK HIGHLIGHT - subtle primary background for the entire current Ayah
        if (isCurrentAyat && wordBg == Colors.transparent) {
          wordBg = AppColors.getPrimary(context).withValues(alpha: 0.1);
        }

        // ========== PRIORITAS 2: Logika Opacity (hideUnread) ==========
        if (controller.hideUnreadAyat) {
          if (wordStatus != null && wordStatus != WordStatus.pending) {
            wordOpacity = 1.0;
          } else if (isCurrentAyat) {
            wordOpacity = (hasArabicNumber || isLastWordInAyah) ? 1.0 : 0.0;
          } else {
            wordOpacity = (hasArabicNumber || isLastWordInAyah) ? 1.0 : 0.0;
          }
        }

        final segments = controller.segmentText(word.text);
        final isLastWord = isLastWordInAyah;
        final effectiveFontSize = isLastWord
            ? baseFontSize * lastWordFontMultiplier
            : baseFontSize;

        for (final textSegment in segments) {
          spans.add(
            TextSpan(
              text: textSegment.text,
              style: TextStyle(
                fontSize: effectiveFontSize,
                fontFamily: fontFamily,
                color: _getWordColor(
                  isCurrentAyat,
                  context,
                ).withValues(alpha: wordOpacity),
                backgroundColor: wordBg,
                fontWeight: FontWeight.w400,
                // ✅ Conditional Style for P1/P2 vs Others
                // APPLIES TO BOTH INDOPAK AND QPC
                // Step 60 Metrics: Height 1.5, Spacing 0.0
                height: (pageNumber == 1 || pageNumber == 2) 
                    ? 1.5 
                    : (isIndopak ? 1.9 : 1.8), 
                letterSpacing: (pageNumber == 1 || pageNumber == 2)
                    ? 0.0 
                    : (isIndopak ? -0.420 : -5),
                decoration: (controller.hideUnreadAyat && !isLastWord)
                    ? TextDecoration.underline
                    : null,
                decorationColor: AppColors.getTextPrimary(
                  context,
                ).withValues(alpha: 0.15),
                decorationThickness: 0.3,
              ),
            ),
          );
        }
      }
    }

    // ✅ Build line widget with CORRECT Available Width
    // We must pass the width that accounts for the padding!
    final lineWidget = MushafRenderer.renderJustifiedLine(
      wordSpans: spans,
      isCentered: line.isCentered,
      availableWidth: layoutConfig.availableWidth,
      context: context,
      allowOverflow: false,
      customLineHeight: layoutConfig.lineHeight,
      useFittedBox: layoutConfig.useFittedBox, // ✅ PASS FLAG
    );

    return lineWidget; // Return directly, Padding is handled in parent
  }
}

// Methods tetap sama
Color _getWordColor(bool isCurrentWord, BuildContext context) {
  return isCurrentWord
      ? getListeningColor(context)
      : AppColors.getTextPrimary(context);
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
    final controller = context.watch<SttController>();
    final isIndopak = controller.mushafLayout == MushafLayout.indopak;
    final headerFontSize = screenWidth * 0.035;
    final headerHeight = screenHeight * 0.035;
    final juzText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'mushaf_view.juz_text')
        : 'Juz';

    final juzNumber = controller.currentPageAyats.isNotEmpty
        ? controller.calculateJuz(
            controller.currentPageAyats.first.surah_id,
            controller.currentPageAyats.first.ayah,
          )
        : 1;

    return Container(
      height: headerHeight,
      // âœ… FIX: Hapus background color sama sekali
      padding: EdgeInsets.symmetric(
        horizontal: isIndopak
            ? screenWidth *
                  0.035 // indopak
            : screenWidth * 0.010, // qpc,
      ), // âœ… CHANGE: Minimal horizontal padding (was screenWidth * 0.005)
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
