import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/screens/main/stt/services/mutashabihat_service.dart';
import 'package:cuda_qurani/screens/main/stt/data/models.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart';
import 'package:cuda_qurani/services/global_ayat_services.dart';

class SimilarityListView extends StatefulWidget {
  final AyahSegment segment;
  final String surahName;
  final bool isUniqueMode;

  const SimilarityListView({
    super.key,
    required this.segment,
    required this.surahName,
    this.isUniqueMode = false,
  });

  @override
  State<SimilarityListView> createState() => _SimilarityListViewState();
}

class _SimilarityListViewState extends State<SimilarityListView> {
  late int _currentSurahId;
  late int _currentAyahNumber;
  late String _currentSurahName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentSurahId = widget.segment.surahId;
    _currentAyahNumber = widget.segment.ayahNumber;
    _currentSurahName = widget.surahName;
  }

  void _navigateToAyah(int surahId, int ayahNumber) async {
    if (surahId < 1 || surahId > 114) return;
    
    setState(() => _isLoading = true);
    
    String surahName = _currentSurahName;
    
    // If surah changed, fetch new surah name
    if (surahId != _currentSurahId) {
      try {
        final quranService = Provider.of<QuranService>(context, listen: false);
        final chapter = await quranService.getChapterInfo(surahId);
        surahName = chapter.nameSimple;
      } catch (e) {
        debugPrint('Error fetching surah name in SimilarityListView: $e');
      }
    }

    setState(() {
      _currentSurahId = surahId;
      _currentAyahNumber = ayahNumber;
      _currentSurahName = surahName;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: _buildBody(context),
          ),
          _buildBottomNavigation(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.getSurface(context),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
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
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final mutashabihatService = MutashabihatService();
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _getData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final data = snapshot.data ?? {};
        final String verseText = data['verseText'] ?? '';
        final List<SimilarVerseReference> similarities = data['similarities'] ?? [];
        final List<MutashabihatPhrase> phrases = data['phrases'] ?? [];

        return ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Current Verse Header
            if (verseText.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                child: Text(
                  verseText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 28,
                    fontFamily: 'UthmanTN',
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Similarity Status
            if (similarities.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 8),
                child: Text(
                  'No similar verses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              )
            else ...[
               Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 8),
                child: Text(
                  'Similar verses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              ...similarities.map((sim) => _buildSimilarVerseCard(context, sim)),
              const SizedBox(height: 24),
            ],

            // Phrases Section
            if (phrases.isNotEmpty) ...[
              if (similarities.isNotEmpty) // Extra heading if phrases follow verses
                 Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 8),
                  child: Text(
                    'Similar phrases',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ),
              ...phrases.map((phrase) => _buildPhraseCard(context, phrase)),
            ],
            
            if (similarities.isEmpty && phrases.isEmpty)
              _buildUniqueView(context),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getData() async {
    final service = MutashabihatService();
    final currentText = await service.getVerseText(_currentSurahId, _currentAyahNumber);
    final similarities = await service.getSimilarPhrases(_currentSurahId, _currentAyahNumber);
    final phrases = await service.getPhrasesForVerse(_currentSurahId, _currentAyahNumber);
    
    return {
      'verseText': currentText,
      'similarities': similarities,
      'phrases': phrases,
    };
  }

  Widget _buildSimilarVerseCard(BuildContext context, SimilarVerseReference sim) {
     return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.getBorderLight(context).withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          try {
            final controller = context.read<SttController>();
            controller.jumpToAyah(sim.surah, sim.ayah);
            Navigator.pop(context);
          } catch (e) {
            debugPrint('Error jumping to ayah: $e');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigation error')));
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sim.surah}:${sim.ayah}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getPrimary(context),
                    ),
                  ),
                  Text(
                    'Score: ${sim.score}%',
                    style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                sim.verseText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'UthmanTN',
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhraseCard(BuildContext context, MutashabihatPhrase phrase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.getBorderLight(context).withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          _showVersesForPhrase(context, phrase);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phrase.text,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: 'UthmanTN',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The phrase appears ${phrase.totalOccurrences} times in ${phrase.verseKeys.length} Verses across ${phrase.totalChapters} chapters in the Quran.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context).withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showVersesForPhrase(BuildContext context, MutashabihatPhrase phrase) {
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getBorderLight(context).withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Verses with this phrase',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: phrase.verseKeys.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final key = phrase.verseKeys[index];
                  return ListTile(
                    title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      final parts = key.split(':');
                      final s = int.parse(parts[0]);
                      final a = int.parse(parts[1]);
                      
                      try {
                        final controller = this.context.read<SttController>();
                        controller.jumpToAyah(s, a);
                        Navigator.pop(context); // Close sheet
                        Navigator.pop(this.context); // Close similarity view
                      } catch (e) {
                         debugPrint('Error jumping to ayah from phrase: $e');
                         Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniqueView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Icon(Icons.verified_outlined, size: 64, color: AppColors.getPrimary(context).withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Ayah Munfaridah',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This verse has no documented similarities in our database.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border(top: BorderSide(color: AppColors.getBorderLight(context).withOpacity(0.5))),
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
            // Next on the left (RTL optimization)
            Expanded(
              child: _buildNavButton(
                context,
                label: 'Next',
                icon: Icons.chevron_left,
                isLeft: true,
                onTap: () {
                  final globalIndex = GlobalAyatService.toGlobalAyat(_currentSurahId, _currentAyahNumber);
                  if (GlobalAyatService.isValid(globalIndex + 1)) {
                    final nextData = GlobalAyatService.fromGlobalAyat(globalIndex + 1);
                    _navigateToAyah(nextData['surah_id']!, nextData['ayah_number']!);
                  } else {
                    _showEdgeCaseSnackBar('Reached the end of Al-Quran');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Previous on the right
            Expanded(
              child: _buildNavButton(
                context,
                label: 'Previous',
                icon: Icons.chevron_right,
                isLeft: false,
                onTap: () {
                  final globalIndex = GlobalAyatService.toGlobalAyat(_currentSurahId, _currentAyahNumber);
                  if (GlobalAyatService.isValid(globalIndex - 1)) {
                    final prevData = GlobalAyatService.fromGlobalAyat(globalIndex - 1);
                    _navigateToAyah(prevData['surah_id']!, prevData['ayah_number']!);
                  } else {
                    _showEdgeCaseSnackBar('First verse of Al-Fatihah');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, {
    required String label,
    required IconData icon,
    required bool isLeft,
    required VoidCallback onTap,
  }) {
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
                if (isLeft) Icon(icon, color: AppColors.getTextPrimary(context).withOpacity(0.7), size: 22),
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
                if (!isLeft) Icon(icon, color: AppColors.getTextPrimary(context).withOpacity(0.7), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEdgeCaseSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
