import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import '../services/quran_service.dart';
import 'package:cuda_qurani/features/quran_content/domain/entities/ayah_content.dart';
import 'tafsir_placeholder_view.dart';
import 'translation_placeholder_view.dart';
import 'package:cuda_qurani/features/similarity/presentation/pages/verse_similarity_page.dart';
import 'package:cuda_qurani/features/similarity/presentation/pages/phrase_similarity_page.dart';
import 'package:cuda_qurani/features/similarity/domain/repositories/similarity_repository.dart';
import 'package:cuda_qurani/features/similarity/data/repositories/similarity_repository_impl.dart';
import 'package:cuda_qurani/features/similarity/presentation/controllers/verse_similarity_controller.dart';
import 'package:cuda_qurani/features/similarity/presentation/controllers/phrase_similarity_controller.dart';

class AyahOptionsSheet extends StatefulWidget {
  final AyahSegment segment;
  final String surahName;

  const AyahOptionsSheet({
    super.key,
    required this.segment,
    required this.surahName,
  });

  static Future<void> show(
    BuildContext context,
    AyahSegment segment,
    String surahName,
  ) {
    // Set selection highlight in controller
    final sttController = context.read<SttController>();
    final quranService = context.read<QuranService>();
    sttController.setSelectedAyahForOptions(segment);

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15), // ✅ Lighter shadow
      isScrollControlled: true,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sttController),
          Provider.value(value: quranService),
        ],
        child: AyahOptionsSheet(segment: segment, surahName: surahName),
      ),
    ).then((_) {
      // Clear highlight when dismissed
      sttController.clearSelectedAyahForOptions();
    });
  }

  @override
  State<AyahOptionsSheet> createState() => _AyahOptionsSheetState();
}

class _AyahOptionsSheetState extends State<AyahOptionsSheet> {
  int? _similarityCount;
  int? _phraseCount;

  @override
  void initState() {
    super.initState();
    _loadSimilarityCounts();
  }

