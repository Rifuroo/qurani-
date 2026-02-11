// lib/screens/main/home/screens/settings/submenu/tafsir_download.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/services/quran_resource_service.dart';
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
  final Map<String, bool> _downloadedTafsirs = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _checkDownloads();
  }

  Future<void> _checkDownloads() async {
    for (var entry in _availableTafsirs.entries) {
      for (var tafsir in entry.value) {
        final isDownloaded = await Provider.of<QuranResourceService>(context, listen: false).isDownloaded(
          'tafsir',
          tafsir['name']!,
          tafsir['language']!,
        );
        setState(() {
          _downloadedTafsirs['${tafsir['id']}_${tafsir['name']}'] = isDownloaded;
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

  // Available tafsirs grouped by language
  // NOTE: Added 'id' to matches what we have in assets
  final Map<String, List<Map<String, String>>> _availableTafsirs = {
    'العربية': [
      {'id': '23', 'name': 'Tafseer Al-Qurtubi', 'language': 'العربية'},
      {'id': '37', 'name': 'Tafsir Al-Tabari', 'language': 'العربية'},
      {'id': '38', 'name': 'Tafsir Al-Muyassar', 'language': 'العربية'},
      {'id': '523', 'name': 'Tafsir Jalalayn', 'language': 'العربية'},
    ],
    'English': [
      {'id': '35', 'name': 'Tafsir Ibn Kathir', 'language': 'English'},
      {'id': '34', 'name': 'Maarif-ul-Quran', 'language': 'English'},
      {'id': '42', 'name': 'Tazkirul Quran', 'language': 'English'},
      {'id': '266', 'name': 'Al-Mukhtasar', 'language': 'English'},
    ],
    'Bahasa Indonesia': [
      {'id': '503', 'name': 'Tafsir As-Saadi', 'language': 'Bahasa Indonesia'},
      {'id': '260', 'name': 'Al-Mukhtasar', 'language': 'Bahasa Indonesia'},
      {'id': '41', 'name': 'Tafsir Jalalayn', 'language': 'Bahasa Indonesia'},
    ],
    'বাংলা': [
      {'id': '32', 'name': 'Ahsanul Bayaan', 'language': 'বাংলা'},
      {'id': '33', 'name': 'Abu Bakr Zakaria', 'language': 'বাংলা'},
    ],
    'اردو': [
      {'id': '29', 'name': 'Bayan ul Quran', 'language': 'اردو'},
      {'id': '30', 'name': 'Tafsir Ibn Kathir', 'language': 'اردو'},
    ],
    'Bosanski': [
      {'id': '252', 'name': 'Tefsir Ibn Kesir', 'language': 'Bosanski'},
    ],
    'Русский': [
      {'id': '262', 'name': 'Al-Mukhtasar', 'language': 'Русский'},
      {'id': '307', 'name': 'Tafsir Ibne Kathir', 'language': 'Русский'},
      {'id': '36', 'name': 'Tafseer Al Saddi', 'language': 'Русский'},
    ],
    'Türkçe': [
      {'id': '306', 'name': 'Tafsir Ibne Kathir', 'language': 'Türkçe'},
      {'id': '258', 'name': 'Al-Mukhtasar', 'language': 'Türkçe'},
    ],
    'Kurdî': [
      {'id': '40', 'name': 'Rebar Kurdish Tafsir', 'language': 'Kurdî'},
    ],
  };

  void _toggleLanguageExpansion(String language) {
    setState(() {
      _expandedLanguages[language] = !(_expandedLanguages[language] ?? false);
    });
    AppHaptics.selection();
  }

  void _downloadTafsir(String id, String name, String language) async {
    final resourceService = Provider.of<QuranResourceService>(context, listen: false);
    final key = '${id}_$name';
    
    final sanitizedName = name.replaceAll(' ', '_').replaceAll('/', '_').replaceAll("'", "").replaceAll('"', '').replaceAll(':', '');
    final sanitizedLang = language.replaceAll(' ', '_').replaceAll('/', '_');

    if (_downloadedTafsirs[key] == true) {
      resourceService.loadTafsir(id, '${sanitizedName}_$sanitizedLang');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected Tafsir: $name'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Real download logic (simulated/actual via service)
    AppHaptics.light();
    await resourceService.downloadResource('tafsir', id, name, language);
    
    // Auto-load after download
    resourceService.loadTafsir(id, '${sanitizedName}_$sanitizedLang');

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
                  'tafsir.available_downloads_text',
                )
              : 'Available Downloads',
          style: TextStyle(
            fontSize: 14 * s * 0.9,
            fontWeight: AppTypography.medium,
            color: AppColors.getTextSecondary(context),
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
            ...tafsirs.asMap().entries.map((entry) {
              final index = entry.key;
              final tafsir = entry.value;
              final isLast = index == tafsirs.length - 1;

              return Column(
                children: [
                  _buildTafsirItem(tafsir['id']!, tafsir['name']!, tafsir['language']!),
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

  Widget _buildTafsirItem(String id, String name, String language) {
    final s = AppDesignSystem.getScaleFactor(context);
    final resourceService = Provider.of<QuranResourceService>(context);
    final key = '${id}_$name';
    final isDownloaded = _downloadedTafsirs[key] ?? false;
    final isSelected = resourceService.selectedTafsirId == id;
    final downloadProgress = resourceService.downloadProgress[key];
    final isDownloading = downloadProgress != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDownloading ? null : () => _downloadTafsir(id, name, language),
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



