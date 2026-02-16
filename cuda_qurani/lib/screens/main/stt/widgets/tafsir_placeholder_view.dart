import 'package:cuda_qurani/services/global_ayat_services.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/tafsir_download.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/translation_download.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/screens/main/stt/data/models.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
import 'package:provider/provider.dart';

class TafsirPlaceholderView extends StatefulWidget {
  final AyahSegment segment;
  final String surahName;

  const TafsirPlaceholderView({
    super.key,
    required this.segment,
    required this.surahName,
  });

  @override
  State<TafsirPlaceholderView> createState() => _TafsirPlaceholderViewState();
}

class _TafsirPlaceholderViewState extends State<TafsirPlaceholderView> {
  late int _currentSurahId;
  late int _currentAyahNumber;
  late String _currentSurahName;

  @override
  void initState() {
    super.initState();
    _currentSurahId = widget.segment.surahId;
    _currentAyahNumber = widget.segment.ayahNumber;
    _currentSurahName = widget.surahName;
  }

  void _navigateToAyah(
    SttController controller,
    int surahId,
    int ayahNumber,
  ) async {
    String surahName = _currentSurahName;

    // If surah changed, fetch new surah name
    if (surahId != _currentSurahId) {
      final quranService = Provider.of<QuranService>(context, listen: false);
      try {
        final chapter = await quranService.getChapterInfo(surahId);
        surahName = chapter.nameSimple;
      } catch (e) {
        print('Error fetching surah name: $e');
      }
    }

    setState(() {
      _currentSurahId = surahId;
      _currentAyahNumber = ayahNumber;
      _currentSurahName = surahName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    // Try to get controller, but don't fail if not available
    SttController? controller;
    try {
      controller = Provider.of<SttController>(context, listen: false);
    } catch (e) {
      controller = null;
    }

    // Try to get QuranService, but don't fail if not available
    QuranService? quranService;
    try {
      quranService = Provider.of<QuranService>(context, listen: false);
    } catch (e) {
      quranService = null;
    }

    final resourceService = Provider.of<QuranResourceService>(context);
    final sourceName = resourceService.selectedTafsirName ?? 'Tafsir';

    // ✅ FIX: Use Text-based fonts for Unicode text rendering
    // If layout is QPC (Glyph-based), use standard KFGQPC Text font
    // If layout is IndoPak, use IndoPak font
    final isGlyphBased = controller?.mushafLayout.isGlyphBased ?? false;
    final fontFamily = isGlyphBased
        ? 'KFGQPCUthmanicScriptHAFSRegular'
        : 'IndoPak-Nastaleeq';

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.getTextSecondary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.getBorderLight(context)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$_currentSurahName - Verse $_currentAyahNumber',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                // Arabic Content
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: FutureBuilder<List<dynamic>>(
                      future: quranService == null
                          ? Future.value(<dynamic>[])
                          : Future.wait([
                              quranService.getAyahWords(
                                _currentSurahId,
                                _currentAyahNumber,
                              ),
                              quranService.getPageForAyah(
                                _currentSurahId,
                                _currentAyahNumber,
                              ),
                            ]),
                      builder: (context, snapshot) {
                        if (snapshot.hasError ||
                            (snapshot.connectionState == ConnectionState.done &&
                                !snapshot.hasData &&
                                quranService == null)) {
                          return Center(
                            child: Text(
                              quranService == null
                                  ? 'Quran Service not found. Please restart app.'
                                  : 'Error loading ayah: ${snapshot.error}',
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final ayahWords = snapshot.data![0] as List<WordData>;
                        final pageNumber = snapshot.data![1] as int;

                        // ✅ FIX: Use correct font based on layout and page number
                        // If layout is QPC (Glyph-based), use p{pageNumber}
                        // If layout is IndoPak, use IndoPak-Nastaleeq
                        final isGlyphBased =
                            controller?.mushafLayout.isGlyphBased ?? false;
                        final fontFamily = isGlyphBased
                            ? 'p$pageNumber'
                            : 'IndoPak-Nastaleeq';

                        return _buildMushafStyleAyah(
                          context,
                          ayahWords,
                          _currentAyahNumber,
                          fontFamily,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tafsir Content + Group Info Banner
                FutureBuilder<String?>(
                  future: resourceService.getTafsirText(
                    _currentSurahId,
                    _currentAyahNumber,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(
                              color: AppColors.getError(context),
                            ),
                          ),
                        ),
                      );
                    }

                    final content = snapshot.data;

                    if (content == null) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _buildDownloadPrompt(context);
                    }

                    // Parse natural group info if present
                    String? groupRange;
                    String cleanData = content;
                    if (content.startsWith('GROUP_INFO|')) {
                      final parts = content.split('|');
                      if (parts.length >= 3) {
                        groupRange = parts[1];
                        cleanData = parts.sublist(2).join('|');
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Info Banner (Restored and Styled)
                        if (groupRange != null)
                          _buildGroupBanner(context, groupRange),

                        const SizedBox(height: 12),

                        RichText(
                          textAlign:
                              resourceService.selectedTafsirLanguage ==
                                      'العربية' ||
                                  resourceService.selectedTafsirLanguage ==
                                      'اردو' ||
                                  resourceService.selectedTafsirLanguage ==
                                      'فارسی'
                              ? TextAlign.justify
                              : TextAlign.left,
                          textDirection:
                              resourceService.selectedTafsirLanguage ==
                                      'العربية' ||
                                  resourceService.selectedTafsirLanguage ==
                                      'اردو' ||
                                  resourceService.selectedTafsirLanguage ==
                                      'فارسی'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          text: TextSpan(
                            children: _parseHtmlToSpans(
                              context,
                              _cleanContent(cleanData, _currentAyahNumber),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.getPrimary(
                                  context,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sourceName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                _buildTafsirSettingsCard(context),
              ],
            ),
          ),

          // Bottom Navigation
          if (controller != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                border: Border(
                  top: BorderSide(
                    color: AppColors.getBorderLight(context).withOpacity(0.5),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNavButton(
                        context,
                        label: 'Next',
                        icon: Icons.chevron_left,
                        isLeft: true, // Next on the left (RTL flow)
                        onTap: () {
                          // Global navigation using GlobalAyatService
                          final globalIndex = GlobalAyatService.toGlobalAyat(
                            _currentSurahId,
                            _currentAyahNumber,
                          );
                          if (GlobalAyatService.isValid(globalIndex + 1)) {
                            final nextData = GlobalAyatService.fromGlobalAyat(
                              globalIndex + 1,
                            );
                            final nextSurah = nextData['surah_id']!;
                            final nextAyah = nextData['ayah_number']!;

                            _navigateToAyah(controller!, nextSurah, nextAyah);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reached the end of Al-Quran'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNavButton(
                        context,
                        label: 'Previous',
                        icon: Icons.chevron_right,
                        isLeft: false, // Previous on the right (RTL flow)
                        onTap: () {
                          // Global navigation using GlobalAyatService
                          final globalIndex = GlobalAyatService.toGlobalAyat(
                            _currentSurahId,
                            _currentAyahNumber,
                          );
                          if (GlobalAyatService.isValid(globalIndex - 1)) {
                            final prevData = GlobalAyatService.fromGlobalAyat(
                              globalIndex - 1,
                            );
                            final prevSurah = prevData['surah_id']!;
                            final prevAyah = prevData['ayah_number']!;

                            _navigateToAyah(controller!, prevSurah, prevAyah);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('First verse of Al-Fatihah'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isLeft,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.getBorderLight(context).withOpacity(0.5),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLeft)
                  Icon(
                    icon,
                    color: AppColors.getTextPrimary(context).withOpacity(0.7),
                    size: 22,
                  ),
                if (isLeft) const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context).withOpacity(0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                if (!isLeft) const SizedBox(width: 8),
                if (!isLeft)
                  Icon(
                    icon,
                    color: AppColors.getTextPrimary(context).withOpacity(0.7),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTafsirSettingsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderLight(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select different tafsir sources for deep understanding',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tafsir Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.getTextSecondary(context),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TafsirDownloadPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationSettingsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderLight(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add additional translations for comparative study',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Translation Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.getTextSecondary(context),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TranslationDownloadPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 48,
            color: AppColors.getTextSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Tafsir not downloaded',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TafsirDownloadPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimary(context),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  /// Helper function to render ayah text with mushaf-style formatting (NO numbering)
  Widget _buildMushafStyleAyah(
    BuildContext context,
    List<WordData> words,
    int ayahNumber,
    String fontFamily,
  ) {
    if (words.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    // Strip all Quranic markers/digits/ornaments for clean text rendering in detail view
    // Aggressive list to catch all possible ornaments
    final markerStripper = RegExp(
      r'[\u0660-\u0669\u06F0-\u06F90-9\u06DD\uFD3E\uFD3F\u06D4\u066B\u066C\u0600-\u060F\(\)\[\]\{\}۝۞۩]',
    );

    // ✅ FIX: Strip "Bismillah" from Method Text if present in first ayah of non-Fatihah
    // Bismillah usually appears as the first 4 words in some digital Mushaf data
    // Word 1: Bismi, 2: Allah, 3: Ar-Rahman, 4: Ar-Rahim
    int startIndex = 0;
    if (ayahNumber == 1 && _currentSurahId != 1 && words.length > 4) {
      final firstWord = words[0].text.replaceAll(markerStripper, '').trim();
      if (firstWord.startsWith('بِسْمِ') || firstWord.startsWith('بسم')) {
        startIndex = 4; // Skip first 4 words (Bismillah)
      }
    }

    // Categorically skip the last word in detail views as it always contains the Ayah marker
    // as per user instruction: "lastword jangan ditampilkan"
    int limit = words.length > 1 ? words.length - 1 : words.length;

    for (int i = startIndex; i < limit; i++) {
      final word = words[i];
      var cleanText = word.text.replaceAll(markerStripper, '').trim();

      if (cleanText.isEmpty) continue;

      spans.add(
        TextSpan(
          text: cleanText + (i < limit - 1 ? ' ' : ''),
          style: TextStyle(
            fontSize: 28, // Reduced from 34 as requested
            fontFamily: fontFamily,
            color: AppColors.getTextPrimary(context),
            height: 1.5, // More compact line height matching screenshot
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      child: RichText(
        textAlign: TextAlign.right, // RTL usually aligns to the right
        textDirection: TextDirection.rtl,
        text: TextSpan(children: spans),
      ),
    );
  }

  String _cleanContent(String raw, int ayahNumber) {
    if (raw.isEmpty) return raw;

    String cleaned = raw;

    // 0. Remove the lengthy preamble from the main scrolling area
    cleaned = cleaned.replaceAll(
      RegExp(
        r'You are reading a tafsir of a group of verses from \d+:\d+ to \d+:\d+',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'Anda sedang membaca tafsir kelompok ayat dari \d+:\d+ sampai \d+:\d+',
        caseSensitive: false,
      ),
      '',
    );

    // Maintain markers like (1) or 1. as "checkpoints" as requested by user
    // But clean up redundant leading "1:1 -" style prefixes
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+:\d+\s*[-]?\s*'), '');

    // 1. Strip references usually at the end or in middle
    // e.g. (Al-Fatihah: 1-7)
    cleaned = cleaned.replaceAll(
      RegExp(r'[\(\[（][^:\]\)]+:\s*\d+[-\d]*[\)\]）]'),
      '',
    );

    // 2. Housekeeping for HTML entities
    cleaned = cleaned.replaceAll('&nbsp;', ' ');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&rsquo;', "'");
    cleaned = cleaned.replaceAll('&lsquo;', "'");

    // Keep some HTML tags for rich rendering but clean up surrounding whitespace
    cleaned = cleaned.replaceAll(RegExp(r'>\s+<'), '><');

    // 3. Collapse multiple spaces created by DB formatting
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');

    return cleaned.trim();
  }

  Widget _buildGroupBanner(BuildContext context, String rangeText) {
    final isIndo = rangeText.toLowerCase().contains('sampai');
    final message = isIndo
        ? 'Tafsir kelompok $rangeText'
        : 'You are reading a tafsir of a group of $rangeText';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA), // Very light pale green
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34A853).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34A853).withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF137333),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF137333),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseHtmlToSpans(BuildContext context, String text) {
    final spans = <InlineSpan>[];

    // More robust stack-based parser for basic tags
    final regExp = RegExp(r'(<[^>]+>|[^<]+)');
    final matches = regExp.allMatches(text);

    final styleStack = <TextStyle>[
      TextStyle(
        fontSize: 16,
        color: AppColors.getTextPrimary(context),
        height: 1.6,
      ),
    ];

    for (final match in matches) {
      final part = match.group(0)!;

      if (part.startsWith('<')) {
        final tag = part.toLowerCase();
        if (tag == '<br>' || tag == '<br/>' || tag == '<br />') {
          spans.add(const TextSpan(text: '\n'));
        } else if (tag == '</p>' || tag == '</div>') {
          spans.add(const TextSpan(text: '\n\n'));
        } else if (tag == '<p>' || tag.startsWith('<div')) {
          // Just skip start p or div
        } else if (part.startsWith('<span')) {
          TextStyle currentStyle = styleStack.last;
          if (part.contains('class="green"') ||
              part.contains('class="ht green"')) {
            currentStyle = currentStyle.copyWith(
              color: const Color(0xFF2E7D32),
              fontWeight: FontWeight.w500,
            );
          } else if (part.contains('class="blue"')) {
            currentStyle = currentStyle.copyWith(
              color: const Color(0xFF1976D2),
              fontWeight: FontWeight.w500,
            );
          } else if (part.contains('class="brown"')) {
            currentStyle = currentStyle.copyWith(
              color: const Color(0xFF795548),
              fontWeight: FontWeight.w500,
            );
          } else if (part.contains('class="gray"')) {
            currentStyle = currentStyle.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            );
          } else if (part.contains('class="bolder"')) {
            currentStyle = currentStyle.copyWith(fontWeight: FontWeight.bold);
          }
          styleStack.add(currentStyle);
        } else if (part.startsWith('</span>')) {
          if (styleStack.length > 1) styleStack.removeLast();
        } else if (part.startsWith('<sup')) {
          styleStack.add(
            styleStack.last.copyWith(fontSize: 12, fontStyle: FontStyle.italic),
          );
        } else if (part.startsWith('</sup>')) {
          if (styleStack.length > 1) styleStack.removeLast();
        }
      } else {
        // Check for verse markers like (1) or [1] or ornate brackets ﴿ ﴾
        final markerRegex = RegExp(r'(\(\d+\)|\[\d+\]|\d+\.|[﴿﴾])');
        final parts = part.split(markerRegex);
        final markerMatches = markerRegex.allMatches(part).toList();

        for (int i = 0; i < parts.length; i++) {
          spans.add(TextSpan(text: parts[i], style: styleStack.last));
          if (i < markerMatches.length) {
            final matchText = markerMatches[i].group(0) ?? '';
            final isBracket = matchText == '﴿' || matchText == '﴾';

            spans.add(
              TextSpan(
                text: matchText,
                style: styleStack.last.copyWith(
                  color: isBracket
                      ? const Color(0xFF2E7D32)
                      : AppColors.getPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
        }
      }
    }

    return spans;
  }
}
