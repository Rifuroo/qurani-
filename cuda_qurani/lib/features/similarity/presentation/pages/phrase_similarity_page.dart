import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/navigation/app_navigation_service.dart';
import '../controllers/phrase_similarity_controller.dart';
import '../widgets/ayah_similarity_card.dart';

class PhraseSimilarityPage extends StatelessWidget {
  const PhraseSimilarityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: Consumer<PhraseSimilarityController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage != null) {
            return Center(child: Text(controller.errorMessage!));
          }

          if (controller.similarPhrases.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ...controller.similarPhrases.map(
                (phrase) => PhraseSimilarityCard(phrase: phrase),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final controller = context.read<PhraseSimilarityController>();
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        'No similar phrases found for this verse',
        style: TextStyle(
          fontSize: 16,
          color: AppColors.getTextSecondary(context),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final controller = context.watch<PhraseSimilarityController>();
    // For now we don't have next/prev in PhraseSimilarityController
    // but based on UI image it should be there.
    // Assuming we can add it or it's a mock.
    // I'll add the UI buttons anyway to match the image.
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
