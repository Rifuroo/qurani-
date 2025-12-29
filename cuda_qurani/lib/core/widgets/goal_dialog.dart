import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/services/widget_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GoalDialog extends StatefulWidget {
  final String initialType;
  final int initialTarget;
  final String userId;

  const GoalDialog({
    Key? key,
    required this.initialType,
    required this.initialTarget,
    required this.userId,
  }) : super(key: key);

  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  late String _selectedType;
  late int _targetValue;
  bool _isSaving = false;
  Map<String, dynamic> _translations = {};
  late TextEditingController _controller;
  final int _maxVerses = 999;

  final List<Map<String, String>> _goalTypes = [
    {'id': 'verses', 'icon': '📖'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = 'verses';
    _targetValue = widget.initialTarget > 0 
        ? widget.initialTarget.clamp(1, _maxVerses) 
        : 1;
    _controller = TextEditingController(text: _targetValue.toString());
    _loadTranslations();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _getMaxTarget(String type) {
    if (type == 'minutes') return 60;
    if (type == 'pages') return 30;
    return 50; // verses default
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('home/home');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

  String _t(String key) {
    if (_translations.isEmpty) return key.split('.').last;
    return LanguageHelper.tr(_translations, key);
  }

  Future<void> _saveGoal() async {
    setState(() => _isSaving = true);
    
    try {
      final success = await SupabaseService().setUserGoal(
        widget.userId,
        _selectedType,
        _targetValue,
      );

      if (mounted) {
        if (success) {
          // Sync with Widget
          WidgetService.updateGoalWidget(
            current: 0, // Reset current progress in widget if goal changed? 
            // Actually, we should probably fetch current progress first, 
            // but for now, we just update the target.
            target: _targetValue,
            goalType: _selectedType,
          );

          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('home.goal_saved_success_text') ?? 'Goal saved successfully!'),
              backgroundColor: AppColors.getSuccess(context),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('home.goal_save_failed_text') ?? 'Failed to save goal'),
              backgroundColor: AppColors.getError(context),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.getError(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDesignSystem.space24 * s,
        AppDesignSystem.space16 * s,
        AppDesignSystem.space24 * s,
        MediaQuery.of(context).viewInsets.bottom + AppDesignSystem.space32 * s,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.radiusXLarge * s),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40 * s,
              height: 4 * s,
              margin: EdgeInsets.only(bottom: AppDesignSystem.space24 * s),
              decoration: BoxDecoration(
                color: AppColors.getBorderLight(context),
                borderRadius: BorderRadius.circular(2 * s),
              ),
            ),
          ),
          Text(
            _t('home.set_goal_text'),
            style: AppTypography.h2(
              context,
              weight: AppTypography.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          AppMargin.gap(context),
          // Removed Type Selection Row
          AppMargin.gapLarge(context),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('home.target_value_text') ?? 'Target Value',
                style: AppTypography.title(
                  context,
                  weight: AppTypography.semiBold,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              Container(
                width: 100 * s,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppTypography.title(
                    context,
                    weight: AppTypography.bold,
                    color: AppColors.getPrimary(context),
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
                    filled: true,
                    fillColor: AppColors.getPrimary(context).withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: _t('home.$_selectedType'),
                    suffixStyle: AppTypography.caption(
                      context,
                      color: AppColors.getPrimary(context),
                    ),
                  ),
                  onChanged: (value) {
                    final newVal = int.tryParse(value);
                    if (newVal != null) {
                      setState(() {
                        _targetValue = newVal.clamp(1, _maxVerses);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          AppMargin.gap(context),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.getPrimary(context),
              inactiveTrackColor: AppColors.getBorderLight(context),
              thumbColor: AppColors.getPrimary(context),
              overlayColor: AppColors.getPrimary(context).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _targetValue.toDouble().clamp(1.0, _maxVerses.toDouble()),
              min: 1,
              max: _maxVerses.toDouble(),
              divisions: _maxVerses - 1,
              onChanged: (value) {
                setState(() {
                  _targetValue = value.round();
                  _controller.text = _targetValue.toString();
                });
              },
            ),
          ),
          AppMargin.gapXLarge(context),
          SizedBox(
            width: double.infinity,
            height: 56 * s,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimary(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 24 * s,
                      height: 24 * s,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      _t('home.save_goal_text') ?? 'Save Goal',
                      style: AppTypography.title(
                        context,
                        weight: AppTypography.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
