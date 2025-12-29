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
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('goal_current', current);
      await HomeWidget.saveWidgetData<int>('goal_target', target);
      await HomeWidget.saveWidgetData<String>('goal_type', goalType ?? 'verses');
      
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
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('ayah_arabic', arabicText);
      await HomeWidget.saveWidgetData<String>('ayah_translation', translationText);
      await HomeWidget.saveWidgetData<String>('ayah_reference', reference);
      await HomeWidget.saveWidgetData<int>('ayah_surah_id', surahId);
      await HomeWidget.saveWidgetData<int>('ayah_number', ayahNumber);
      
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
