import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/navigation/app_navigation_service.dart';
import '../../domain/entities/similarity_result.dart';
import '../../domain/repositories/similarity_repository.dart';
import '../widgets/ayah_similarity_card.dart';

class PhraseDetailPage extends StatefulWidget {
  final SimilarPhrase phrase;
  final int surahId;
  final int ayahNumber;
  final String surahName;
  final ISimilarityRepository repository;
  final dynamic sttController;

  const PhraseDetailPage({
    super.key,
    required this.phrase,
    required this.surahId,
    required this.ayahNumber,
    required this.surahName,
    required this.repository,
    this.sttController,
  });

  @override
  State<PhraseDetailPage> createState() => _PhraseDetailPageState();
}

class _PhraseDetailPageState extends State<PhraseDetailPage> {
  List<SimilarVerse>? _verses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final verses = await widget.repository.getVersesByKeys(
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
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header Section
                SliverToBoxAdapter(child: _buildPhraseHeader(context)),

                // Verses List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return AyahSimilarityCard(
                        verse: _verses![index],
                        isCurrentSelected:
                            _verses![index].surahId == widget.surahId &&
                            _verses![index].ayahNumber == widget.ayahNumber,
                      );
                    }, childCount: _verses?.length ?? 0),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.getSurface(context),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => AppNavigationService.safePop(context),
        color: AppColors.getTextSecondary(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => AppNavigationService.exitToRoot(context),
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
            'Phrase detail',
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhraseHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            children: [
              Text(
                widget.phrase.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontFamily: 'UthmanTN',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The phrase appears ${widget.phrase.totalOccurrences} times in ${widget.phrase.verseKeys.length} Verses across ${widget.phrase.totalChapters} chapters in the Quran.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(context).withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 24),
      ],
    );
  }
}
