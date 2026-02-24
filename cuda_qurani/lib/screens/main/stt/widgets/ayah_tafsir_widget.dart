// lib/screens/main/stt/widgets/ayah_tafsir_widget.dart
//
// An expandable widget that displays the Tafsir of a single Ayah inline.
// Defaults to a collapsed "Read Tafsir" button to save space.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
import 'package:cuda_qurani/screens/main/stt/utils/translation_html_parser.dart';

class AyahTafsirWidget extends StatefulWidget {
  final int surahId;
  final int ayahNumber;

  const AyahTafsirWidget({
    super.key,
    required this.surahId,
    required this.ayahNumber,
  });

  @override
  State<AyahTafsirWidget> createState() => _AyahTafsirWidgetState();
}

class _AyahTafsirWidgetState extends State<AyahTafsirWidget> {
  bool _isExpanded = false;
  Future<String?>? _future;
  String? _lastTafsirId;

  @override
  void initState() {
    super.initState();
    // Do NOT call _scheduleFetch here because didChangeDependencies
    // will be called immediately after.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = context.read<QuranResourceService>();
    if (svc.selectedTafsirId != _lastTafsirId) {
      _lastTafsirId = svc.selectedTafsirId;
      _scheduleFetch();
    }
  }

  void _scheduleFetch() {
    final svc = context.read<QuranResourceService>();
    if (svc.selectedTafsirId == null) {
      _future = Future.value(null);
    } else {
      _future = svc.getTafsirText(widget.surahId, widget.ayahNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tafsirId = context.select<QuranResourceService, String?>(
      (s) => s.selectedTafsirId,
    );
    final tafsirLanguage = context.select<QuranResourceService, String?>(
      (s) => s.selectedTafsirLanguage,
    );

    if (tafsirId == null) {
      return const SizedBox.shrink(); // Hide entirely if no tafsir selected
    }

    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Wait quietly
        }

        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink(); // No tafsir available for this ayah
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expand/Collapse Toggle
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpanded
                            ? Icons.menu_book
                            : Icons.menu_book_outlined,
                        size: 14,
                        color: AppColors.getPrimary(
                          context,
                        ).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isExpanded ? 'Hide Tafsir' : 'Read Tafsir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getPrimary(
                            context,
                          ).withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: AppColors.getPrimary(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Content
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                _buildTafsirContent(context, data, tafsirLanguage),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTafsirContent(
    BuildContext context,
    String data,
    String? language,
  ) {
    final (groupRange, cleanRaw) = TranslationHtmlParser.extractGroupInfo(data);
    final cleaned = TranslationHtmlParser.cleanContent(
      cleanRaw,
      widget.ayahNumber,
    );
    final spans = TranslationHtmlParser.parseHtmlToSpans(context, cleaned);
    final isRtl = TranslationHtmlParser.isRtlLanguage(language);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceVariant(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.getBorderLight(context).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (groupRange != null) ...[
            _buildGroupBanner(context, groupRange),
            const SizedBox(height: 10),
          ],
          Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: RichText(
              textAlign: isRtl ? TextAlign.justify : TextAlign.left,
              text: TextSpan(
                children: spans,
                style: TextStyle(
                  fontSize: 15, // Slightly larger for long-form reading
                  color: AppColors.getTextPrimary(context),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupBanner(BuildContext context, String rangeText) {
    final isIndo = rangeText.toLowerCase().contains('sampai');
    final message = isIndo
        ? 'Tafsir kelompok $rangeText'
        : 'Tafsir Group: $rangeText';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getPrimary(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: AppColors.getPrimary(context).withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.getPrimary(context).withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
