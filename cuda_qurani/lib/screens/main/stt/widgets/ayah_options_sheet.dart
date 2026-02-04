import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/translation_placeholder_view.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/tafsir_placeholder_view.dart';
import '../data/models.dart';

class AyahOptionsSheet extends StatelessWidget {
  final AyahSegment segment;
  final String surahName;

  const AyahOptionsSheet({
    super.key,
    required this.segment,
    required this.surahName,
  });

  static Future<void> show(BuildContext context, AyahSegment segment, String surahName) {
    // Set selection highlight in controller
    final sttController = context.read<SttController>();
    sttController.setSelectedAyahForOptions(segment);

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15), // ✅ Lighter shadow
      isScrollControlled: true,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sttController),
        ],
        child: AyahOptionsSheet(segment: segment, surahName: surahName),
      ),
    ).then((_) {
      // Clear highlight when dismissed
      sttController.clearSelectedAyahForOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      // height: screenHeight * 0.5, // ❌ Remove fixed height to allow shrink-wrap
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // ✅ Shrink to fit content
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getBorderLight(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Row: [36:3] Ya-Sin - Verse 3 [X]
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4), // Reduced bottom padding
              child: Row(
                children: [
                  // Ayah Box [36:3]
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.getBorderLight(context)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${segment.surahId}:${segment.ayahNumber}',
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
                      '$surahName - Verse ${segment.ayahNumber}',
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
                    icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
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
                    context.read<SttController>().playAyah(segment);
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.translate_outlined,
                  label: 'Translations',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TranslationPlaceholderView(
                          surahId: segment.surahId,
                          ayahNumber: segment.ayahNumber,
                          surahName: surahName,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'Tafsir',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TafsirPlaceholderView(
                          surahId: segment.surahId,
                          ayahNumber: segment.ayahNumber,
                          surahName: surahName,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.bookmark_border_outlined,
                  label: 'Bookmark',
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.layers_outlined,
                  label: 'Similar phrases',
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.format_list_bulleted_outlined,
                  label: 'No similar verses',
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.copy_outlined,
                  label: 'Copy',
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1, thickness: 0.5),
                _buildCompactOption(
                  context,
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => Navigator.pop(context),
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

  Widget _buildCompactOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // ✅ Compact padding
        child: Row(
          children: [
            Icon(
              icon, 
              size: 22, 
              color: AppColors.getTextSecondary(context),
            ),
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
}
