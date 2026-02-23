import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/navigation/app_navigation_service.dart';
import '../controllers/verse_similarity_controller.dart';
import '../widgets/ayah_similarity_card.dart';

class VerseSimilarityPage extends StatelessWidget {
  const VerseSimilarityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: Consumer<VerseSimilarityController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage != null) {
            return Center(child: Text(controller.errorMessage!));
          }

          final hasSimilar = controller.similarVerses.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              const SizedBox(height: 24),
              _buildCurrentVerseHeader(context, controller),
              const SizedBox(height: 32),
              if (!hasSimilar)
                _buildEmptyState(context)
              else
                ...controller.similarVerses.map(
                  (sim) => AyahSimilarityCard(verse: sim),
                ),
              // Extra space for bottom nav
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final controller = context.read<VerseSimilarityController>();
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
              '${controller.surahId}:${controller.ayahNumber}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${controller.surahName} - Verse ${controller.ayahNumber}',
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

  Widget _buildCurrentVerseHeader(
    BuildContext context,
    VerseSimilarityController controller,
  ) {
    return Column(
      children: [
        Text(
          controller.verseText ?? '',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 26,
            fontFamily: 'UthmanTN',
            height: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No similar verses',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No similar phrases found for this verse',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final controller = context.watch<VerseSimilarityController>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavButton(
                  context,
                  label: 'Next',
                  icon: Icons.chevron_left,
                  onPressed: controller.nextAyah,
                ),
                _buildNavButton(
                  context,
                  label: 'Previous',
                  icon: Icons.chevron_right,
                  onPressed: controller.previousAyah,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == Icons.chevron_left) Icon(icon, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            if (icon == Icons.chevron_right) Icon(icon, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
