import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';


class TafsirPlaceholderView extends StatelessWidget {
  final int surahId;
  final int ayahNumber;
  final String surahName;

  const TafsirPlaceholderView({
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
                   // Arabic Text
                  Text(
                    'لِتُنذِرَ قَوْمًا مَّا أُنذِرَ آبَاؤُهُمْ فَهُمْ غَافِلُونَ', // Hardcoded for demo
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'IndoPak-Nastaleeq',
                      fontSize: 28,
                      height: 2.0,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceVariant(context),
                      border: Border.all(color: AppColors.getBorderLight(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.getTextSecondary(context), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are reading a tafsir of a group of verses from 36:1 to 36:12',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextPrimary(context),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tafsir Text
                  Text(
                    '"Ya, sin. Demi al-Qur`an yang penuh hikmah, sesungguhnya kamu benar-benar salah seorang dari rasul-rasul, (yang berada) di atas jalan yang lurus, (sebagai wahyu) yang diturunkan oleh Yang Mahaperkasa lagi Maha Penyayang. Agar kamu memberi peringatan kepada kaum yang bapak-bapak mereka belum pernah diberi peringatan, karena mereka lalai. Sungguh telah pasti berlaku per-kataan (ketentuan Allah) terhadap kebanyakan mereka, karena mereka tidak beriman. Sesungguhnya Kami telah memasang be-lenggu di leher mereka, lalu tangan mereka (diangkat) ke dagu, maka karena itu mereka tertengadah. Dan Kami adakan di ha-dapan mereka dinding dan di belakang mereka juga dinding, dan Kami tutup (mata) mereka sehingga mereka tidak dapat melihat. Sama saja bagi mereka apakah kamu memberi peringatan kepada mereka ataukah kamu tidak memberi peringatan kepada mereka, mereka tidak akan beriman. Sesungguhnya kamu hanya memberi peringatan kepada orang-orang yang mau mengikuti peringatan dan takut kepada Yang Maha Pemurah walaupun dia tidak me-lihatNya. Maka berilah mereka kabar gembira dengan ampunan dan pahala yang mulia."',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.getTextPrimary(context),
                      height: 1.6,
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
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.arrow_back_ios, size: 14, color: AppColors.getTextSecondary(context)),
                    label: Text('Previous', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 16)),
                     style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
