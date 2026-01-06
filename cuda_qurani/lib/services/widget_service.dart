import 'package:cuda_qurani/core/providers/language_provider.dart';
import 'package:cuda_qurani/providers/theme_provider.dart';
import 'package:cuda_qurani/services/daily_ayah_service.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class WidgetService {
  static const String androidWidgetName = 'QuraniWidgetProvider';
  static const String androidGoalWidgetName = 'GoalWidgetProvider';
  static const String iosWidgetName = 'QuraniWidget';

  /// Updates the progress widget with current and target values.
  static Future<void> updateGoalWidget({
    required int current,
    required int target,
    String? goalType,
    required String titleText, // "Target Harian" / "Daily Goal"
    required String progressText, // "0/10 Ayat" / "0/10 Verses"
    BuildContext? context,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('goal_current', current);
      await HomeWidget.saveWidgetData<int>('goal_target', target);
      await HomeWidget.saveWidgetData<String>('goal_type', goalType ?? 'verses');
      await HomeWidget.saveWidgetData<String>('goal_title_text', titleText);
      await HomeWidget.saveWidgetData<String>('goal_progress_text', progressText);
      
      // Save current theme
      String themeStr = 'auto';
      if (context != null) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        if (themeProvider.themeMode == ThemeMode.light) themeStr = 'light';
        if (themeProvider.themeMode == ThemeMode.dark) themeStr = 'dark';
      }
      await HomeWidget.saveWidgetData<String>('app_theme', themeStr);
      
      await _updateWidget(androidName: androidGoalWidgetName);
    } catch (e) {
      print('WidgetService: Error updating goal widget: $e');
    }
  }

  /// Updates the Ayah of the Day widget.
  static Future<void> updateAyahWidget({
    required String arabicText,
    required String translationText,
    required String reference,
    required int surahId,
    required int ayahNumber,
    required String titleText, // "Ayah of the Day" / "Ayat Hari Ini"
    BuildContext? context,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('ayah_arabic', arabicText);
      await HomeWidget.saveWidgetData<String>('ayah_translation', translationText);
      await HomeWidget.saveWidgetData<String>('ayah_reference', reference);
      await HomeWidget.saveWidgetData<int>('ayah_surah_id', surahId);
      await HomeWidget.saveWidgetData<int>('ayah_number', ayahNumber);
      await HomeWidget.saveWidgetData<String>('ayah_title_text', titleText);
      
      // Save current theme
      String themeStr = 'auto';
      if (context != null) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        if (themeProvider.themeMode == ThemeMode.light) themeStr = 'light';
        if (themeProvider.themeMode == ThemeMode.dark) themeStr = 'dark';
      }
      await HomeWidget.saveWidgetData<String>('app_theme', themeStr);
      
      await _updateWidget(androidName: androidWidgetName);
    } catch (e) {
      print('WidgetService: Error updating ayah widget: $e');
    }
  }

  /// Centralized logic to refresh both widgets with latest data.
  static Future<void> refreshAllWidgets(BuildContext context) async {
    try {
      // 1. Refresh Ayah Widget
      await DailyAyahService.refreshDailyAyah();

      // 2. Refresh Goal Widget if authenticated
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated && auth.userId != null) {
        final supabase = SupabaseService();
        final Map<String, dynamic>? data = await supabase.getHomePageData(auth.userId!);
        final goal = data?['today_goal'] as Map<String, dynamic>?;

        if (goal != null) {
          final current = goal['current_value'] as int? ?? 0;
          final target = goal['target_value'] as int? ?? 10;
          final type = goal['goal_type'] ?? 'verses';
          final hasGoal = goal['has_goal'] as bool? ?? false;

          if (hasGoal) {
            final language = Provider.of<LanguageProvider>(context, listen: false);
            final lang = language.currentLanguageCode;

            String title = 'Daily Goal';
            String unit = 'Verses';
            if (lang == 'id') {
              title = 'Target Harian';
              unit = 'Ayat';
            } else if (lang == 'ar') {
              title = 'الهدف اليومي';
              unit = 'آيات';
            }

            String progressValue = "$current/$target";
            if (lang == 'ar') {
              progressValue = "${DailyAyahService.toArabicDigits(current)}/${DailyAyahService.toArabicDigits(target)}";
            }

            await updateGoalWidget(
              context: context,
              current: current,
              target: target,
              goalType: type,
              titleText: title,
              progressText: "$progressValue $unit",
            );
          }
        }
      }
    } catch (e) {
      print('WidgetService: Error in refreshAllWidgets: $e');
    }
  }

  /// Triggers the native widget to refresh.
  static Future<void> _updateWidget({String? androidName}) async {
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(
        name: androidName ?? androidWidgetName,
        androidName: androidName ?? androidWidgetName,
      );
    } else if (Platform.isIOS) {
      await HomeWidget.updateWidget(
        name: iosWidgetName,
        iOSName: iosWidgetName,
      );
    }
  }
}
