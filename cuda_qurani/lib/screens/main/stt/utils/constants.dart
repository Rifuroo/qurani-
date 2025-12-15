// lib\screens\main\stt\utils\constants.dart

import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

// ==================== UI & THEME ====================
// Theme-aware color getters - use these instead of hardcoded colors

Color getBackgroundColor(BuildContext context) {
  return AppColors.getBackground(context);
}

Color getPrimaryColor(BuildContext context) {
  return AppColors.getPrimary(context);
}

Color getCorrectColor(BuildContext context) {
  return AppColors.getSuccess(context);
}

Color getErrorColor(BuildContext context) {
  return AppColors.getError(context);
}

Color getWarningColor(BuildContext context) {
  return AppColors.getWarning(context);
}

Color getUnreadColor(BuildContext context) {
  // Unread color doesn't have dark theme variant, use textTertiary for consistency
  return AppColors.getTextTertiary(context);
}

Color getListeningColor(BuildContext context) {
  // Use textPrimary for listening color to ensure visibility in both themes
  return AppColors.getTextPrimary(context);
}

Color getAccentColor(BuildContext context) {
  // Accent color doesn't have dark theme variant, use primary for consistency
  return AppColors.getPrimary(context);
}

Color getSkippedColor(BuildContext context) {
  // Skipped color doesn't have dark theme variant, use textTertiary for consistency
  return AppColors.getTextTertiary(context);
}

// Legacy constants for backward compatibility (deprecated - use getters above)
@Deprecated('Use getBackgroundColor(context) instead')
const Color backgroundColor = Color.fromARGB(255, 255, 255, 255);

@Deprecated('Use getPrimaryColor(context) instead')
const Color primaryColor = Color(0xFF247C64);

@Deprecated('Use getCorrectColor(context) instead')
const Color correctColor = Color(0xFF27AE60);

@Deprecated('Use getErrorColor(context) instead')
const Color errorColor = Color(0xFFE74C3C);

@Deprecated('Use getWarningColor(context) instead')
const Color warningColor = Color(0xFFF39C12);

@Deprecated('Use getUnreadColor(context) instead')
const Color unreadColor = Color(0xFFBDC3C7);

@Deprecated('Use getListeningColor(context) instead')
const Color listeningColor = Color.fromARGB(255, 0, 0, 0);

@Deprecated('Use getAccentColor(context) instead')
const Color accentColor = Color(0xFF9B59B6);

@Deprecated('Use getSkippedColor(context) instead')
const Color skippedColor = Color(0xFF95A5A6);

// ==================== PRE-LOADING CACHE ====================
// ✅ OPTIMIZED: Increased cache radius and size for faster mushaf loading (Tarteel-style)
// ✅ CRITICAL: Large cache to prevent re-loading when swiping back and forth
const int cacheRadius = 20; // Preload ±20 pages for ultra-fast swipe
const int maxCacheSize = 500; // Increased to 500 (keep ALL visited pages in memory - no re-loading!)
const int quranServiceCacheSize = 500; // Increased for faster preload (dynamic: 604 QPC / 610 IndoPak)
const int cacheEvictionThreshold = 600; // Only evict when cache exceeds this (very large buffer)
const int cacheEvictionDistance = 300; // Only evict pages > 300 pages away from current

// ==================== PERFORMANCE TUNING ====================
const double averageAyatHeight = 170.0;
const int listViewCacheExtent = 500;
