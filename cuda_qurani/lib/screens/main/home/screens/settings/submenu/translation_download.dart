// lib/screens/main/home/screens/settings/submenu/translation_download.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== TRANSLATION DOWNLOAD PAGE ====================
/// Halaman untuk memilih dan mendownload terjemahan Quran

class TranslationDownloadPage extends StatefulWidget {
  const TranslationDownloadPage({Key? key}) : super(key: key);

  @override
  State<TranslationDownloadPage> createState() =>
      _TranslationDownloadPageState();
}

class _TranslationDownloadPageState extends State<TranslationDownloadPage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/downloads');
    setState(() {
      _translations = trans;
    });
  }

  // Track which language sections are expanded
  final Map<String, bool> _expandedLanguages = {};

  // Downloaded translations
  final List<Map<String, String>> _downloadedTranslations = [
    {
      'name': 'Dr. Mustafa Khattab, The Clear Quran',
      'language': 'English',
      'languageCode': 'english',
    },
  ];

  // Available translations grouped by language
  final Map<String, List<Map<String, String>>> _availableTranslations = {
    'English': [
      {'name': 'Dr. Mustafa Khattab, The Clear Quran', 'language': 'English'},
      {'name': 'Sahih International', 'language': 'English'},
      {'name': 'Pickthall', 'language': 'English'},
    ],
    'Bahasa Indonesia': [
      {
        'name': 'Indonesian Islamic affairs ministry',
        'language': 'Bahasa Indonesia',
      },
      {'name': 'King Fahad Quran Complex', 'language': 'Bahasa Indonesia'},
      {'name': 'The Sabiq company', 'language': 'Bahasa Indonesia'},
    ],
    'Bahasa Melayu': [
      {'name': 'Syeikh Abdullah Muhammad Basmeih', 'language': 'Bahasa Melayu'},
    ],
    'বাংলা': [
      {'name': 'Fathul Majid', 'language': 'বাংলা'},
      {'name': 'Sheikh Mujibur Rahman', 'language': 'বাংলা'},
    ],
    'اردو': [
      {'name': 'Maulana Fateh Muhammad Jalandhari', 'language': 'اردو'},
      {'name': 'Ahmed Raza Khan', 'language': 'اردو'},
    ],
    'Türkçe': [
      {'name': 'Diyanet İşleri', 'language': 'Türkçe'},
      {'name': 'Elmalılı Hamdi Yazır', 'language': 'Türkçe'},
    ],
    'فارسی': [
      {'name': 'Hussain Ansarian', 'language': 'فارسی'},
      {'name': 'Makarem Shirazi', 'language': 'فارسی'},
    ],
    'Hausa': [
      {'name': 'Abubakar Mahmud Gumi', 'language': 'Hausa'},
    ],
    'Kiswahili': [
      {'name': 'Ali Muhsin Al-Barwani', 'language': 'Kiswahili'},
    ],
    'Français': [
      {'name': 'Muhammad Hamidullah', 'language': 'Français'},
      {'name': 'Rashid Maash', 'language': 'Français'},
    ],
    'پښتو': [
      {'name': 'Zakaria Abasin', 'language': 'پښتو'},
    ],
    'Русский': [
      {'name': 'Elmir Kuliev', 'language': 'Русский'},
      {'name': 'Kuliev and Osmanov', 'language': 'Русский'},
    ],
    'Español': [
      {'name': 'Abdel Ghani Navio', 'language': 'Español'},
      {'name': 'Muhammad Isa García', 'language': 'Español'},
    ],
    'हिन्दी': [
      {
        'name': 'Suhel Farooq Khan and Saifur Rahman Nadwi',
        'language': 'हिन्दी',
      },
    ],
    'Uzbek': [
      {'name': 'Muhammad Sodik Muhammad Yusuf', 'language': 'Uzbek'},
    ],
  };

  void _toggleLanguageExpansion(String language) {
    setState(() {
      _expandedLanguages[language] = !(_expandedLanguages[language] ?? false);
    });
    AppHaptics.selection();
  }

  void _downloadTranslation(String name, String language) {
    // TODO: Implement download logic
    AppHaptics.light();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading: $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDownloadedSection() {
    final s = AppDesignSystem.getScaleFactor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'translation.downloaded_text')
              : 'Downloaded',
          style: TextStyle(
            fontSize: 14 * s * 0.9,
            fontWeight: AppTypography.medium,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppDesignSystem.space16 * s * 0.9),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space16 * s * 0.9,
            vertical: AppDesignSystem.space16 * s * 0.9,
          ),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(
              AppDesignSystem.radiusMedium * s * 0.9,
            ),
            border: Border.all(
              color: AppColors.borderLight,
              width: 1.0 * s * 0.9,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _downloadedTranslations[0]['name']!,
                style: TextStyle(
                  fontSize: 16 * s * 0.9,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4 * s * 0.9),
              Text(
                _downloadedTranslations[0]['language']!,
                style: TextStyle(
                  fontSize: 14 * s * 0.9,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableDownloadsSection() {
    final s = AppDesignSystem.getScaleFactor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(
                  _translations,
                  'translation.available_downloads_text',
                )
              : 'Available Downloads',
          style: TextStyle(
            fontSize: 14 * s * 0.9,
            fontWeight: AppTypography.medium,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppDesignSystem.space16 * s * 0.9),
        ..._availableTranslations.entries.map((entry) {
          final language = entry.key;
          final translations = entry.value;
          final isExpanded = _expandedLanguages[language] ?? false;

          return Padding(
            padding: EdgeInsets.only(bottom: AppDesignSystem.space16 * s * 0.9),
            child: _buildLanguageSection(language, translations, isExpanded),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLanguageSection(
    String language,
    List<Map<String, String>> translations,
    bool isExpanded,
  ) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(
          AppDesignSystem.radiusMedium * s * 0.9,
        ),
        border: Border.all(color: AppColors.borderLight, width: 1.0 * s * 0.9),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleLanguageExpansion(language),
            borderRadius: BorderRadius.circular(
              AppDesignSystem.radiusMedium * s * 0.9,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDesignSystem.space16 * s * 0.9,
                vertical: AppDesignSystem.space16 * s * 0.9,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      language,
                      style: TextStyle(
                        fontSize: 16 * s * 0.9,
                        fontWeight: AppTypography.regular,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 24 * s * 0.9,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(
              height: 1,
              thickness: 1 * s * 0.9,
              color: AppColors.borderLight,
            ),
            ...translations.asMap().entries.map((entry) {
              final index = entry.key;
              final translation = entry.value;
              final isLast = index == translations.length - 1;

              return Column(
                children: [
                  _buildTranslationItem(
                    translation['name']!,
                    translation['language']!,
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1 * s * 0.9,
                      color: AppColors.borderLight,
                    ),
                ],
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildTranslationItem(String name, String language) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s * 0.9,
        vertical: AppDesignSystem.space16 * s * 0.9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16 * s * 0.9,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4 * s * 0.9),
                Text(
                  language,
                  style: TextStyle(
                    fontSize: 14 * s * 0.9,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _downloadTranslation(name, language),
            borderRadius: BorderRadius.circular(20 * s * 0.9),
            child: Container(
              width: 40 * s * 0.9,
              height: 40 * s * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textPrimary,
              ),
              child: Icon(
                Icons.arrow_downward,
                size: 20 * s * 0.9,
                color: AppColors.getSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: SettingsAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'translation.translation_text')
            : 'Translation',
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
          children: [
            _buildDownloadedSection(),
            SizedBox(height: AppDesignSystem.space24 * s * 0.9),
            _buildAvailableDownloadsSection(),
          ],
        ),
      ),
    );
  }
}



