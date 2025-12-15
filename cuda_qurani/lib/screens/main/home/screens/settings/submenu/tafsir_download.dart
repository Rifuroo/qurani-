// lib/screens/main/home/screens/settings/submenu/tafsir_download.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/widgets/appbar.dart';

/// ==================== TAFSIR DOWNLOAD PAGE ====================
/// Halaman untuk memilih dan mendownload tafsir Quran

class TafsirDownloadPage extends StatefulWidget {
  const TafsirDownloadPage({Key? key}) : super(key: key);

  @override
  State<TafsirDownloadPage> createState() => _TafsirDownloadPageState();
}

class _TafsirDownloadPageState extends State<TafsirDownloadPage> {
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

  // Available tafsirs grouped by language
  final Map<String, List<Map<String, String>>> _availableTafsirs = {
    'العربية': [
      {'name': 'Tafsir Al-Jalalayn', 'language': 'العربية'},
      {'name': 'Tafsir Ibn Kathir', 'language': 'العربية'},
      {'name': 'Tafsir Al-Tabari', 'language': 'العربية'},
      {'name': 'Tafsir Al-Qurtubi', 'language': 'العربية'},
      {'name': 'Tafsir Al-Sa\'di', 'language': 'العربية'},
    ],
    'English': [
      {
        'name': 'A Brief Explanation of the Glorious Quran',
        'language': 'English',
      },
      {'name': 'Tafsir Ibn Kathir', 'language': 'English'},
      {'name': 'Tazkirul Quran', 'language': 'English'},
      {'name': 'Ma\'ariful Qur\'an', 'language': 'English'},
    ],
    'Bahasa Indonesia': [
      {'name': 'Tafsir Al-Saadi', 'language': 'Bahasa Indonesia'},
      {
        'name': 'Al-Mukhtasar in Interpreting the Noble Quran',
        'language': 'Bahasa Indonesia',
      },
    ],
    'বাংলা': [
      {'name': 'Tafsir Ahsanul Bayaan', 'language': 'বাংলা'},
      {'name': 'Tafsir Abu Bakr Zakaria', 'language': 'বাংলা'},
    ],
    'اردو': [
      {'name': 'Tafheem-ul-Quran', 'language': 'اردو'},
      {'name': 'Tafsir Ahsanul Bayan', 'language': 'اردو'},
    ],
    'Türkçe': [
      {'name': 'Elmalılı Hamdi Yazır Tefsiri', 'language': 'Türkçe'},
    ],
    'فارسی': [
      {'name': 'Tafsir Noor', 'language': 'فارسی'},
      {'name': 'Tafsir Nemooneh', 'language': 'فارسی'},
    ],
    'Français': [
      {'name': 'Tafsir Al-Sa\'di', 'language': 'Français'},
    ],
    'Русский': [
      {'name': 'Tafsir Al-Muntakhab', 'language': 'Русский'},
    ],
    'Español': [
      {'name': 'Tafsir Al-Muyassar', 'language': 'Español'},
    ],
    'Italiano': [
      {'name': 'Tafsir Al-Jalalayn', 'language': 'Italiano'},
    ],
    'অসমীয়া': [
      {'name': 'Tafsir Ahsanul Bayaan', 'language': 'অসমীয়া'},
    ],
    'Bosanski': [
      {'name': 'Tefsir Ibn Kesir', 'language': 'Bosanski'},
    ],
    '日本語': [
      {'name': 'Tafsir Al-Muyassar', 'language': '日本語'},
    ],
    'Khmer': [
      {'name': 'Tafsir Al-Muyassar', 'language': 'Khmer'},
    ],
    'Kurdî': [
      {'name': 'Tefsîra Quranê', 'language': 'Kurdî'},
    ],
    'മലയാളം': [
      {'name': 'Tafsir Cheriyamudam Abdul Hammed', 'language': 'മലയാളം'},
    ],
    'Tagalog': [
      {'name': 'Tafsir Al-Muyassar', 'language': 'Tagalog'},
    ],
    'Tiếng Việt': [
      {'name': 'Tafsir Al-Muyassar', 'language': 'Tiếng Việt'},
    ],
  };

  void _toggleLanguageExpansion(String language) {
    setState(() {
      _expandedLanguages[language] = !(_expandedLanguages[language] ?? false);
    });
    AppHaptics.selection();
  }

  void _downloadTafsir(String name, String language) {
    // TODO: Implement download logic
    AppHaptics.light();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading: $name'),
        duration: const Duration(seconds: 2),
      ),
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
                  'tafsir.available_downloads_text',
                )
              : 'Available Downloads',
          style: TextStyle(
            fontSize: 14 * s * 0.9,
            fontWeight: AppTypography.medium,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppDesignSystem.space16 * s * 0.9),
        ..._availableTafsirs.entries.map((entry) {
          final language = entry.key;
          final tafsirs = entry.value;
          final isExpanded = _expandedLanguages[language] ?? false;

          return Padding(
            padding: EdgeInsets.only(bottom: AppDesignSystem.space16 * s * 0.9),
            child: _buildLanguageSection(language, tafsirs, isExpanded),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLanguageSection(
    String language,
    List<Map<String, String>> tafsirs,
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
            ...tafsirs.asMap().entries.map((entry) {
              final index = entry.key;
              final tafsir = entry.value;
              final isLast = index == tafsirs.length - 1;

              return Column(
                children: [
                  _buildTafsirItem(tafsir['name']!, tafsir['language']!),
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

  Widget _buildTafsirItem(String name, String language) {
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
            onTap: () => _downloadTafsir(name, language),
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
            ? LanguageHelper.tr(_translations, 'tafsir.tafsir_text')
            : 'Tafsir',
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
          children: [_buildAvailableDownloadsSection()],
        ),
      ),
    );
  }
}



