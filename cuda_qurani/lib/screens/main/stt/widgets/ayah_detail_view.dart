import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';

/// A detailed view for a specific Ayah, allowing users to read Tafsir and Translations.
class AyahDetailView extends StatefulWidget {
  final AyahSegment segment;
  final String surahName;
  final String initialMode;

  const AyahDetailView({
    super.key,
    required this.segment,
    required this.surahName,
    this.initialMode = 'tafsir',
  });

  @override
  State<AyahDetailView> createState() => _AyahDetailViewState();
}

class _AyahDetailViewState extends State<AyahDetailView> {
  late String _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final resourceService = Provider.of<QuranResourceService>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          '${widget.surahName} ${widget.segment.ayahNumber}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18 * s,
          ),
        ),
        backgroundColor: AppColors.getSurface(context),
        foregroundColor: AppColors.getTextPrimary(context),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Mode Toggle
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppDesignSystem.space20 * s,
              vertical: AppDesignSystem.space12 * s,
            ),
            color: AppColors.getSurface(context),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    label: 'Tafsir',
                    isSelected: _mode == 'tafsir',
                    onTap: () => setState(() => _mode = 'tafsir'),
                  ),
                ),
                SizedBox(width: AppDesignSystem.space12 * s),
                Expanded(
                  child: _buildToggleButton(
                    label: 'Terjemahan',
                    isSelected: _mode == 'translation',
                    onTap: () => setState(() => _mode = 'translation'),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppDesignSystem.space20 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Arabic Source Card
                   Container(
                     padding: EdgeInsets.all(AppDesignSystem.space20 * s),
                     decoration: BoxDecoration(
                       color: AppColors.getSurface(context),
                       borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
                       border: Border.all(
                         color: AppColors.getPrimary(context).withValues(alpha: 0.1),
                         width: 1,
                       ),
                     ),
                     child: Text(
                       widget.segment.words.map((w) => w.text).join(' '),
                       style: TextStyle(
                         fontSize: 26 * s,
                         fontFamily: 'IndoPak-Nastaleeq', // Reusable font
                         color: AppColors.getTextPrimary(context),
                         height: 1.8,
                       ),
                       textDirection: TextDirection.rtl,
                       textAlign: TextAlign.center,
                     ),
                   ),
                   SizedBox(height: AppDesignSystem.space24 * s),
                   
                   // Info Section Header & Real Content Text
                   FutureBuilder<String?>(
                     future: _mode == 'tafsir' 
                        ? resourceService.getTafsirText(widget.segment.surahId, widget.segment.ayahNumber)
                        : resourceService.getTranslationText(widget.segment.surahId, widget.segment.ayahNumber),
                     builder: (context, snapshot) {
                        final content = snapshot.data;
                        final sourceName = _mode == 'tafsir' 
                            ? (resourceService.selectedTafsirName ?? 'Tafsir Jalalayn')
                            : (resourceService.selectedTranslationName ?? 'Translation');

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(),
                          ));
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 18 * s,
                                  decoration: BoxDecoration(
                                    color: AppColors.getPrimary(context),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                SizedBox(width: AppDesignSystem.space10 * s),
                                Text(
                                  sourceName,
                                  style: TextStyle(
                                    fontSize: 14 * s,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getPrimary(context),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppDesignSystem.space16 * s),
                            _buildContentArea(content ?? "Resource not selected or downloaded. Please go to Settings > Downloads to select a resource."),
                          ],
                        );
                     },
                   ),
                   
                   SizedBox(height: AppDesignSystem.space40 * s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: AppDesignSystem.space10 * s),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getPrimary(context) : AppColors.getSurfaceVariant(context),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14 * s,
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(String text) {
    final s = AppDesignSystem.getScaleFactor(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 16 * s,
        height: 1.7,
        color: AppColors.getTextPrimary(context),
        letterSpacing: 0.2,
      ),
    );
  }
}
