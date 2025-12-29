import 'package:home_widget/home_widget.dart';
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
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('goal_current', current);
      await HomeWidget.saveWidgetData<int>('goal_target', target);
      await HomeWidget.saveWidgetData<String>('goal_type', goalType ?? 'verses');
      await HomeWidget.saveWidgetData<String>('goal_title_text', titleText);
      await HomeWidget.saveWidgetData<String>('goal_progress_text', progressText);
      
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
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('ayah_arabic', arabicText);
      await HomeWidget.saveWidgetData<String>('ayah_translation', translationText);
      await HomeWidget.saveWidgetData<String>('ayah_reference', reference);
      await HomeWidget.saveWidgetData<int>('ayah_surah_id', surahId);
      await HomeWidget.saveWidgetData<int>('ayah_number', ayahNumber);
      await HomeWidget.saveWidgetData<String>('ayah_title_text', titleText);
      
      await _updateWidget(androidName: androidWidgetName);
    } catch (e) {
      print('WidgetService: Error updating ayah widget: $e');
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