  Future<void> _loadSimilarityCounts() async {
    try {
      final resourceService = context.read<QuranResourceService>();
      final repository = SimilarityRepositoryImpl(
        resourceService: resourceService,
      );

      final verses = await repository.getSimilarVerses(
        widget.segment.surahId,
        widget.segment.ayahNumber,
      );
      final phrases = await repository.getSimilarPhrases(
        widget.segment.surahId,
        widget.segment.ayahNumber,
      );

      if (mounted) {
        setState(() {
          _similarityCount = verses.length;
          _phraseCount = phrases.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading similarity counts for sheet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Material(
      color: AppColors.getSurface(context),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // ✅ Shrink to fit content
          children: [
            // Header Row: [36:3] Ya-Sin - Verse 3 [X]
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                4,
                8,
                4,
              ), // Reduced bottom padding
              child: Row(
                children: [
                  // Ayah Box [36:3]
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.getBorderLight(context),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.segment.surahId}:${widget.segment.ayahNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Text(
                      '${widget.surahName} - Verse ${widget.segment.ayahNumber}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                  // Close Button
                  IconButton(
                    iconSize: 22,
                    icon: Icon(
                      Icons.close,
                      color: AppColors.getTextSecondary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // Compact Options List (No Scroll)
            Column(
              children: [
                _buildCompactOption(
                  context,
                  icon: Icons.play_arrow_outlined,
                  label: 'Listen',
                  onTap: () {
                    Navigator.pop(context);
                    // ✅ Trigger audio playback
                    context.read<SttController>().playAyah(widget.segment);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.translate_outlined,
                  label: 'Translations',
                  onTap: () {
                    _navigateToContent(context, AyahContentType.translation);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'Tafsir',
                  onTap: () {
                    _navigateToContent(context, AyahContentType.tafsir);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.bookmark_border_outlined,
                  label: 'Bookmark',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleBookmark(context);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.layers_outlined,
                  label: _phraseCount == null
                      ? 'Similar phrases'
                      : (_phraseCount == 0
                            ? 'No similar phrases'
                            : '$_phraseCount similar phrases'),
                  onTap: () {
                    _navigateToPhraseSimilarity(context);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.compare_arrows,
                  label: _similarityCount == null
                      ? 'Similar verses'
                      : (_similarityCount == 0
                            ? 'No similar verses'
                            : '$_similarityCount similar verses'),
                  onTap: () {
                    _navigateToVerseSimilarity(context);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.copy_outlined,
                  label: 'Copy',
                  onTap: () {
                    Navigator.pop(context);
                    _copyToClipboard(context);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    Navigator.pop(context);
                    _shareAyah(context);
                  },
                ),
                // Add bottom padding for better touch area
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Navigates to the new modular [AyahContentPage].
  ///
  /// This method prepares the repository and controller needed for the page,
  /// ensuring a clean separation from the [AyahOptionsSheet].
  void _navigateToContent(BuildContext context, AyahContentType type) {
    try {
      final sttController = Provider.of<SttController>(context, listen: false);
      final quranService = Provider.of<QuranService>(context, listen: false);

      if (type == AyahContentType.tafsir) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: sttController),
                Provider.value(value: quranService),
              ],
              child: TafsirPlaceholderView(
                segment: widget.segment,
                surahName: widget.surahName,
              ),
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: sttController),
                Provider.value(value: quranService),
              ],
              child: TranslationPlaceholderView(
                segment: widget.segment,
                surahName: widget.surahName,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to AyahContentPage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load ${type.name} view')),
      );
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final resourceService = Provider.of<QuranResourceService>(
      context,
      listen: false,
    );

    final arabicText =
        widget.segment.ayahGlyphText ??
        widget.segment.words.map((w) => w.text).join(' ');
    final translation = await resourceService.getTranslationText(
      widget.segment.surahId,
      widget.segment.ayahNumber,
    );

    final textToCopy =
        'Quran ${widget.segment.surahId}:${widget.segment.ayahNumber}\n\n$arabicText\n\n${translation ?? ""}';

    await Clipboard.setData(ClipboardData(text: textToCopy));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ayah copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleBookmark(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkKey = 'bookmarks';
    final currentBookmarks = prefs.getStringList(bookmarkKey) ?? [];
    final ayahKey = '${widget.segment.surahId}:${widget.segment.ayahNumber}';

    if (currentBookmarks.contains(ayahKey)) {
      currentBookmarks.remove(ayahKey);
      await prefs.setStringList(bookmarkKey, currentBookmarks);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmark removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      currentBookmarks.add(ayahKey);
      await prefs.setStringList(bookmarkKey, currentBookmarks);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayah bookmarked successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _shareAyah(BuildContext context) async {
    final resourceService = Provider.of<QuranResourceService>(
      context,
      listen: false,
    );
    final arabicText = widget.segment.words.map((w) => w.text).join(' ');
    final translation = await resourceService.getTranslationText(
      widget.segment.surahId,
      widget.segment.ayahNumber,
    );

    final shareText =
        'Quran ${widget.segment.surahId}:${widget.segment.ayahNumber}\n\n$arabicText\n\n${translation ?? ""} - Shared from Qurani';

    // Since share_plus is not yet in pubspec, we'll use copy as a fallback for now
    // but structure it for future share integration.
    await Clipboard.setData(ClipboardData(text: shareText));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prepared for sharing (copied to clipboard)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCompactOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ), // ✅ Compact padding
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.getTextSecondary(context)),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToVerseSimilarity(BuildContext context) {
    try {
      final sttController = Provider.of<SttController>(context, listen: false);
      final quranService = Provider.of<QuranService>(context, listen: false);
      final resourceService = Provider.of<QuranResourceService>(
        context,
        listen: false,
      );

      final repository = SimilarityRepositoryImpl(
        resourceService: resourceService,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: sttController),
              Provider.value(value: quranService),
              Provider<ISimilarityRepository>.value(value: repository),
              ChangeNotifierProvider(
                create: (_) => VerseSimilarityController(
                  repository: repository,
                  initialSurahId: widget.segment.surahId,
                  initialAyahNumber: widget.segment.ayahNumber,
                  initialSurahName: widget.surahName,
                ),
              ),
            ],
            child: const VerseSimilarityPage(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to VerseSimilarityPage: $e');
    }
  }

  void _navigateToPhraseSimilarity(BuildContext context) {
    try {
      final sttController = Provider.of<SttController>(context, listen: false);
      final quranService = Provider.of<QuranService>(context, listen: false);
      final resourceService = Provider.of<QuranResourceService>(
        context,
        listen: false,
      );

      final repository = SimilarityRepositoryImpl(
        resourceService: resourceService,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: sttController),
              Provider.value(value: quranService),
              ChangeNotifierProvider(
                create: (_) => PhraseSimilarityController(
                  repository: repository,
                  initialSurahId: widget.segment.surahId,
                  initialAyahNumber: widget.segment.ayahNumber,
                  initialSurahName: widget.surahName,
                ),
              ),
            ],
            child: const PhraseSimilarityPage(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to PhraseSimilarityPage: $e');
    }
  }
}
