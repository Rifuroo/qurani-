import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart';
import 'package:cuda_qurani/core/navigation/app_navigation_service.dart';
import '../../domain/entities/similarity_result.dart';
import '../controllers/phrase_similarity_controller.dart';
import '../pages/phrase_detail_page.dart';

class AyahSimilarityCard extends StatelessWidget {
  final SimilarVerse verse;
  final bool isCurrentSelected;

  const AyahSimilarityCard({
    super.key,
    required this.verse,
    this.isCurrentSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrentSelected
              ? AppColors.getPrimary(context)
              : AppColors.getBorderLight(context).withOpacity(0.6),
          width: isCurrentSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          AppNavigationService.exitFlowAndJumpToAyah(
            context,
            surahId: verse.surahId,
            ayahNumber: verse.ayahNumber,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: [Surah:Ayah] and Surah Name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.getBorderLight(context),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${verse.surahId}:${verse.ayahNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(
                              context,
                            ).withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        verse.surahName ?? 'Surah',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Arabic Text
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildArabicText(context),
                  ),
                  if (verse.transliteration != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      verse.transliteration!,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppColors.getTextSecondary(
                          context,
                        ).withOpacity(0.9),
                      ),
                    ),
                  ],
                  if (verse.transliteration != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      verse.transliteration!,
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: AppColors.getTextPrimary(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (verse.translation != null) ...[
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        children: _parseHtmlToSpans(
                          context,
                          verse.translation!,
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.getTextPrimary(context),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            // Footer: Continue Reading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue Reading',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.menu_book_outlined,
                        size: 20,
                        color: AppColors.getTextPrimary(
                          context,
                        ).withOpacity(0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArabicText(BuildContext context) {
    final text = verse.verseText;
    final highlight = verse.matchingPhrase;

    if (highlight == null || highlight.isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 24,
          fontFamily: 'UthmanTN',
          height: 1.8,
        ),
      );
    }

    // ✅ Robust Diacritic-Insensitive Highlighting
    // We create a regex that matches the phrase while ignoring harakat (vowels)
    try {
      // 1. Define harakat range (common Arabic marks)
      const String harakat =
          '[\u0610-\u061A\u064B-\u065F\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u0670]';

      // 2. Escape the search phrase and insert 'harakat*' between every character
      // Also allow optional whitespace between words if highlight contains spaces
      String pattern = '';
      for (int i = 0; i < highlight.length; i++) {
        final char = highlight[i];
        if (RegExp(harakat).hasMatch(char))
          continue; // skip harakat in search phrase

        if (RegExp(r'\s').hasMatch(char)) {
          pattern += r'\s+'; // allow one or more whitespace
        } else {
          pattern += RegExp.escape(char) + harakat + '*';
        }
      }

      final regex = RegExp(pattern, caseSensitive: false);
      final matches = regex.allMatches(text);

      if (matches.isEmpty) {
        return Text(
          text,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 28,
            fontFamily: 'UthmanTN',
            height: 1.8,
          ),
        );
      }

      final spans = <TextSpan>[];
      int lastMatchEnd = 0;

      for (final match in matches) {
        // Text before match
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
        }
        // Highlighted match
        spans.add(
          TextSpan(
            text: text.substring(match.start, match.end),
            style: const TextStyle(
              color: Color(0xFF34A853), // ✅ Ijo Cerah (Islamic Green)
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        lastMatchEnd = match.end;
      }

      // Remaining text
      if (lastMatchEnd < text.length) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd)));
      }

      return RichText(
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        text: TextSpan(
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'UthmanTN',
            height: 1.8,
            color: AppColors.getTextPrimary(context),
          ),
          children: spans,
        ),
      );
    } catch (e) {
      debugPrint('Highlighting error: $e');
      return Text(
        text,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 28,
          fontFamily: 'UthmanTN',
          height: 1.8,
        ),
      );
    }
  }

  /// ✅ Simple HTML Parser for translation Footnotes
  List<InlineSpan> _parseHtmlToSpans(BuildContext context, String text) {
    if (!text.contains('<')) {
      return [TextSpan(text: text)];
    }

    final spans = <InlineSpan>[];
    final regExp = RegExp(r'(<[^>]+>|[^<]+)');
    final matches = regExp.allMatches(text);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<')) {
        final tag = part.toLowerCase();
        if (tag.startsWith('<sup')) {
          // Footnote indicator style
          continue; // Skip the open tag
        } else if (tag == '</sup>') {
          continue; // Skip close tag
        } else if (tag == '<br>' || tag == '<br/>' || tag == '<br />') {
          spans.add(const TextSpan(text: '\n'));
        }
      } else {
        // Text content
        // If it's a footnote number inside <sup>, style it specially
        // For simplicity, we just strip or style lightly
        spans.add(TextSpan(text: part));
      }
    }

    // Fallback: If parsing resulted in nothing, return the original text stripped of tags
    if (spans.isEmpty) {
      return [TextSpan(text: text.replaceAll(RegExp(r'<[^>]*>'), ''))];
    }

    return spans;
  }
}

class PhraseSimilarityCard extends StatelessWidget {
  final SimilarPhrase phrase;

  const PhraseSimilarityCard({super.key, required this.phrase});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: AppColors.getBorderLight(context).withOpacity(0.4),
        ),
      ),
      child: InkWell(
        onTap: () {
          // Drill down to occurrences
          final controller = context.read<PhraseSimilarityController>();
          final sttController = context.read<SttController>();
          final quranService = context.read<QuranService>();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: sttController),
                  Provider.value(value: quranService),
                ],
                child: PhraseDetailPage(
                  phrase: phrase,
                  surahId: controller.surahId,
                  ayahNumber: controller.ayahNumber,
                  surahName: controller.surahName,
                  repository: controller.repository,
                  sttController: sttController,
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  phrase.text,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 24,
                    fontFamily: 'UthmanTN',
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'The phrase appears ${phrase.totalOccurrences} times in ${phrase.verseKeys.length} Verses across ${phrase.totalChapters} chapters in the Quran.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.getTextSecondary(context).withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
