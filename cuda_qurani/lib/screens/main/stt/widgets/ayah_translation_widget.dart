// lib/screens/main/stt/widgets/ayah_translation_widget.dart
//
// A compact, reusable widget that displays the translation of a single Ayah
// inline inside the list view. Uses QuranResourceService which is already
// in MultiProvider — no additional providers needed.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/translation_download.dart';
import 'package:cuda_qurani/screens/main/stt/utils/translation_html_parser.dart';

class AyahTranslationWidget extends StatefulWidget {
  final int surahId;
  final int ayahNumber;

  const AyahTranslationWidget({
    super.key,
    required this.surahId,
    required this.ayahNumber,
  });

  @override
  State<AyahTranslationWidget> createState() => _AyahTranslationWidgetState();
}

class _AyahTranslationWidgetState extends State<AyahTranslationWidget> {
  Future<String?>? _future;
  String? _lastTranslationId;

  @override
  void initState() {
    super.initState();
    // Do NOT call _scheduleFetch here because didChangeDependencies
    // will be called immediately after, which would trigger a double fetch.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh if the user switches to a different translation,
    // or if this is the initial build (since _lastTranslationId is null).
    final svc = context.read<QuranResourceService>();
    if (svc.selectedTranslationId != _lastTranslationId) {
      _lastTranslationId = svc.selectedTranslationId;
      _scheduleFetch();
    }
  }

  void _scheduleFetch() {
    final svc = context.read<QuranResourceService>();
    if (svc.selectedTranslationId == null) {
      _future = Future.value(null);
    } else {
      _future = svc.getTranslationText(widget.surahId, widget.ayahNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationLanguage = context.select<QuranResourceService, String?>(
      (s) => s.selectedTranslationLanguage,
    );

    if (translationLanguage == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(context);
        }

        final data = snapshot.data;
        if (data == null) {
          return _buildNotAvailable(context);
        }

        final (groupRange, cleanRaw) = TranslationHtmlParser.extractGroupInfo(
          data,
        );
        final cleaned = TranslationHtmlParser.cleanContent(
          cleanRaw,
          widget.ayahNumber,
        );
        final spans = TranslationHtmlParser.parseHtmlToSpans(context, cleaned);
        final isRtl = TranslationHtmlParser.isRtlLanguage(translationLanguage);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (groupRange != null) ...[
              _buildGroupBanner(context, groupRange),
              const SizedBox(height: 4),
            ],
            Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: RichText(
                textAlign: isRtl ? TextAlign.justify : TextAlign.left,
                text: TextSpan(children: spans),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SkeletonLine(width: double.infinity),
          const SizedBox(height: 4),
          _SkeletonLine(width: 180),
        ],
      ),
    );
  }

  Widget _buildNotAvailable(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TranslationDownloadPage()),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 14,
            color: AppColors.getTextSecondary(context).withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            'Download translation',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondary(context).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupBanner(BuildContext context, String rangeText) {
    final isIndo = rangeText.toLowerCase().contains('sampai');
    final message = isIndo
        ? 'Terjemahan kelompok $rangeText'
        : 'Group: $rangeText';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getInfo(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: AppColors.getInfo(context).withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.getInfo(context).withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  const _SkeletonLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.getBorderLight(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
