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
    return MediaQuery.of(context).size.height * 0.050; // Reverted to original 5.0%
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
    bool useFittedBox = false,
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

    // Calculate total text width WITHOUT spacing for FittedBox decision
    double totalTextWidth = 0;
    for (final span in wordSpans) {
      if (span is WidgetSpan) {
         totalTextWidth += 40.0; // Approximation for marker
      } else {
         final painter = TextPainter(
           text: span is TextSpan ? span : TextSpan(children: [span]),
           textDirection: TextDirection.rtl,
           maxLines: 1,
         )..layout();
         totalTextWidth += painter.width;
      }
    }

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
    double fontSizeMultiplier = 0.055;
    double scaleX = 1.0;
    double scaleY = 1.0;
    double targetLineHeight = lineHeight(context);
    bool useFittedBox = false;

    if (isIndopak) {
      if (pageNumber == 1 || pageNumber == 2) {
         horizontalPadding = screenWidth * 0.05;
         fontSizeMultiplier = 0.070;
         scaleY = 1.0;
         scaleX = 1.0;
         targetLineHeight = screenHeight * 0.060;
         useFittedBox = false;
      } else {
        horizontalPadding = 0.0;
        fontSizeMultiplier = 0.0630;
        scaleY = 1.150;
        scaleX = 0.98;
        targetLineHeight = screenHeight * 0.050;
        useFittedBox = false;
      }
    } else {
      if (pageNumber == 1 || pageNumber == 2) {
        horizontalPadding = screenWidth * 0.05;
        fontSizeMultiplier = 0.062;
        targetLineHeight = screenHeight * 0.060;
        useFittedBox = false;
      } else {
        horizontalPadding = 0.0;
        fontSizeMultiplier = 0.060;
        targetLineHeight = screenHeight * 0.050;
      }
    }

    final availableWidth = screenWidth - (horizontalPadding * 2) - 2.0;
    double calculatedFontSize = screenWidth * fontSizeMultiplier;

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

class MushafLayoutConfig {
  final double horizontalPadding;
  final double availableWidth;
  final double fontSize;
  final double scaleX;
  final double scaleY;
  final double lineHeight;
  final bool useFittedBox;

  MushafLayoutConfig({
    required this.horizontalPadding,
    required this.availableWidth,
    required this.fontSize,
    required this.scaleX,
    required this.scaleY,
    required this.lineHeight,
    required this.useFittedBox,
  });
}

class MushafDisplay extends StatefulWidget {
  const MushafDisplay({Key? key}) : super(key: key); // ✅ Already OK

  @override
  State<MushafDisplay> createState() => _MushafDisplayState();
}

