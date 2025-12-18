// lib/screens/main/home/screens/settings/widgets/tajweed_rules.dart
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/submenu/marking.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

/// ==================== TAJWEED RULES PAGE ====================
/// Halaman untuk menampilkan penjelasan aturan tajweed dengan warna

class TajweedRulesPage extends StatefulWidget {
  const TajweedRulesPage({Key? key}) : super(key: key);

  @override
  State<TajweedRulesPage> createState() => _TajweedRulesPageState();
}

class _TajweedRulesPageState extends State<TajweedRulesPage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('settings/tajweed_rules');
    setState(() {
      _translations = trans;
    });
  }

  // Track expanded state for each rule
  final Map<int, bool> _expandedStates = {};

  // Tajweed rules data
  List<TajweedRule> _getRules(BuildContext context) {
    return [
      TajweedRule(
        color: Color(0xFF8B2D2D), // Dark red
        titleKey: 'madd_text',
        titleSuffix: ' 6',
        subtitleKey: 'necessary_prolongation_text',
        descriptionKey: 'necessary_prolongation_desc',
      ),
      TajweedRule(
        color: Color(0xFFD81B60), // Pink/Magenta
        titleKey: 'madd_text',
        titleSuffix: ' 4 or 5',
        subtitleKey: 'obligatory_prolongation_text',
        descriptionKey: 'obligatory_prolongation_desc',
      ),
      TajweedRule(
        color: Color(0xFFFF8C42), // Orange
        titleKey: 'madd_text',
        titleSuffix: ' 2, 4, or 6',
        subtitleKey: 'permissible_prolongation_text',
        descriptionKey: 'permissible_prolongation_desc',
      ),
      TajweedRule(
        color: Color(0xFFB8860B), // Dark goldenrod/yellow-brown
        titleKey: 'madd_text',
        titleSuffix: ' 2',
        subtitleKey: 'normal_prolongation_text',
        descriptionKey: 'normal_prolongation_desc',
      ),
      TajweedRule(
        color: Color(0xFF4CAF50), // Green
        titleKey: 'ghunnah_text',
        titleSuffix: '',
        subtitleKey: 'nasalization_text',
        descriptionKey: 'nasalization_desc',
      ),
      TajweedRule(
        color: Color(0xFF00BCD4), // Light blue/Cyan
        titleKey: 'qalqala_text',
        titleSuffix: '',
        subtitleKey: 'echoing_sound_text',
        descriptionKey: 'echoing_sound_desc',
      ),
      TajweedRule(
        color: Color(0xFF1976D2), // Dark blue
        titleKey: 'tafkhim_text',
        titleSuffix: '',
        subtitleKey: 'emphatic_text',
        descriptionKey: 'emphatic_desc',
      ),
      TajweedRule(
        color: AppColors.getTextTertiary(context), // Grey - theme-aware
        titleKey: 'silent_text',
        titleSuffix: '',
        subtitleKey: 'unannounced_pronunciation_text',
        descriptionKey: 'unannounced_pronunciation_desc',
      ),
    ];
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedStates[index] = !(_expandedStates[index] ?? false);
    });
    AppHaptics.selection();
  }

  Widget _buildRuleItem(TajweedRule rule, int index, BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final isExpanded = _expandedStates[index] ?? false;

    // Get translated text
    final title = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, rule.titleKey)
        : rule.titleKey;
    final subtitle = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, rule.subtitleKey)
        : rule.subtitleKey;
    final description = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, rule.descriptionKey)
        : rule.descriptionKey;

    return Column(
      children: [
        InkWell(
          onTap: () => _toggleExpanded(index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDesignSystem.space16 * s * 0.9,
              vertical: AppDesignSystem.space16 * s * 0.9,
            ),
            child: Row(
              children: [
                // Color indicator circle
                Container(
                  width: 32 * s * 0.9,
                  height: 32 * s * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rule.color,
                  ),
                ),
                SizedBox(width: AppDesignSystem.space12 * s * 0.9),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title + rule.titleSuffix,
                        style: TextStyle(
                          fontSize: 16 * s * 0.9,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      SizedBox(height: 2 * s * 0.9),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14 * s * 0.9,
                          fontWeight: AppTypography.regular,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Expand/collapse icon
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
        // Expanded content
        if (isExpanded) ...[
          Divider(
            height: 1,
            thickness: 1 * s * 0.9,
            color: AppColors.getBorderLight(context),
          ),
          Padding(
            padding: EdgeInsets.all(AppDesignSystem.space16 * s * 0.9),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14 * s * 0.9,
                fontWeight: AppTypography.regular,
                color: AppColors.getTextPrimary(context),
                height: 1.5,
              ),
            ),
          ),
        ],
        // Divider between items (except last item)
        if (index < _getRules(context).length - 1)
          Divider(
            height: 1,
            thickness: 1 * s * 0.9,
            color: AppColors.getBorderLight(context),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final rules = _getRules(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.getTextPrimary(context),
            size: 24 * s * 0.9,
          ),
          onPressed: () {
            AppHaptics.light();
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const MarkingPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const begin = Offset(-0.03, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  var fadeAnimation = animation.drive(
                    Tween(
                      begin: 0.0,
                      end: 1.0,
                    ).chain(CurveTween(curve: curve)),
                  );

                  return FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                transitionDuration: AppDesignSystem.durationNormal,
              ),
            );
          },
        ),
        title: Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'tajweed_rules_text')
              : 'Tajweed Rules',
          style: TextStyle(
            fontSize: 18 * s * 0.9,
            fontWeight: AppTypography.semiBold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppDesignSystem.space20 * s * 0.9),
          children: [
            // Header description
            Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'tajweed_rules_desc')
                  : 'Tajweed is the set of rules governing the correct pronunciation and articulation of the Quranic text during recitation.',
              style: TextStyle(
                fontSize: 14 * s * 0.9,
                fontWeight: AppTypography.regular,
                color: AppColors.getTextSecondary(context),
                height: 1.5,
              ),
            ),
            SizedBox(height: AppDesignSystem.space12 * s * 0.9),
            // "Read our blog" link
            InkWell(
              onTap: () {
                // TODO: Navigate to blog
                AppHaptics.selection();
              },
              child: Text(
                _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'read_our_blog_text')
                    : 'Read our blog',
                style: TextStyle(
                  fontSize: 14 * s * 0.9,
                  fontWeight: AppTypography.regular,
                  color: AppColors.getTextSecondary(context),
                  decoration: TextDecoration.underline,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: AppDesignSystem.space20 * s * 0.9),
            // All rules in one container
            Container(
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusMedium * s * 0.9,
                ),
                border: Border.all(
                  color: AppColors.getBorderLight(context),
                  width: 1.0 * s * 0.9,
                ),
              ),
              child: Column(
                children: List.generate(rules.length, (index) {
                  return _buildRuleItem(rules[index], index, context);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Model class for Tajweed Rule
class TajweedRule {
  final Color color;
  final String titleKey;
  final String titleSuffix;
  final String subtitleKey;
  final String descriptionKey;

  TajweedRule({
    required this.color,
    required this.titleKey,
    required this.titleSuffix,
    required this.subtitleKey,
    required this.descriptionKey,
  });
}


