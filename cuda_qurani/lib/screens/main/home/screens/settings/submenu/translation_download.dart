// lib/screens/main/home/screens/settings/submenu/translation_download.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
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
  final Map<String, bool> _downloadedTranslationsMap = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _checkDownloads();
  }

  Future<void> _checkDownloads() async {
    for (var entry in _availableTranslations.entries) {
      for (var translation in entry.value) {
        final isDownloaded = await Provider.of<QuranResourceService>(context, listen: false).isDownloaded(
          'translation',
          translation['name']!,
          translation['language']!,
        );
        setState(() {
          _downloadedTranslationsMap['${translation['id']}_${translation['name']}'] = isDownloaded;
        });
      }
    }
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

  // Available translations grouped by language
  final Map<String, List<Map<String, String>>> _availableTranslations = {
    'English': [
      {'id': '193', 'name': 'Sahih International', 'language': 'English'},
      {'id': '145', 'name': 'Pickthall', 'language': 'English'},
    ],
    'Bahasa Indonesia': [
      {'id': '224', 'name': 'Islamic affairs ministry', 'language': 'Bahasa Indonesia'},
      {'id': '194', 'name': 'Sabiq', 'language': 'Bahasa Indonesia'},
      {'id': '554', 'name': 'King Fahad Indonesian Translation', 'language': 'Bahasa Indonesia'},
    ],
    'Bahasa Melayu': [
      {'id': '292', 'name': 'Basmeih', 'language': 'Bahasa Melayu'},
    ],
    'বাংলা': [
      {'id': '229', 'name': 'Fathul Majid', 'language': 'বাংলা'},
      {'id': '186', 'name': 'Sheikh Mujibur Rahman', 'language': 'বাংলা'},
    ],
    'اردو': [
      {'id': '218', 'name': 'Jalandhari', 'language': 'اردو'},
      {'id': '284', 'name': 'Ahmed Raza Khan', 'language': 'اردو'},
    ],
    'Türkçe': [
      {'id': '148', 'name': 'Diyanet İşleri', 'language': 'Türkçe'},
      {'id': '233', 'name': 'Elmalılı Hamdi Yazır', 'language': 'Türkçe'},
    ],
    'فارسی': [
      {'id': '169', 'name': 'Ansarian', 'language': 'فارسی'},
      {'id': '188', 'name': 'Makarem Shirazi', 'language': 'فارسی'},
    ],
    'Hausa': [
      {'id': '128', 'name': 'Gumi', 'language': 'Hausa'},
    ],
    'Swahili': [
      {'id': '139', 'name': 'Barwani', 'language': 'Swahili'},
    ],
    'Français': [
      {'id': '227', 'name': 'Hamidullah', 'language': 'Français'},
      {'id': '295', 'name': 'Rashid Maash', 'language': 'Français'},
    ],
    'پښتو': [
      {'id': '164', 'name': 'Zakaria Abasin', 'language': 'پښتو'},
    ],
    'Русский': [
      {'id': '136', 'name': 'Kuliev', 'language': 'Русский'},
      {'id': '271', 'name': 'Osmanov', 'language': 'Русский'},
    ],
    'Español': [
      {'id': '223', 'name': 'Abdel Ghani Navio', 'language': 'Español'},
      {'id': '152', 'name': 'Isa García', 'language': 'Español'},
    ],
    'Uzbek': [
      {'id': '168', 'name': 'Sodik Muhammad Yusuf', 'language': 'Uzbek'},
    ],
  };

  void _toggleLanguageExpansion(String language) {
    setState(() {
      _expandedLanguages[language] = !(_expandedLanguages[language] ?? false);
    });
    AppHaptics.selection();
  }

  void _downloadTranslation(String id, String name, String language) async {
    final resourceService = Provider.of<QuranResourceService>(context, listen: false);
    final key = '${id}_$name';
    
    final sanitizedName = name.replaceAll(' ', '_').replaceAll('/', '_').replaceAll("'", "").replaceAll('"', '').replaceAll(':', '');
    final sanitizedLang = language.replaceAll(' ', '_').replaceAll('/', '_');

    if (_downloadedTranslationsMap[key] == true) {
      resourceService.loadTranslation(id, '${sanitizedName}_$sanitizedLang');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected Translation: $name'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Real download logic (simulated/actual via service)
    AppHaptics.light();
    await resourceService.downloadResource('translation', id, name, language);
    
    // Auto-load after download
    resourceService.loadTranslation(id, '${sanitizedName}_$sanitizedLang');

    // Refresh status after download
    _checkDownloads();
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
            color: AppColors.getTextSecondary(context),
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
        border: Border.all(color: AppColors.getBorderLight(context), width: 1.0 * s * 0.9),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
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
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 24 * s * 0.9,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(
              height: 1,
              thickness: 1 * s * 0.9,
              color: AppColors.getBorderLight(context),
            ),
            ...translations.asMap().entries.map((entry) {
              final index = entry.key;
              final translation = entry.value;
              final isLast = index == translations.length - 1;

              return Column(
                children: [
                  _buildTranslationItem(
                    translation['id']!,
                    translation['name']!,
                    translation['language']!,
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1 * s * 0.9,
                      color: AppColors.getBorderLight(context),
                    ),
                ],
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildTranslationItem(String id, String name, String language) {
    final s = AppDesignSystem.getScaleFactor(context);
    final resourceService = Provider.of<QuranResourceService>(context);
    final key = '${id}_$name';
    final isDownloaded = _downloadedTranslationsMap[key] ?? false;
    final isSelected = resourceService.selectedTranslationId == id;
    final downloadProgress = resourceService.downloadProgress[key];
    final isDownloading = downloadProgress != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDownloading ? null : () => _downloadTranslation(id, name, language),
        child: Padding(
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
                        fontWeight: isSelected ? AppTypography.bold : AppTypography.regular,
                        color: isSelected ? AppColors.getPrimary(context) : AppColors.getTextPrimary(context),
                      ),
                    ),
                    SizedBox(height: 4 * s * 0.9),
                    Text(
                      language,
                      style: TextStyle(
                        fontSize: 14 * s * 0.9,
                        fontWeight: AppTypography.regular,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40 * s * 0.9,
                height: 40 * s * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDownloading 
                      ? AppColors.getPrimary(context).withValues(alpha: 0.1)
                      : (isDownloaded 
                          ? (isSelected ? AppColors.getPrimary(context) : AppColors.getPrimary(context).withValues(alpha: 0.2))
                          : AppColors.getBorderLight(context).withValues(alpha: 0.5)),
                ),
                child: isDownloading
                    ? Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: (downloadProgress == 0.0) ? null : downloadProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.getPrimary(context)),
                        ),
                      )
                    : Icon(
                        isDownloaded ? Icons.check : Icons.arrow_downward,
                        size: 20 * s * 0.9,
                        color: isDownloaded 
                            ? (isSelected ? Colors.white : AppColors.getPrimary(context))
                            : AppColors.getTextSecondary(context),
                      ),
              ),
            ],
          ),
        ),
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
            _buildAvailableDownloadsSection(),
          ],
        ),
      ),
    );
  }
}



