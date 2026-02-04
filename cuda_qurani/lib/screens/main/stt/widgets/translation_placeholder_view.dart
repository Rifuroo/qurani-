import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';


class TranslationPlaceholderView extends StatelessWidget {
  final int surahId;
  final int ayahNumber;
  final String surahName;

  const TranslationPlaceholderView({
    super.key,
    required this.surahId,
    required this.ayahNumber,
    required this.surahName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextSecondary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.getBorderLight(context)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$surahId:$ayahNumber',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$surahName - Verse $ayahNumber',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Arabic Text
                  Text(
                    'عَلَىٰ صِرَاطٍ مُّسْتَقِيمٍ', // Hardcoded for demo/screenshot match
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'IndoPak-Nastaleeq',
                      fontSize: 32,
                      height: 2.0,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Translation Text
                  Text(
                    'upon the Straight Path.',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.getTextPrimary(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dr. Mustafa Khattab, The Clear Quran',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Settings Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.getBorderLight(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add additional translations for comparative study',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Translation Settings',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.settings, color: AppColors.getTextSecondary(context), size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Navigation
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.arrow_back_ios, size: 14, color: AppColors.getTextSecondary(context)),
                  label: Text('Next', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 16)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
                TextButton.icon(
                  onPressed: () {},
                  // Note: "Previous" is historically forward in Quran flow, but assuming UI direction
                  icon: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.getTextSecondary(context)), 
                  label: Text('Previous', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 16)),
                   style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                   // Reverse direction layout for RTL intuitive feel? 
                   // Screenshot shows "Next" on Left, "Previous" on Right. Keeping as requested.
                ).styleWith(direction: TextDirection.rtl), 
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension ButtonParams on TextButton {
  Widget styleWith({required TextDirection direction}) {
    return Directionality(textDirection: direction, child: this);
  }
}
