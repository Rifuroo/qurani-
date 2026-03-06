import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models.dart';
import '../../../../services/local_database_service.dart';
import '../../../../services/quran_resource_service.dart';
import '../../../../core/design_system/app_design_system.dart';
import '../../../../core/utils/language_helper.dart';
import '../utils/translation_html_parser.dart';

class ShareCustomizationSheet extends StatefulWidget {
  final AyahSegment segment;
  final String surahName;

  const ShareCustomizationSheet({
    super.key,
    required this.segment,
    required this.surahName,
  });

  static Future<void> show(
    BuildContext context,
    AyahSegment segment,
    String surahName,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ Allows better height control
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ShareCustomizationSheet(segment: segment, surahName: surahName),
    );
  }

  @override
  State<ShareCustomizationSheet> createState() =>
      _ShareCustomizationSheetState();
}

class _ShareCustomizationSheetState extends State<ShareCustomizationSheet> {
  bool _includeArabic = true;
  bool _includeTranslation = true;
  bool _includeTransliteration = true;
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('stt');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  LanguageHelper.tr(_translations, 'share.title'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Option Tiles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildModernToggle(
                      icon: Icons.article_outlined,
                      title: LanguageHelper.tr(
                        _translations,
                        'share.arabic_text',
                      ),
                      value: _includeArabic,
                      onChanged: (val) => setState(() => _includeArabic = val),
                    ),
                    const SizedBox(height: 12),
                    _buildModernToggle(
                      icon: Icons.translate_outlined,
                      title: LanguageHelper.tr(
                        _translations,
                        'share.translation_text',
                      ),
                      value: _includeTranslation,
                      onChanged: (val) =>
                          setState(() => _includeTranslation = val),
                    ),
                    const SizedBox(height: 12),
                    _buildModernToggle(
                      icon: Icons.abc_outlined,
                      title: LanguageHelper.tr(
                        _translations,
                        'share.transliteration_text',
                      ),
                      value: _includeTransliteration,
                      onChanged: (val) =>
                          setState(() => _includeTransliteration = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getPrimary(context),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _handleShare(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          LanguageHelper.tr(_translations, 'share.button_text'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16), // ✅ Extra bottom clearance
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernToggle({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final primaryColor = AppColors.getPrimary(context);

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? primaryColor.withOpacity(0.08)
              : AppColors.getSurfaceVariant(context).withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: value ? primaryColor : AppColors.getBorderLight(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: value
                    ? AppColors.textInverse
                    : AppColors.getTextSecondary(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Slighly larger
                  color: value
                      ? primaryColor
                      : AppColors.getTextPrimary(context),
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      final resourceService = context.read<QuranResourceService>();
      final StringBuffer buffer = StringBuffer();

      buffer.writeln(
        '${widget.surahName} - ${LanguageHelper.tr(_translations, "bookmarks.ayah_label")} ${widget.segment.ayahNumber}',
      );
      buffer.writeln();

      if (_includeArabic) {
        final simpleArabic = await LocalDatabaseService.getSimpleArabicText(
          widget.segment.surahId,
          widget.segment.ayahNumber,
        );
        if (simpleArabic != null) {
          buffer.writeln(simpleArabic);
          buffer.writeln();
        }
      }

      if (_includeTranslation) {
        final rawTranslation = await resourceService.getTranslationText(
          widget.segment.surahId,
          widget.segment.ayahNumber,
        );
        if (rawTranslation != null) {
          final cleanTranslation = TranslationHtmlParser.cleanContent(
            rawTranslation.replaceAll(RegExp(r'<[^>]*>'), ''),
            widget.segment.ayahNumber,
          );
          buffer.writeln(cleanTranslation);
          buffer.writeln();
        }
      }

      if (_includeTransliteration) {
        final rawTrans = await resourceService.getTransliterationText(
          widget.segment.surahId,
          widget.segment.ayahNumber,
        );
        if (rawTrans != null) {
          buffer.writeln(
            '${LanguageHelper.tr(_translations, "share.transliteration_text")}: $rawTrans',
          );
          buffer.writeln();
        }
      }

      buffer.write(
        '- ${LanguageHelper.tr(_translations, "share.footer_text")}',
      );

      final finalContent = buffer.toString().trim();

      if (context.mounted) {
        Navigator.pop(context); // Close customization sheet
        await Share.share(finalContent);
      }
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }
}
