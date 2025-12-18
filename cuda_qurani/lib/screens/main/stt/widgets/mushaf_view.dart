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
    return MediaQuery.of(context).size.height * 0.050; // ~5.5% screen height
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
  }) {
    if (wordSpans.isEmpty) return const SizedBox.shrink();

    final lineH = lineHeight(context);

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
      ),
    );
  }

  static Widget _usText({
    required List<InlineSpan> wordSpans,
    required double maxWidth,
    bool allowOverflow = false,
    required BuildContext context,
  }) {
    if (wordSpans.isEmpty) return const SizedBox.shrink();

    final lineH = lineHeight(context);

    // Single word case
    if (wordSpans.length == 1) {
      return SizedBox(
        width: maxWidth,
        child: RichText(
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          text: TextSpan(
            children: [wordSpans.first],
          ), // ✅ UBAH: wrap dalam children
        ),
      );
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
    return SizedBox(
      width: maxWidth,
      height: lineH,
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
  }
}

class MushafDisplay extends StatefulWidget {
  const MushafDisplay({Key? key}) : super(key: key); // ✅ Already OK

  @override
  State<MushafDisplay> createState() => _MushafDisplayState();
}

class _MushafDisplayState extends State<MushafDisplay> {
  bool _isSwipeInProgress = false;
  double _dragStartPosition = 0;
  bool _isUpdating = false; // ✅ FIX: Prevent concurrent updates

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();

    return GestureDetector(
      behavior: HitTestBehavior
          .translucent, // ✅ FIX: Ganti dari opaque ke translucent
      onHorizontalDragStart: (details) {
        if (!mounted) return; // ✅ FIX: Check mounted state
        _dragStartPosition = details.globalPosition.dx;
        _isSwipeInProgress = false;
      },
      onHorizontalDragUpdate: (details) {
        if (!mounted) return; // ✅ FIX: Check mounted state
        // Detect significant horizontal movement
        final dragDistance = (details.globalPosition.dx - _dragStartPosition)
            .abs();
        if (dragDistance > 50 && !_isSwipeInProgress) {
          _isSwipeInProgress = true;
        }
      },
      onHorizontalDragEnd: (details) {
        if (!mounted || !_isSwipeInProgress)
          return; // ✅ FIX: Check mounted state

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
        // ✅ Fill entire screen for gesture detection
        child: SingleChildScrollView(
          // ✅ Allow scrolling if content exceeds screen
          physics:
              const NeverScrollableScrollPhysics(), // ✅ Disable scroll (only swipe)
          child: RepaintBoundary(
            // ✅ FIX: Isolate repaints to prevent MouseTracker conflicts
            child: _buildMushafPageOptimized(context),
          ),
        ),
      ),
    );
  }

  // ✅ CRITICAL: Track emergency loads to prevent duplicates
  static final Set<int> _emergencyLoadingPages = {};

  Widget _buildMushafPageOptimized(BuildContext context) {
    final controller = context.watch<SttController>();
    final pageNumber = controller.currentPage;
    var cachedLines = controller.pageCache[pageNumber];

    // ✅ CRITICAL: Also check QuranService cache (shared singleton)
    if (cachedLines == null || cachedLines.isEmpty) {
      final service = context.read<QuranService>();
      final serviceCache = service.getCachedPage(pageNumber);
      if (serviceCache != null && serviceCache.isNotEmpty) {
        // ✅ Sync cache immediately
        controller.updatePageCache(pageNumber, serviceCache);
        cachedLines = serviceCache;
      }
    }

    // ✅ FAST PATH: If page is cached, render immediately (NO LOADING)
    if (cachedLines != null && cachedLines.isNotEmpty) {
      // ✅ OPTIMIZED: Use RepaintBoundary to prevent unnecessary repaints
      return RepaintBoundary(
        key: ValueKey('mushaf_page_$pageNumber'),
        child: MushafPageContent(
          pageLines: cachedLines,
          pageNumber: pageNumber,
        ),
      );
    }

    // ⚠️ FALLBACK: Emergency load only if not already loading
    if (!_emergencyLoadingPages.contains(pageNumber)) {
      final service = context.read<QuranService>();

      // ✅ CRITICAL: Check if page is already being loaded in QuranService
      if (service.isPageLoading(pageNumber)) {
        // Wait for existing load instead of creating duplicate
        final loadingFuture = service.getLoadingFuture(pageNumber);
        if (loadingFuture != null) {
          loadingFuture
              .then((lines) {
                controller.updatePageCache(pageNumber, lines);
              })
              .catchError((e) {
                print('❌ Waiting for page $pageNumber load failed: $e');
              });
          // Show loading indicator while waiting
        }
      } else {
        // Only trigger new emergency load if not already loading
        _emergencyLoadingPages.add(pageNumber);
        print(
          '⚠️ CACHE MISS: Page $pageNumber not cached, emergency loading...',
        );

        // ✅ CRITICAL: Trigger emergency load and sync cache
        Future.microtask(() async {
          try {
            final lines = await service.getMushafPageLines(pageNumber);

            // ✅ CRITICAL: Sync cache to controller immediately
            controller.updatePageCache(pageNumber, lines);
          } catch (e) {
            print('❌ Emergency load failed: $e');
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

    return Padding(
      padding: EdgeInsets.only(
        top: appBarHeight,
        left: screenWidth * 0, // 1.5% (dari 0.010)
        right: screenWidth * 0, // 1.5% (dari 0.010)
      ),
      child: Column(
        children: [
          const MushafPageHeader(),
          const SizedBox(height: 0),
          ..._buildPageLines(),
        ],
      ),
    );
  }

  List<Widget> _buildPageLines() {
    return pageLines.map((line) => _buildMushafLine(line)).toList();
  }

  Widget _buildMushafLine(MushafPageLine line) {
    switch (line.lineType) {
      case 'surah_name':
        return _SurahNameLine(line: line);
      case 'basmallah':
        return _BasmallahLine();
      case 'ayah':
        return _JustifiedAyahLine(line: line, pageNumber: pageNumber);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SurahNameLine extends StatelessWidget {
  final MushafPageLine line;
  const _SurahNameLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerSize = screenHeight * 0.060;
    final surahNameSize = screenHeight * 0.050;
    final controller = context.read<SttController>();
    final surahGlyphCode = line.surahNumber != null
        ? controller.formatSurahIdForGlyph(line.surahNumber!)
        : '';
    return Container(
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'header',
            style: TextStyle(
              fontSize: headerSize - 1.5,
              fontFamily: 'Quran-Common',
              color: AppColors.getTextPrimary(context),
              height: MediaQuery.of(context).size.height * 0.0010,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            surahGlyphCode,
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
  final int pageNumber; // TAMBAH ini

  const _JustifiedAyahLine({
    required this.line,
    required this.pageNumber, // TAMBAH ini
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final controller = context.watch<SttController>();
    final isIndopak = controller.mushafLayout == MushafLayout.indopak;

    // Font size berbeda untuk QPC vs IndoPak
    final fontSizeMultiplier = isIndopak
        ? 0.0610 // IndoPak: ukuran konsisten
        : ((pageNumber == 1 || pageNumber == 2)
              ? 0.080
              : 0.0690); // QPC: page 1-2 lebih besar

    final baseFontSize = screenWidth * fontSizeMultiplier;
    final lastWordFontMultiplier = 0.9;

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
          print(
            '🎨 UI RENDER: Ayah ${segment.surahId}:${segment.ayahNumber}, Word[$wordIndex] (loop $i) = $wordStatus',
          );
          print(
            '   Full wordStatusMap[$wordStatusKey] = ${controller.wordStatusMap[wordStatusKey]}',
          );
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
              wordBg = getCorrectColor(context).withValues(alpha: 0.4);
              break;
            case WordStatus.mismatched:
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
                height: isIndopak ? 1.9 : 1.8,
                // ✅ SOLUSI: Letterspace yang lebih negatif untuk "gepengin" text
                letterSpacing: isIndopak
                    ? -0.3 // ✅ Lebih negatif = lebih gepeng (coba -1.5 sampai -3.0)
                    : -5,
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

    // ✅ Build line widget
    final lineWidget = MushafRenderer.renderJustifiedLine(
      wordSpans: spans,
      isCentered: line.isCentered,
      availableWidth: MediaQuery.of(context).size.width,
      context: context,
      allowOverflow: false,
    );

    // ✅ Wrap dengan Transform untuk IndoPak
    if (isIndopak) {
      return Transform.scale(
        scaleX: 0.93, // Gepengin 10%
        alignment: Alignment.center,
        child: lineWidget,
      );
    }

    return lineWidget;
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
    final headerFontSize = screenWidth * 0.035;
    final headerHeight = screenHeight * 0.035;
    final juzText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'mushaf_view.juz_text')
        : 'Juz';

    final controller = context.watch<SttController>();
    final juzNumber = controller.currentPageAyats.isNotEmpty
        ? controller.calculateJuz(
            controller.currentPageAyats.first.surah_id,
            controller.currentPageAyats.first.ayah,
          )
        : 1;

    return Container(
      height: headerHeight,
      // ✅ FIX: Hapus background color sama sekali
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.030,
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
          // const SizedBox(width: 3),
          // Container(
          //   width: 1,
          //   height: screenHeight * 0.016,
          //   color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.3),
          // ),
          // Text(
          //   'Al-Ikhlas',
          //   style: TextStyle(
          //     fontSize: headerFontSize * 90 / 100,
          //     color: Colors.grey.shade700,
          //     fontWeight: FontWeight.w500,
          //   ),
          //   textDirection: TextDirection.rtl,
          // ),
          // Container(
          //   width: 1,
          //   height: screenHeight * 0.016,
          //   color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.3),
          // ),
          // Text(
          //   'Al-Falaq',
          //   style: TextStyle(
          //     fontSize: headerFontSize * 90 / 100,
          //     color: Colors.grey.shade700,
          //     fontWeight: FontWeight.w500,
          //   ),
          //   textDirection: TextDirection.rtl,
          // ),
          // Container(
          //   width: 1,
          //   height: screenHeight * 0.016,
          //   color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.3),
          // ),
          // Text(
          //   'An-Nas',
          //   style: TextStyle(
          //     fontSize: headerFontSize * 90 / 100,
          //     color: Colors.grey.shade700,
          //     fontWeight: FontWeight.w500,
          //   ),
          //   textDirection: TextDirection.rtl,
          // ),
          // Container(
          //   width: 1,
          //   height: screenHeight * 0.016,
          //   color: const Color.fromARGB(255, 0, 0, 0).withOpaque(0.3),
          // ),
          // const SizedBox(width: 3),
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
