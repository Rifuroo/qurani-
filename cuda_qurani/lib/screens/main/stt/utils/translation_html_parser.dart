// lib/screens/main/stt/utils/translation_html_parser.dart
//
// Shared utility for parsing and cleaning translation text from QuranResourceService.
// Extracted from TranslationPlaceholderView to avoid code duplication.

import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

/// Shared utility for rendering and cleaning translation text.
class TranslationHtmlParser {
  TranslationHtmlParser._(); // prevent instantiation

  // RTL languages served by the translation system
  static const _rtlLanguages = {'العربية', 'اردو', 'فارسی'};

  /// Returns `true` if the selected translation language is RTL.
  static bool isRtlLanguage(String? language) =>
      language != null && _rtlLanguages.contains(language);

  /// Strips common preamble text, reference citations, HTML entities,
  /// and inline footnote markers from raw translation content.
  static String cleanContent(String raw, int ayahNumber) {
    if (raw.isEmpty) return raw;

    String cleaned = raw;

    // Remove grouped-verse preambles (English + Indonesian)
    cleaned = cleaned.replaceAll(
      RegExp(
        r'You are reading a [^ ]+ of a group of verses from \d+:\d+ to \d+:\d+',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'Anda sedang membaca [^ ]+ kelompok ayat dari \d+:\d+ sampai \d+:\d+',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+:\d+\s*[-]\s*'), '');

    // Strip reference citations e.g. (Al-Fatihah: 1-7)
    cleaned = cleaned.replaceAll(
      RegExp(r'[\(\[（][^:\]\)]+:\s*\d+[-\d]*[\)\]）]'),
      '',
    );

    // ✅ Strip footnote markers — common in Quran translation DBs:
    //   <sup>1</sup>, <sup class="foot">1</sup> etc.
    cleaned = cleaned.replaceAll(
      RegExp(r'<sup[^>]*>\d+</sup>', caseSensitive: false),
      '',
    );
    //   Standalone superscript-style numbers attached to punctuation: ,1  .1  ;1
    cleaned = cleaned.replaceAll(RegExp(r'([,\.;:])\d+(?=\s|\$)'), r'\1');
    //   Bracketed footnote refs: [1] [2] (1) (2)
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\d+[\)\]]'), '');
    //   Trailing bare numbers after whitespace (e.g. "jalan yang lurus 1")
    cleaned = cleaned.replaceAll(RegExp(r'\s\d+(?=\s*\$)'), '');

    // HTML entity decoding
    cleaned = cleaned.replaceAll('&nbsp;', ' ');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&rsquo;', "'");
    cleaned = cleaned.replaceAll('&lsquo;', "'");

    // Tighten tag whitespace
    cleaned = cleaned.replaceAll(RegExp(r'>\s+<'), '><');

    // Collapse whitespace runs
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');

    return cleaned.trim();
  }

  /// Extracts group-range info from raw content if present.
  /// Returns `(groupRange, cleanedData)` — groupRange is null when absent.
  static (String?, String) extractGroupInfo(String raw) {
    if (raw.startsWith('GROUP_INFO|')) {
      final parts = raw.split('|');
      if (parts.length >= 3) {
        final groupRange = parts[1];
        final cleanData = parts.sublist(2).join('|');
        return (groupRange, cleanData);
      }
    }
    return (null, raw);
  }

  /// Converts an HTML-tagged string into a list of [InlineSpan]s for [RichText].
  static List<InlineSpan> parseHtmlToSpans(BuildContext context, String text) {
    final spans = <InlineSpan>[];

    final regExp = RegExp(r'(<[^>]+>|[^<]+)');
    final matches = regExp.allMatches(text);

    final styleStack = <TextStyle>[
      TextStyle(
        fontSize: 14,
        color: AppColors.getTextSecondary(context),
        height: 1.5,
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
          // skip opening block tags
        } else if (part.startsWith('<sup')) {
          // ✅ Skip superscript footnote tags entirely (content handled by cleanContent)
          // We push a dummy style so the closing </sup> pops correctly
          styleStack.add(styleStack.last.copyWith(fontSize: 0));
        } else if (tag == '</sup>') {
          if (styleStack.length > 1) styleStack.removeLast();
        } else if (part.startsWith('<span')) {
          TextStyle current = styleStack.last;
          if (part.contains('font-weight:bold') ||
              part.contains('font-weight: bold')) {
            current = current.copyWith(fontWeight: FontWeight.bold);
          }
          if (part.contains('font-style:italic') ||
              part.contains('font-style: italic')) {
            current = current.copyWith(fontStyle: FontStyle.italic);
          }
          styleStack.add(current);
        } else if (tag == '</span>') {
          if (styleStack.length > 1) styleStack.removeLast();
        } else if (tag == '<b>' || tag == '<strong>') {
          styleStack.add(styleStack.last.copyWith(fontWeight: FontWeight.bold));
        } else if (tag == '</b>' || tag == '</strong>') {
          if (styleStack.length > 1) styleStack.removeLast();
        } else if (tag == '<i>' || tag == '<em>') {
          styleStack.add(styleStack.last.copyWith(fontStyle: FontStyle.italic));
        } else if (tag == '</i>' || tag == '</em>') {
          if (styleStack.length > 1) styleStack.removeLast();
        }
        // All other tags ignored
      } else {
        if (part.trim().isNotEmpty) {
          spans.add(TextSpan(text: part, style: styleStack.last));
        }
      }
    }

    return spans;
  }
}
