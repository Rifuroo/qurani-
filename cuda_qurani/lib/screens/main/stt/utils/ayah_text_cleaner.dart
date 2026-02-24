import 'translation_html_parser.dart';

class AyahTextCleaner {
  AyahTextCleaner._();

  /// Cleans Arabic text by removing PUA characters (often used for ayah markers/glyphs).
  static String cleanArabic(String text) {
    // We no longer strip PUA characters as the user wants the stylized QPC glyphs
    // which often appear larger and more correct for the Mushaf context.
    String cleaned = text;

    // Collapse multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// Cleans translation text using the existing HTML parser logic.
  static String cleanTranslation(String text, int ayahNumber) {
    // 1. Strip HTML tags
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // 2. Use TranslationHtmlParser for deep cleaning (preambles, footnotes, etc.)
    cleaned = TranslationHtmlParser.cleanContent(cleaned, ayahNumber);

    return cleaned;
  }
}