class _MushafDisplayState extends State<MushafDisplay> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final controller = context.read<SttController>();
    _pageController = PageController(
      initialPage: controller.currentPage - 1,
    );
    context.read<SttController>().addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (!mounted) return;
    final controller = context.read<SttController>();
    if (_pageController.hasClients) {
      final currentViewPage = _pageController.page?.round() ?? 0;
      if (currentViewPage != controller.currentPage - 1) {
        _pageController.animateToPage(
          controller.currentPage - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      context.read<SttController>().removeListener(_handleControllerChange);
    } catch (_) {}
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();

    return Directionality(
      textDirection: TextDirection.rtl, // ✅ FIX RTL: Kanan ke Kiri
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // 🚀 DEFERRED NAVIGATION: Only update state when scrolling is finished
          // This prevents the AppBar and surrounding UI from rebuilding mid-swipe.
          if (notification is ScrollEndNotification) {
            final pageValue = _pageController.page?.round() ?? 0;
            final newPage = pageValue + 1;
            if (newPage != controller.currentPage) {
              controller.navigateToPage(newPage);
            }
          }
          return false;
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: controller.totalPages,
          // onPageChanged is too "early" and causes jank. 
          // We use the NotificationListener above instead.
          onPageChanged: null, 
          itemBuilder: (context, index) {
            // 🚀 ULTRA-PURE OPTIMIZATION: Build the page content ONCE
            final Widget pageContent = CachedMushafPage(
              key: ValueKey('cached_page_${index + 1}_${controller.mushafLayout.name}'),
              pageNumber: index + 1,
              layout: controller.mushafLayout,
              builder: () => Builder(
                builder: (innerC) => _buildMushafPageOptimized(innerC, index + 1),
              ),
            );

            // Listen to page scroll but skip rebuild of pageContent
            return AnimatedBuilder(
              animation: _pageController,
              child: pageContent, // ✅ PASS STABLE CHILD: This is never rebuilt during swipe!
              builder: (context, staticChild) {
                final double pageValue = _pageController.hasClients 
                    ? (_pageController.page ?? 0.0) 
                    : (controller.currentPage - 1).toDouble();
                    
                final double position = index - pageValue;
                
                // Only build active pages for performance
                if (position < -2.0 || position > 2.0) {
                  return const SizedBox.shrink();
                }

                return _BookFoldTransformer(
                  position: position,
                  child: staticChild!, // ✅ USE STABLE CHILD
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ✅ Keep helper methods
  static final Set<int> _emergencyLoadingPages = {};

  Widget _buildMushafPageOptimized(BuildContext context, int pageNumber) {
    //  ✅ OPTIMIZATION: Use granular selects for cache
    var cachedLines = context.select<SttController, List<MushafPageLine>?>((c) => c.pageCache[pageNumber]);
    final controller = context.read<SttController>(); 

    if (cachedLines == null || cachedLines.isEmpty) {
      final service = context.read<QuranService>();
      final serviceCache = service.getCachedPage(pageNumber);
      if (serviceCache != null && serviceCache.isNotEmpty) {
        controller.updatePageCache(pageNumber, serviceCache);
        cachedLines = serviceCache;
      }
    }

    if (cachedLines != null && cachedLines.isNotEmpty) {
      return MushafPageContent(
        key: ValueKey('page_$pageNumber'), // ✅ Add Key to force refresh if needed
        pageLines: cachedLines,
        pageNumber: pageNumber,
      );
    }

    if (!_emergencyLoadingPages.contains(pageNumber)) {
      final service = context.read<QuranService>();
      if (service.isPageLoading(pageNumber)) {
         // Wait silently
      } else {
        _emergencyLoadingPages.add(pageNumber);
        Future.microtask(() async {
          try {
            final lines = await service.getMushafPageLines(pageNumber);
            controller.updatePageCache(pageNumber, lines);
          } catch (e) {
            print('Emergency load failed: $e');
          } finally {
            _emergencyLoadingPages.remove(pageNumber);
          }
        });
      }
    }

    return SizedBox(
      height: MushafRenderer.pageHeight(context),
      child: Center(
        child: SizedBox(
           width: 30, height: 30,
           child: CircularProgressIndicator(color: AppColors.getTextTertiary(context)),
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
    // ✅ Highlighting Consolidated: Use a single Stack with one overlay for the entire page
    return Column(
      children: [
        // Header tanpa padding horizontal
        Padding(
          padding: EdgeInsets.only(top: appBarHeight),
          child: MushafPageHeader(pageNumber: pageNumber),
        ),

        // ✅ KHUSUS HALAMAN 1 & 2: Tambahkan ruang kosong di atas Surah Header
        if (isSpecialPage)
          SizedBox(height: screenHeight * 0.15),

        const SizedBox(height: 0),

        // Page lines
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.00,
          ),
          child: linesContent,
        ),
      ],
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

    final isIndopakFontSize = context.select<SttController, bool>((c) => c.mushafLayout == MushafLayout.indopak);

    return Container(
      height: MushafRenderer.lineHeight(context),
      alignment: Alignment.center,
      child: Text(
        '﷽',
        style: TextStyle(
          fontSize: isIndopakFontSize ? basmallahSize * 0.85 : basmallahSize,
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
    final hideUnreadAyat = context.select<SttController, bool>((c) => c.hideUnreadAyat);

    // Select ONLY the word status for the current active highlight if it belongs to this line
    final lineAyahKeys = line.ayahSegments?.map((s) => '${s.surahId}:${s.ayahNumber}').toSet() ?? {};

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

    // ✅ Use Calculated Font Size
    final baseFontSize = layoutConfig.fontSize;
    final lastWordFontMultiplier = 0.850;

    if (line.ayahSegments == null || line.ayahSegments!.isEmpty) {
      return SizedBox(height: MushafRenderer.lineHeight(context));
    }

    List<InlineSpan> spans = [];

    final fontFamily = mushafLayout.isGlyphBased
        ? 'p$pageNumber' // QPC: p1, p2, p3, etc.
        : 'IndoPak-Nastaleeq'; // IndoPak: single font for all pages

    final wordStatusMap = controller.wordStatusMap;

    // ✅ CRITICAL: Ensure segments are sorted by reading order (Surah/Ayah)
    final sortedSegments = List<AyahSegment>.from(line.ayahSegments ?? []);
    sortedSegments.sort((a, b) {
      if (a.surahId != b.surahId) return a.surahId.compareTo(b.surahId);
      return a.ayahNumber.compareTo(b.ayahNumber);
    });

    for (final segment in sortedSegments) {
      final ayatIndex = controller.ayatList.indexWhere(
        (a) => a.surah_id == segment.surahId && a.ayah == segment.ayahNumber,
      );
      final isCurrentAyat =
          ayatIndex >= 0 && ayatIndex == currentAyatIndex;

      for (int i = 0; i < segment.words.length; i++) {
        final word = segment.words[i];
        final wordIndex = word.wordNumber - 1;

        final wordStatusKey = '${segment.surahId}:${segment.ayahNumber}';
        final wordStatus = wordStatusMap[wordStatusKey]?[wordIndex];

        Color wordBg = Colors.transparent;
        double wordOpacity = 1.0;

        final isLastWordInAyah =
            segment.isEndOfAyah && i == (segment.words.length - 1);

        // Highlight logic
        if (wordStatus != null) {
          switch (wordStatus) {
            case WordStatus.matched:
            case WordStatus.correct:
              wordBg = getCorrectColor(context).withValues(alpha: 0.6);
              break;
            case WordStatus.mismatched:
            case WordStatus.incorrect:
            case WordStatus.skipped:
              wordBg = getErrorColor(context).withValues(alpha: 0.6);
              break;
            case WordStatus.processing:
              if (isRecording || isListeningMode) {
                wordBg = AppColors.getInfo(context).withValues(alpha: 0.6);
              }
              break;
            default: break;
          }
        }

        final hasActiveHighlight = wordStatusMap[wordStatusKey]?.values
            .any((s) => s == WordStatus.processing) ?? false;

        if (isCurrentAyat && 
            wordBg == Colors.transparent && 
            hasActiveHighlight &&
            (isListeningMode || isRecording)) {
          wordBg = AppColors.getPrimary(context).withValues(alpha: 0.1);
        }

        // Opacity logic
        if (hideUnreadAyat) {
          if (wordStatus != null && wordStatus != WordStatus.pending) {
            wordOpacity = 1.0;
          } else {
            wordOpacity = (isLastWordInAyah) ? 1.0 : 0.0;
          }
        }

        final isLastWord = isLastWordInAyah;
        final effectiveFontSize = isLastWord
            ? baseFontSize * lastWordFontMultiplier
            : baseFontSize;

        // ✅ FORCE INDOPAK STYLE FOR AYAH MARKER WITH STACK
        if (isLastWord) {
             spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  width: effectiveFontSize * 1.2,
                  height: effectiveFontSize,
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 1. Lingkaran (Ayah End Marker)
                      Transform.translate(
                        offset: Offset(0, -effectiveFontSize * 0.15),
                        child: Transform.scale(
                          scale: (pageNumber == 1 || pageNumber == 2) ? 1.6 : 1.9,
                          child: Text(
                            '\u06DD', 
                            style: TextStyle(
                              fontSize: effectiveFontSize,
                              fontFamily: 'IndoPak-Nastaleeq',
                              color: AppColors.getAyahNumber(context).withValues(alpha: wordOpacity),
                              height: 0.1,
                            ),
                            textDirection: TextDirection.rtl,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),

                      // 2. Nomor Ayat (Centered inside ornament)
                      Center(
                         child: Text(
                          LanguageHelper.toIndoPakDigits(segment.ayahNumber),
                          style: TextStyle(
                            fontSize: effectiveFontSize * 0.55,
                            fontFamily: 'Quran-Common',
                            color: AppColors.getAyahNumber(context).withValues(alpha: wordOpacity),
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
        } else {
             // Normal text word
             spans.add(
              TextSpan(
                text: word.text,
                style: TextStyle(
                  fontSize: effectiveFontSize,
                  fontFamily: fontFamily,
                  color: _getWordColor(isCurrentAyat, context).withValues(alpha: wordOpacity),
                  backgroundColor: wordBg,
                  fontWeight: FontWeight.normal,
                  height: (pageNumber == 1 || pageNumber == 2)
                      ? 1.5
                      : (isIndopak ? 1.6 : 1.8),
                ),
              ),
            );
        }
      }
    }

    // ✅ Build stack with highlights
    return Stack(
      children: [
        RepaintBoundary(
          key: ValueKey('static_line_${pageNumber}_${line.lineNumber}'),
          child: MushafRenderer.renderJustifiedLine(
            wordSpans: spans,
            isCentered: line.isCentered,
            availableWidth: layoutConfig.availableWidth,
            context: context,
            allowOverflow: false,
            customLineHeight: layoutConfig.lineHeight,
            useFittedBox: layoutConfig.useFittedBox,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: _WordHighlightOverlay(
              line: line,
              pageNumber: pageNumber,
              layoutConfig: layoutConfig,
            ),
          ),
        ),
      ],
    );
  }
}


/// ✅ Per-Line Highlighting Overlay (Restored)
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
    if (line.ayahSegments == null) return const SizedBox.shrink();

    final lineAyahKeys = line.ayahSegments!.map((s) => '${s.surahId}:${s.ayahNumber}').toSet();
    
    // Listen to highlight state only if it affects this line
    final highlightData = context.select<SttController, String?>((c) {
      if (c.currentHighlightKey == null || !lineAyahKeys.contains(c.currentHighlightKey)) {
        return null;
      }
      return '${c.currentHighlightKey}:${c.currentHighlightWordIdx}';
    });

    // Hash of statuses on THIS line for efficient rebuilds
    final statusHash = context.select<SttController, int>((c) {
      int hash = 0;
      for (final segment in line.ayahSegments!) {
        final status = c.wordStatusMap[segment.verseKey];
        if (status != null) hash ^= status.hashCode;
      }
      return hash;
    });

    final controller = context.read<SttController>();
    
    return CustomPaint(
      painter: _WordHighlightPainter(
        line: line,
        pageNumber: pageNumber,
        controller: controller,
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
  final Color correctColor;
  final Color incorrectColor;
  final Color infoColor;
  final Color primaryColor;

  _WordHighlightPainter({
    required this.line,
    required this.pageNumber,
    required this.controller,
    required this.correctColor,
    required this.incorrectColor,
    required this.infoColor,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = controller.geometryCache[pageNumber];
    if (geometry == null || line.ayahSegments == null) return;

    final wordStatusMap = controller.wordStatusMap;
    final highlightKey = controller.currentHighlightKey;
    final highlightWordIdx = controller.currentHighlightWordIdx;
    final paint = Paint();

    for (final segment in line.ayahSegments!) {
      final key = segment.verseKey;
      final statuses = wordStatusMap[key];
      if (statuses == null && key != highlightKey) continue;

      for (final word in segment.words) {
        final wordIdx = word.wordNumber - 1;
        final status = statuses?[wordIdx];
        
        Color? highlightColor;
        if (status != null && status != WordStatus.pending) {
          highlightColor = _getHighlightColor(status);
        } else if (key == highlightKey && highlightWordIdx == wordIdx) {
          highlightColor = primaryColor;
        }

        if (highlightColor != null) {
          final geometryKey = PageGeometry.getWordKey(segment.surahId, segment.ayahNumber, word.wordNumber);
          final rects = geometry.wordBounds[geometryKey];

          if (rects != null) {
            paint.color = highlightColor;
            for (final rect in rects) {
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

  Color _getHighlightColor(WordStatus status) {
    switch (status) {
      case WordStatus.matched:
      case WordStatus.correct: return correctColor;
      case WordStatus.mismatched:
      case WordStatus.incorrect:
      case WordStatus.skipped: return incorrectColor;
      case WordStatus.processing: return infoColor;
      default: return Colors.transparent;
    }
  }

  @override
  bool shouldRepaint(covariant _WordHighlightPainter oldDelegate) => true;
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
  final int pageNumber; // ✅ ACCEPT PAGE NUMBER
  const MushafPageHeader({super.key, required this.pageNumber});

  @override
  State<MushafPageHeader> createState() => _MushafPageHeaderState();
}

class _MushafPageHeaderState extends State<MushafPageHeader> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('stt');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
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

    // ✅ OPTIMIZATION: Only listen to layout changes, NOT page changes
    final mushafLayout = context.select<SttController, MushafLayout>((c) => c.mushafLayout);
    final isIndopak = mushafLayout == MushafLayout.indopak;

    final controller = context.read<SttController>(); 
    final headerFontSize = screenWidth * 0.035;
    final headerHeight = screenHeight * 0.035;
    final juzText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'mushaf_view.juz_text')
        : 'Juz';

    // ✅ CALCULATE JUZ FOR *THIS* PAGE
    // Estimation logic: 20 pages per juz.
    // Juz = ((pageNumber - 1) / 20).floor() + 1
    // This is instant and doesn't require waiting for controller state
    final juzNumber = ((widget.pageNumber - 1) / 20).floor() + 1;

    return Container(
      height: headerHeight,
      // ✅ FIX: Hapus background color sama sekali
      padding: EdgeInsets.symmetric(
        horizontal: isIndopak
            ? screenWidth *
                  0.035 // indopak
            : screenWidth * 0.010, // qpc,
      ), 
      alignment: Alignment.center,
      child: Row(
        textDirection: TextDirection.rtl, // ✅ RTL layout
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // RIGHT side in RTL
          Text(
            '${context.formatNumber(widget.pageNumber)}', // ✅ Page number on RIGHT
            style: TextStyle(
              fontSize: headerFontSize,
              color: AppColors.getTextPrimary(context).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          // LEFT side in RTL
          Text(
            '$juzText ${context.formatNumber(juzNumber)}', // ✅ Juz on LEFT
            style: TextStyle(
              fontSize: headerFontSize,
              color: AppColors.getTextPrimary(context).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

/// ✅ CUSTOM TRANSFORMER: Memberikan efek "Spacing Sendiri" & "Spine Shadow"
/// Tanpa package, lebih stabil dan terkontrol performanya.
class _BookFoldTransformer extends StatelessWidget {
  final double position;
  final Widget child;

  const _BookFoldTransformer({
    required this.position,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double absPosition = position.abs();
    
    // 🚀 2D OPTIMIZED TRANSFORM: Simulation of fold using 2D math
    // Faster for mid-range GPUs (like Redmi Note 12) than 3D matrices.
    
    // 1. Horizontal "Squeeze" (Simulates turning away)
    // ScaleX from 1.0 (straight) to 0.85 (folded)
    final double scaleX = 1.0 - (absPosition * 0.15);
    
    // 2. Subtle Verticall "Skew" (Simulates perspective tilt)
    // Very cheap 2D tilt
    final double skewY = position * 0.05;

    final Matrix4 transform = Matrix4.identity()
      ..scale(scaleX, 1.0);
    
    // Simulating skewY without the undefined method
    transform.setEntry(1, 0, skewY); 

    // 3. Dynamic Crease Shadow
    final double dimAmount = absPosition.clamp(0.0, 0.45);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0), // ✅ Wider white gap
      child: Transform(
        transform: transform,
        // RTL Logic for Spine Alignment
        alignment: position < 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: child, // ✅ Removed gutter shadow
      ),
    );
  }
}

class _GutterShadowPainter extends CustomPainter {
  final double dimAmount;
  final bool isRightPage;
  final bool isFixed;

  _GutterShadowPainter({
    required this.dimAmount,
    required this.isRightPage,
    this.isFixed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dimAmount <= 0) return;
    
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: isRightPage ? Alignment.centerLeft : Alignment.centerRight,
        end: isRightPage ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          Colors.black.withOpacity(isFixed ? 0.3 * dimAmount : 0.8 * dimAmount),
          Colors.transparent,
        ],
        stops: isFixed ? const [0.0, 0.05] : const [0.0, 0.25],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _GutterShadowPainter oldDelegate) {
    return oldDelegate.dimAmount != dimAmount || oldDelegate.isRightPage != isRightPage;
  }
}



