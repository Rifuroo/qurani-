// lib/core/utils/language_helper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';

/// ==================== LANGUAGE HELPER ====================
/// Global helper untuk akses translations dengan mudah di semua halaman
/// 
/// Cara pakai:
/// 1. Load translations dulu di initState atau di FutureBuilder
/// 2. Akses dengan tr('key.nested') atau trParams('key', {'param': 'value'})

class LanguageHelper {

  /// Load translation (alias untuk loadFrom)
  /// Example: await LanguageHelper.loadTranslations(context, 'settings/appearances')
  static Future<Map<String, dynamic>> loadTranslations(
    BuildContext context,
    String path,
  ) async {
    return await loadFrom(context, path);
  }
  /// Get translation dengan key
  /// Example: tr(translations, 'home.welcome')
  static String tr(Map<String, dynamic> translations, String key) {
    final provider = LanguageProvider();
    return provider.translate(translations, key);
  }

  /// Get translation dengan parameters
  /// Example: trParams(translations, 'home.greeting', {'name': 'John'})
  static String trParams(
    Map<String, dynamic> translations,
    String key,
    Map<String, String> params,
  ) {
    final provider = LanguageProvider();
    return provider.translate(translations, key, params: params);
  }

  /// Load translation dari context
  /// Example: await LanguageHelper.loadFrom(context, 'settings/appearances')
  static Future<Map<String, dynamic>> loadFrom(
    BuildContext context,
    String path,
  ) async {
    final provider = Provider.of<LanguageProvider>(context, listen: false);
    return await provider.loadTranslation(path);
  }

  /// Get current language code
  static String getCurrentLanguage(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context, listen: false);
    return provider.currentLanguageCode;
  }

  /// Convert numbers to Arabic-Indic digits (٠-٩)
  static String toIndoPakDigits(int number) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final chars = number.toString().split('');
    final buffer = StringBuffer();
    for (var c in chars) {
      final index = western.indexOf(c);
      if (index != -1) {
        buffer.write(arabic[index]);
      } else {
        buffer.write(c);
      }
    }
    return buffer.toString();
  }
}

/// Extension untuk memudahkan akses translations di BuildContext
extension TranslationExtension on BuildContext {
  /// Load translations
  /// Example: await context.loadTranslations('home/home')
  Future<Map<String, dynamic>> loadTranslations(String path) async {
    return await LanguageHelper.loadFrom(this, path);
  }

  /// Get current language
  String get currentLanguage => LanguageHelper.getCurrentLanguage(this);
}