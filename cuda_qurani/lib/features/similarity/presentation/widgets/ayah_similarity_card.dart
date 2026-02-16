import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import '../../domain/entities/similarity_result.dart';
import '../../domain/repositories/similarity_repository.dart';
import '../controllers/phrase_similarity_controller.dart';

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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isCurrentSelected
              ? AppColors.getPrimary(context)
              : AppColors.getBorderLight(context).withOpacity(0.4),
          width: isCurrentSelected ? 2 : 0.8,
        ),
      ),
      child: InkWell(
        onTap: () {
          try {
            final sttController = context.read<SttController>();
            sttController.jumpToAyah(verse.surahId, verse.ayahNumber);
            Navigator.pop(context);
          } catch (e) {
            debugPrint('Error jumping to ayah: $e');
          }
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
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        verse.surahName ?? 'Surah',
                        style: TextStyle(
                          fontSize: 18,
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
                  if (verse.translation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      verse.translation!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextPrimary(context),
                        height: 1.4,
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

    if (highlight == null || highlight.isEmpty || !text.contains(highlight)) {
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

    final parts = text.split(highlight);
    final spans = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: highlight,
            style: TextStyle(
              color: AppColors.getPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    return RichText(
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: TextStyle(
          fontSize: 24,
          fontFamily: 'UthmanTN',
          height: 1.8,
          color: AppColors.getTextPrimary(context),
        ),
        children: spans,
      ),
    );
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhraseOccurrencesPage(
                phrase: phrase,
                surahId: controller.surahId,
                ayahNumber: controller.ayahNumber,
                surahName: controller.surahName,
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
                      'The phrase appears ${phrase.totalOccurrences} times in ${phrase.totalOccurrences} Verses across ${phrase.totalChapters} chapters in the Quran.',
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

class PhraseOccurrencesPage extends StatefulWidget {
  final SimilarPhrase phrase;
  final int surahId;
  final int ayahNumber;
  final String surahName;

  const PhraseOccurrencesPage({
    super.key,
    required this.phrase,
    required this.surahId,
    required this.ayahNumber,
    required this.surahName,
  });

  @override
  State<PhraseOccurrencesPage> createState() => _PhraseOccurrencesPageState();
}

class _PhraseOccurrencesPageState extends State<PhraseOccurrencesPage> {
  List<SimilarVerse>? _verses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repository = context.read<ISimilarityRepository>();
      final verses = await repository.getVersesByKeys(
        widget.phrase.verseKeys,
        widget.phrase.text,
      );
      if (mounted) {
        setState(() {
          _verses = verses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading phrase occurrences: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(context),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: AppColors.getTextSecondary(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(
              context,
            ).popUntil((r) => r.isFirst || r.settings.name == '/'),
            color: AppColors.getTextSecondary(context),
          ),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.getBorderLight(context)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${widget.surahId}:${widget.ayahNumber}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.surahName} - Verse ${widget.ayahNumber}',
              style: TextStyle(
                color: AppColors.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _verses == null || _verses!.isEmpty
          ? const Center(child: Text('No occurrences found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _verses!.length,
              itemBuilder: (context, index) {
                return AyahSimilarityCard(verse: _verses![index]);
              },
            ),
    );
  }
}
