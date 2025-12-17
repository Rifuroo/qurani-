// lib/core/design_system/app_design_system.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ==================== CORE DESIGN SYSTEM ====================
/// Professional Design System yang SIAP DIGUNAKAN di SEMUA halaman
/// Mengikuti Material Design 3 dengan custom branding Qurani App

class AppDesignSystem {
  // ==================== SPACING (8pt Grid System) ====================
  static const double space0 = 0.0;
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space72 = 72.0;
  static const double space80 = 80.0;
  static const double space96 = 96.0;

  // ==================== BORDER RADIUS ====================
  static const double radiusXSmall = 4.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusXXLarge = 24.0;
  static const double radiusRound = 100.0;

  // ==================== ICON SIZES ====================
  static const double iconXSmall = 14.0;
  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  static const double iconXLarge = 32.0;
  static const double iconXXLarge = 40.0;
  static const double iconHuge = 48.0;

  // ==================== BUTTON SIZES ====================
  static const double buttonHeightSmall = 32.0;
  static const double buttonHeightMedium = 40.0;
  static const double buttonHeightLarge = 48.0;
  static const double buttonHeightXLarge = 56.0;

  // ==================== ELEVATION (Shadow) ====================
  static const double elevationNone = 0;
  static const double elevationLow = 1;
  static const double elevationMedium = 2;
  static const double elevationHigh = 4;
  static const double elevationXHigh = 8;

  // ==================== BORDER WIDTH ====================
  static const double borderThin = 0.5;
  static const double borderNormal = 1.0;
  static const double borderThick = 1.5;
  static const double borderXThick = 2.0;
  static const double borderXXThick = 3.0;

  // ==================== OPACITY LEVELS ====================
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.6;
  static const double opacityHigh = 0.87;
  static const double opacityFull = 1.0;

  // ==================== ANIMATION DURATIONS ====================
  static const Duration durationInstant = Duration(milliseconds: 100);
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationXSlow = Duration(milliseconds: 800);

  // ==================== RESPONSIVE BREAKPOINTS ====================
  static const double breakpointMobile = 600;
  static const double breakpointTablet = 900;
  static const double breakpointDesktop = 1200;
  static const double breakpointWide = 1600;

  // ==================== BASE SCREEN WIDTH (for scaling) ====================
  static const double baseWidth = 400.0; // iPhone 12/13 width

  // ==================== RESPONSIVE SCALING ====================
  
  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Calculate responsive scale factor based on screen width
  static double getScaleFactor(BuildContext context) {
    return screenWidth(context) / baseWidth;
  }

  /// Scale value responsively
  static double scale(BuildContext context, double value) {
    return value * getScaleFactor(context);
  }

  /// Scale EdgeInsets responsively
  static EdgeInsets scaleInsets(BuildContext context, EdgeInsets insets) {
    final s = getScaleFactor(context);
    return EdgeInsets.only(
      left: insets.left * s,
      top: insets.top * s,
      right: insets.right * s,
      bottom: insets.bottom * s,
    );
  }

  /// Scale BorderRadius responsively
  static BorderRadius scaleBorderRadius(BuildContext context, BorderRadius radius) {
    final s = getScaleFactor(context);
    return BorderRadius.only(
      topLeft: Radius.circular((radius.topLeft.x) * s),
      topRight: Radius.circular((radius.topRight.x) * s),
      bottomLeft: Radius.circular((radius.bottomLeft.x) * s),
      bottomRight: Radius.circular((radius.bottomRight.x) * s),
    );
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < breakpointMobile;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= breakpointMobile &&
        screenWidth(context) < breakpointDesktop;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= breakpointDesktop;
  }

  /// Get safe area padding
  static EdgeInsets safeArea(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get keyboard height
  static double keyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return keyboardHeight(context) > 0;
  }
}

/// ==================== COLOR SYSTEM ====================
class AppColors {
  // ==================== PRIMARY COLORS ====================
  static const Color primary = Color(0xFF247C64);
  static const Color primaryLight = Color(0xFF2D9A7E);
  static const Color primaryDark = Color(0xFF1B5D4C);
  static const Color primaryContainer = Color(0xFFE8F5F2);
  
  // ==================== SECONDARY COLORS ====================
  static const Color secondary = Color(0xFF4A90E2);
  static const Color secondaryLight = Color(0xFF6BA3E8);
  static const Color secondaryDark = Color(0xFF357ABD);
  static const Color secondaryContainer = Color(0xFFE3F2FD);

  // ==================== ACCENT COLORS ====================
  static const Color accent = Color(0xFF9B59B6);
  static const Color accentLight = Color(0xFFB07CC6);
  static const Color accentDark = Color(0xFF7D3C98);

  // ==================== SURFACE COLORS ====================
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAFAFA);
  static const Color surfaceContainerLowest = Color(0xFFF5F5F5);
  static const Color surfaceContainerLow = Color(0xFFF0F0F0);
  static const Color surfaceContainerMedium = Color(0xFFE8E8E8);
  static const Color surfaceContainerHigh = Color(0xFFE0E0E0);
  static const Color surfaceDim = Color(0xFFDEDEDE);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  
  // ==================== BACKGROUND COLORS ====================
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDim = Color(0xFFF5F5F5);

  // ==================== TEXT COLORS ====================
  static const Color textPrimary = Color(0xFF1C1C1C);
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color textTertiary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFF9E9E9E);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textInverse = Color(0xFFFFFFFF);
  
  // ==================== BORDER COLORS ====================
  static const Color borderLight = Color(0xFFF0F0F0);
  static const Color borderMedium = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFFBDBDBD);
  static const Color borderFocus = Color(0xFF247C64);
  static const Color borderError = Color(0xFFE74C3C);

  // ==================== SEMANTIC COLORS ====================
  static const Color success = Color(0xFF27AE60);
  static const Color successLight = Color(0xFF52C785);
  static const Color successDark = Color(0xFF1E8B4D);
  static const Color successContainer = Color(0xFFE8F7EE);

  static const Color error = Color(0xFFE74C3C);
  static const Color errorLight = Color(0xFFED6B5E);
  static const Color errorDark = Color(0xFFCF3A2D);
  static const Color errorContainer = Color(0xFFFDECEA);

  static const Color warning = Color(0xFFF39C12);
  static const Color warningLight = Color(0xFFF5B041);
  static const Color warningDark = Color(0xFFD68910);
  static const Color warningContainer = Color(0xFFFEF5E7);

  static const Color info = Color(0xFF3498DB);
  static const Color infoLight = Color(0xFF5DADE2);
  static const Color infoDark = Color(0xFF2874A6);
  static const Color infoContainer = Color(0xFFEBF5FB);

  // ==================== STATE COLORS ====================
  static const Color listening = Color(0xFF3498DB);
  static const Color correct = Color(0xFF27AE60);
  static const Color incorrect = Color(0xFFE74C3C);
  static const Color skipped = Color(0xFF95A5A6);
  static const Color unread = Color(0xFFBDC3C7);

  // ==================== OVERLAY COLORS ====================
  static const Color overlay = Color(0x80000000); // 50% black
  static const Color overlayLight = Color(0x40000000); // 25% black
  static const Color overlayDark = Color(0xB3000000); // 70% black
  static const Color scrim = Color(0x99000000); // 60% black

  // ==================== DIVIDER COLORS ====================
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerLight = Color(0xFFF0F0F0);
  static const Color dividerDim = Color(0xFFBDBDBD);

  // ==================== SHADOW COLORS ====================
  static Color shadowLight = const Color(0x1A000000); // 10% black
  static Color shadowMedium = const Color(0x33000000); // 20% black
  static Color shadowDark = const Color(0x4D000000); // 30% black

  // ==================== OPACITY VARIANTS ====================
  static Color primaryWithOpacity(double opacity) => primary.withValues(alpha: opacity);
  static Color secondaryWithOpacity(double opacity) => secondary.withValues(alpha: opacity);
  static Color surfaceWithOpacity(double opacity) => surface.withValues(alpha: opacity);
  static Color textWithOpacity(double opacity) => textPrimary.withValues(alpha: opacity);
  static Color blackWithOpacity(double opacity) => Colors.black.withValues(alpha: opacity);
  static Color whiteWithOpacity(double opacity) => Colors.white.withValues(alpha: opacity);

  // ==================== GRADIENT COLORS ====================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [error, errorLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== SHIMMER COLORS (for loading) ====================
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // ==================== DARK THEME COLORS ====================
  // Primary Colors (same for dark theme)
  static const Color primaryDarkTheme = Color(0xFF2D9A7E);
  static const Color primaryLightDarkTheme = Color(0xFF3FCCB8);
  static const Color primaryDarkDarkTheme = Color(0xFF1B5D4C);
  static const Color primaryContainerDarkTheme = Color(0xFF1B3D33);
  
  // Secondary Colors
  static const Color secondaryDarkTheme = Color(0xFF6BA3E8);
  static const Color secondaryLightDarkTheme = Color(0xFF8BB5ED);
  static const Color secondaryDarkDarkTheme = Color(0xFF4A7FC8);
  static const Color secondaryContainerDarkTheme = Color(0xFF1A2E3D);
  
  // Surface Colors (Dark Theme)
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantDark = Color(0xFF2A2A2A);
  static const Color surfaceContainerLowestDark = Color(0xFF121212);
  static const Color surfaceContainerLowDark = Color(0xFF1C1C1C);
  static const Color surfaceContainerMediumDark = Color(0xFF252525);
  static const Color surfaceContainerHighDark = Color(0xFF2E2E2E);
  static const Color surfaceDimDark = Color(0xFF1A1A1A);
  static const Color surfaceBrightDark = Color(0xFF2E2E2E);
  
  // Background Colors (Dark Theme)
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundLightDark = Color(0xFF1A1A1A);
  static const Color backgroundDarkDark = Color(0xFF0F0F0F);
  
  // Text Colors (Dark Theme)
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF909090);
  static const Color textDisabledDark = Color(0xFF606060);
  static const Color textHintDark = Color(0xFF505050);
  static const Color textInverseDark = Color(0xFF1C1C1C);
  
  // Border Colors (Dark Theme)
  static const Color borderLightDark = Color(0xFF2A2A2A);
  static const Color borderMediumDark = Color(0xFF3A3A3A);
  static const Color borderDarkDark = Color(0xFF4A4A4A);
  static const Color borderFocusDark = Color(0xFF2D9A7E);
  static const Color borderErrorDark = Color(0xFFE74C3C);
  
  // Divider Colors (Dark Theme)
  static const Color dividerDark = Color(0xFF2A2A2A);
  static const Color dividerLightDark = Color(0xFF1E1E1E);
  static const Color dividerDarkDark = Color(0xFF3A3A3A);
  
  // Shadow Colors (Dark Theme - lighter shadows for dark backgrounds)
  static Color shadowLightDark = const Color(0x40000000); // 25% black
  static Color shadowMediumDark = const Color(0x60000000); // 37.5% black
  static Color shadowDarkDark = const Color(0x80000000); // 50% black
  
  // Shimmer Colors (Dark Theme)
  static const Color shimmerBaseDark = Color(0xFF2A2A2A);
  static const Color shimmerHighlightDark = Color(0xFF3A3A3A);
  
  // Overlay Colors (Dark Theme - lighter overlays)
  static const Color overlayDarkTheme = Color(0x80000000); // 50% black
  static const Color overlayLightDarkTheme = Color(0x40000000); // 25% black
  static const Color overlayDarkDarkTheme = Color(0xB3000000); // 70% black
  static const Color scrimDarkTheme = Color(0x99000000); // 60% black

  // ==================== QURAN-SPECIFIC COLORS ====================
  // Light Theme Quran Colors
  static const Color quranTextLight = Color(0xFF1A1A1A); // High contrast black for Arabic text
  static const Color ayahNumberLight = Color(0xFF247C64); // Primary green for ayah numbers
  static const Color surahHeaderLight = Color(0xFF2D5A4A); // Darker green for surah headers
  static const Color translationTextLight = Color(0xFF4A4A4A); // Secondary text for translations
  
  // Dark Theme Quran Colors
  static const Color quranTextDark = Color(0xFFE8E8E8); // High contrast light for Arabic text
  static const Color ayahNumberDark = Color(0xFF3FCCB8); // Brighter green for ayah numbers in dark
  static const Color surahHeaderDark = Color(0xFF2D9A7E); // Primary dark theme green for headers
  static const Color translationTextDark = Color(0xFFB0B0B0); // Light secondary for translations

  // ==================== CONTEXT-AWARE COLOR GETTERS ====================
  // These methods return colors based on current theme brightness
  
  static Color getSurface(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceDark : surface;
  }
  
  static Color getPrimary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? primaryDarkTheme : primary;
  }

  static Color getPrimaryLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? primaryLightDarkTheme : primaryLight;
  }

  static Color getPrimaryContainer(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? primaryContainerDarkTheme : primaryContainer;
  }

  static Color getSecondary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? secondaryDarkTheme : secondary;
  }

  static Color getSecondaryLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? secondaryLightDarkTheme : secondaryLight;
  }

  static Color getSecondaryContainer(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? secondaryContainerDarkTheme : secondaryContainer;
  }

  static Color getBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? backgroundDark : background;
  }
  
  static Color getTextPrimary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textPrimaryDark : textPrimary;
  }
  
  static Color getTextSecondary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textSecondaryDark : textSecondary;
  }
  
  static Color getTextTertiary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textTertiaryDark : textTertiary;
  }
  
  static Color getBorderLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? borderLightDark : borderLight;
  }
  
  static Color getBorderMedium(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? borderMediumDark : borderMedium;
  }
  
  static Color getDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dividerDark : divider;
  }
  
  static Color getShadowLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? shadowLightDark : shadowLight;
  }
  
  static Color getShadowMedium(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? shadowMediumDark : shadowMedium;
  }
  
  static Color getShadowDark(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? shadowDarkDark : shadowDark;
  }
  
  static Color getShimmerBase(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? shimmerBaseDark : shimmerBase;
  }
  
  static Color getShimmerHighlight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? shimmerHighlightDark : shimmerHighlight;
  }
  
  static Color getTextInverse(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textInverseDark : textInverse;
  }
  
  static Color getTextDisabled(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textDisabledDark : textDisabled;
  }
  
  static Color getSurfaceContainerLowest(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceContainerLowestDark : surfaceContainerLowest;
  }
  
  static Color getSurfaceContainerLow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceContainerLowDark : surfaceContainerLow;
  }
  
  static Color getSurfaceVariant(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceVariantDark : surfaceVariant;
  }
  
  static Color getScrim(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? scrimDarkTheme : scrim;
  }
  
  static Color getError(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? errorDark : error;
  }
  
  static Color getErrorLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? errorLight : errorLight;
  }
  
  static Color getErrorDark(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? errorDark : errorDark;
  }
  
  static Color getErrorContainer(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? errorContainer : errorContainer;
  }

  // ==================== QURAN-SPECIFIC CONTEXT-AWARE GETTERS ====================
  
  /// Get Quran text color (Arabic verses) - optimized for readability
  static Color getQuranText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? quranTextDark : quranTextLight;
  }
  
  /// Get ayah number color - maintains visibility and brand consistency
  static Color getAyahNumber(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? ayahNumberDark : ayahNumberLight;
  }
  
  /// Get surah header color - provides hierarchy and emphasis
  static Color getSurahHeader(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surahHeaderDark : surahHeaderLight;
  }
  
  /// Get translation text color - ensures readability while being secondary
  static Color getTranslationText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? translationTextDark : translationTextLight;
  }

  // ==================== ADDITIONAL MISSING CONTEXT-AWARE GETTERS ====================
  
  static Color getSuccess(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? successLight : success;
  }
  
  static Color getSuccessContainer(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? successContainer : successContainer;
  }
  
  static Color getWarning(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? warningLight : warning;
  }
  
  static Color getWarningLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? warningLight : warningLight;
  }
  
  static Color getWarningDark(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? warningDark : warningDark;
  }
  
  static Color getWarningContainer(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? warningContainer : warningContainer;
  }
  
  static Color getInfo(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? infoLight : info;
  }
  
  static Color getInfoContainer(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? infoContainer : infoContainer;
  }
  
  static Color getSurfaceContainerMedium(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceContainerMediumDark : surfaceContainerMedium;
  }
  
  static Color getSurfaceContainerHigh(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceContainerHighDark : surfaceContainerHigh;
  }
  
  static Color getSurfaceDim(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceDimDark : surfaceDim;
  }
  
  static Color getSurfaceBright(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceBrightDark : surfaceBright;
  }
  
  static Color getBackgroundLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? backgroundLightDark : backgroundLight;
  }
  
  static Color getBackgroundDim(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? backgroundDarkDark : backgroundDim;
  }
  
  static Color getTextHint(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textHintDark : textHint;
  }
  
  static Color getBorderDark(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? borderDarkDark : borderDark;
  }
  
  static Color getBorderFocus(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? borderFocusDark : borderFocus;
  }
  
  static Color getBorderError(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? borderErrorDark : borderError;
  }
  
  static Color getDividerLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dividerLightDark : dividerLight;
  }
  
  static Color getDividerDim(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dividerDarkDark : dividerDim;
  }
  
  static Color getOverlay(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? overlayDarkTheme : overlay;
  }
  
  static Color getOverlayLight(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? overlayLightDarkTheme : overlayLight;
  }
  
  static Color getOverlayDark(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? overlayDarkDarkTheme : overlayDark;
  }

  // ==================== COLOR CONTRAST VALIDATION UTILITIES ====================
  
  /// Calculate relative luminance of a color (WCAG standard)
  static double _relativeLuminance(Color color) {
    double rsRGB = color.r;
    double gsRGB = color.g;
    double bsRGB = color.b;

    double r = rsRGB <= 0.03928 ? rsRGB / 12.92 : pow((rsRGB + 0.055) / 1.055, 2.4).toDouble();
    double g = gsRGB <= 0.03928 ? gsRGB / 12.92 : pow((gsRGB + 0.055) / 1.055, 2.4).toDouble();
    double b = bsRGB <= 0.03928 ? bsRGB / 12.92 : pow((bsRGB + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
  
  /// Calculate contrast ratio between two colors (WCAG standard)
  static double getContrastRatio(Color color1, Color color2) {
    double lum1 = _relativeLuminance(color1);
    double lum2 = _relativeLuminance(color2);
    
    double lighter = lum1 > lum2 ? lum1 : lum2;
    double darker = lum1 > lum2 ? lum2 : lum1;
    
    return (lighter + 0.05) / (darker + 0.05);
  }
  
  /// Check if color combination meets WCAG AA standard (4.5:1 for normal text)
  static bool meetsWCAGAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 4.5;
  }
  
  /// Check if color combination meets WCAG AAA standard (7:1 for normal text)
  static bool meetsWCAGAAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 7.0;
  }
  
  /// Check if color combination meets WCAG AA for large text (3:1)
  static bool meetsWCAGAALargeText(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 3.0;
  }
  
  /// Validate Quran text contrast in current theme
  static bool validateQuranTextContrast(BuildContext context) {
    final quranColor = getQuranText(context);
    final backgroundColor = getBackground(context);
    return meetsWCAGAA(quranColor, backgroundColor);
  }
  
  /// Validate ayah number contrast in current theme
  static bool validateAyahNumberContrast(BuildContext context) {
    final ayahColor = getAyahNumber(context);
    final backgroundColor = getBackground(context);
    return meetsWCAGAA(ayahColor, backgroundColor);
  }
  
  /// Validate all Quran-specific colors for accessibility
  static Map<String, bool> validateAllQuranContrast(BuildContext context) {
    final backgroundColor = getBackground(context);
    
    return {
      'quranText': meetsWCAGAA(getQuranText(context), backgroundColor),
      'ayahNumber': meetsWCAGAA(getAyahNumber(context), backgroundColor),
      'surahHeader': meetsWCAGAA(getSurahHeader(context), backgroundColor),
      'translationText': meetsWCAGAA(getTranslationText(context), backgroundColor),
    };
  }
  
  /// Get accessible text color for any background
  static Color getAccessibleTextColor(Color backgroundColor) {
    final whiteContrast = getContrastRatio(Colors.white, backgroundColor);
    final blackContrast = getContrastRatio(Colors.black, backgroundColor);
    
    return whiteContrast > blackContrast ? Colors.white : Colors.black;
  }
  
  /// Ensure border visibility by checking contrast with background
  static bool isBorderVisible(Color borderColor, Color backgroundColor) {
    return getContrastRatio(borderColor, backgroundColor) >= 1.5; // Minimum for UI elements
  }
  
  /// Get a visible border color for the current theme
  static Color getVisibleBorderColor(BuildContext context) {
    final backgroundColor = getBackground(context);
    final defaultBorder = getBorderMedium(context);
    
    if (isBorderVisible(defaultBorder, backgroundColor)) {
      return defaultBorder;
    }
    
    // Fallback to a more contrasted border
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF4A4A4A) // Lighter border for dark theme
        : const Color(0xFFBDBDBD); // Darker border for light theme
  }

  // ==================== MISSING CONTEXT-AWARE GETTERS ====================
  
  /// Get primary color (context-aware) - this is the main brand color
  static Color getPrimaryColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? primaryDarkTheme : primary;
  }
  
  /// Get accent color (context-aware)
  static Color getAccent(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? accentLight : accent;
  }
  
  /// Get listening state color (context-aware)
  static Color getListening(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? infoLight : listening;
  }
  
  /// Get correct state color (context-aware)
  static Color getCorrect(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? successLight : correct;
  }
  
  /// Get incorrect state color (context-aware)
  static Color getIncorrect(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? errorLight : incorrect;
  }
  
  /// Get skipped state color (context-aware)
  static Color getSkipped(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textTertiaryDark : skipped;
  }
  
  /// Get unread state color (context-aware)
  static Color getUnread(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? textDisabledDark : unread;
  }
}

/// ==================== TYPOGRAPHY SYSTEM ====================
class AppTypography {
  // ==================== FONT FAMILIES ====================
  static const String defaultFontFamily = 'System';
  static const String arabicFontFamily = 'UthmanicHafs';
  static const String arabicAltFont = 'Me_Quran';
  static const String surahNameFont = 'surah-name-v1';
  static const String surahNameAltFont = 'surah-name-v2';

  // ==================== FONT WEIGHTS ====================
  static const FontWeight thin = FontWeight.w100;
  static const FontWeight extraLight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;

  // ==================== LINE HEIGHTS ====================
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightRelaxed = 1.6;
  static const double lineHeightLoose = 1.8;
  static const double lineHeightArabic = 1.9;

  // ==================== LETTER SPACING ====================
  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;
  static const double letterSpacingXWide = 1.0;
  static const double letterSpacingXXWide = 1.5;

  // ==================== TYPE SCALE (Responsive) ====================
  
  /// Display Large - Largest text (hero sections, splash screens)
  static TextStyle displayLarge(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 40 * s,
      fontWeight: weight ?? bold,
      height: lineHeightTight,
      letterSpacing: letterSpacingTight,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Display Medium - Large display text
  static TextStyle displayMedium(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 36 * s,
      fontWeight: weight ?? bold,
      height: lineHeightTight,
      letterSpacing: letterSpacingTight,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Display Small - Small display text
  static TextStyle displaySmall(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 32 * s,
      fontWeight: weight ?? semiBold,
      height: lineHeightTight,
      letterSpacing: letterSpacingTight,
      color: color ?? AppColors.textPrimary,
    );
  }
  
  /// Heading 1 - Main section headers
  static TextStyle h1(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 28 * s,
      fontWeight: weight ?? semiBold,
      height: lineHeightNormal,
      letterSpacing: letterSpacingTight,
      color: color ?? AppColors.getTextPrimary(context),
    );
  }
  
  /// Heading 2 - Subsection headers
  static TextStyle h2(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 24 * s,
      fontWeight: weight ?? semiBold,
      height: lineHeightNormal,
      letterSpacing: letterSpacingNormal,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Heading 3 - Minor section headers
  static TextStyle h3(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 20 * s,
      fontWeight: weight ?? semiBold,
      height: lineHeightNormal,
      letterSpacing: letterSpacingNormal,
      color: color ?? AppColors.textPrimary,
    );
  }
  
  /// Title Large - Large card/list titles
  static TextStyle titleLarge(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 18 * s,
      fontWeight: weight ?? semiBold,
      height: lineHeightNormal,
      letterSpacing: letterSpacingNormal,
      color: color ?? AppColors.getTextPrimary(context),
    );
  }

  /// Title - Standard card/list item titles
  static TextStyle title(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 16 * s,
      fontWeight: weight ?? semiBold,
      height: lineHeightNormal,
      letterSpacing: letterSpacingNormal,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Title Small - Small titles
  static TextStyle titleSmall(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 14 * s,
      fontWeight: weight ?? semiBold,
      height: lineHeightNormal,
      letterSpacing: letterSpacingNormal,
      color: color ?? AppColors.textPrimary,
    );
  }
  
  /// Body Large - Large body text
  static TextStyle bodyLarge(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 16 * s,
      fontWeight: weight ?? regular,
      height: lineHeightRelaxed,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.getTextSecondary(context),
    );
  }
  
  /// Body - Standard body text
  static TextStyle body(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 14 * s,
      fontWeight: weight ?? regular,
      height: lineHeightRelaxed,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.getTextSecondary(context),
    );
  }

  /// Body Small - Small body text
  static TextStyle bodySmall(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 12 * s,
      fontWeight: weight ?? regular,
      height: lineHeightRelaxed,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.getTextSecondary(context),
    );
  }
  
  /// Caption Large - Large metadata text
  static TextStyle captionLarge(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 13 * s,
      fontWeight: weight ?? regular,
      height: lineHeightNormal,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textTertiary,
    );
  }

  /// Caption - Standard metadata text
  static TextStyle caption(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 12 * s,
      fontWeight: weight ?? regular,
      height: lineHeightNormal,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textTertiary,
    );
  }

  /// Caption Small - Tiny text (timestamps, footnotes)
  static TextStyle captionSmall(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 10 * s,
      fontWeight: weight ?? regular,
      height: lineHeightNormal,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textTertiary,
    );
  }
  
  /// Label Large - Large button/badge text
  static TextStyle labelLarge(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 14 * s,
      fontWeight: weight ?? medium,
      height: lineHeightNormal,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textSecondary,
    );
  }

  /// Label - Standard button/badge/chip text
  static TextStyle label(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 13 * s,
      fontWeight: weight ?? medium,
      height: lineHeightNormal,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textSecondary,
    );
  }

  /// Label Small - Small labels
  static TextStyle labelSmall(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 11 * s,
      fontWeight: weight ?? medium,
      height: lineHeightNormal,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textSecondary,
    );
  }
  
  /// Overline - Category labels (uppercase)
  static TextStyle overline(BuildContext context, {Color? color, FontWeight? weight}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontSize: 11 * s,
      fontWeight: weight ?? bold,
      height: lineHeightNormal,
      letterSpacing: letterSpacingXXWide,
      color: color ?? AppColors.textTertiary,
    );
  }
  
  /// Arabic Text - Quran verses (large)
  static TextStyle arabicLarge(BuildContext context, {double? fontSize, Color? color}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontFamily: arabicFontFamily,
      fontSize: (fontSize ?? 24) * s,
      fontWeight: regular,
      height: lineHeightArabic,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Arabic Text - Quran verses (medium, default)
  static TextStyle arabic(BuildContext context, {double? fontSize, Color? color}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontFamily: arabicFontFamily,
      fontSize: (fontSize ?? 20) * s,
      fontWeight: regular,
      height: lineHeightArabic,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Arabic Text - Quran verses (small)
  static TextStyle arabicSmall(BuildContext context, {double? fontSize, Color? color}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontFamily: arabicFontFamily,
      fontSize: (fontSize ?? 16) * s,
      fontWeight: regular,
      height: lineHeightArabic,
      letterSpacing: letterSpacingWide,
      color: color ?? AppColors.textPrimary,
    );
  }
  
  /// Surah Name (decorative Arabic font) - Large
  static TextStyle surahNameLarge(BuildContext context, {double? fontSize, Color? color}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontFamily: surahNameFont,
      fontSize: (fontSize ?? 36) * s,
      color: color ?? AppColors.primary.withValues(alpha: 0.8),
    );
  }

  /// Surah Name (decorative Arabic font) - Medium
  static TextStyle surahName(BuildContext context, {double? fontSize, Color? color}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontFamily: surahNameFont,
      fontSize: (fontSize ?? 30) * s,
      color: color ?? AppColors.primary.withValues(alpha: 0.8),
    );
  }

  /// Surah Name (decorative Arabic font) - Small
  static TextStyle surahNameSmall(BuildContext context, {double? fontSize, Color? color}) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextStyle(
      fontFamily: surahNameFont,
      fontSize: (fontSize ?? 24) * s,
      color: color ?? AppColors.primary.withValues(alpha: 0.8),
    );
  }
}

/// ==================== COMPONENT STYLES ====================
class AppComponentStyles {
  // ==================== CARD DECORATIONS ====================
  
  /// Standard card with shadow
  static BoxDecoration card({
    Color? color,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
    bool shadow = true,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface, // Note: Use context-aware getter when calling
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusMedium),
      border: borderColor != null 
          ? Border.all(color: borderColor, width: borderWidth ?? 1.0)
          : null,
      boxShadow: shadow ? [
        BoxShadow(
          color: AppColors.shadowLight, // Note: Use context-aware getter when calling
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ] : null,
    );
  }

  /// Card with strong shadow
  static BoxDecoration cardElevated({
    Color? color,
    double? borderRadius,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface, // Note: Use context-aware getter when calling
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusMedium),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowMedium, // Note: Use context-aware getter when calling
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Card without shadow (flat)
  static BoxDecoration cardFlat({
    Color? color,
    double? borderRadius,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface, // Note: Use context-aware getter when calling
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusMedium),
      border: borderColor != null
          ? Border.all(color: borderColor, width: 1.0)
          : Border.all(color: AppColors.borderLight, width: 1.0), // Note: Use context-aware getter when calling
    );
  }
  
  // ==================== DIVIDER DECORATIONS ====================
  
  /// Bottom divider
  static BoxDecoration divider({Color? color, double? width}) {
    return BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: color ?? AppColors.borderLight, // Note: Use context-aware getter when calling
          width: width ?? 1.0,
        ),
      ),
    );
  }

  /// Top divider
  static BoxDecoration dividerTop({Color? color, double? width}) {
    return BoxDecoration(
      border: Border(
        top: BorderSide(
          color: color ?? AppColors.borderLight, // Note: Use context-aware getter when calling
          width: width ?? 1.0,
        ),
      ),
    );
  }

  /// All borders
  static BoxDecoration bordered({Color? color, double? width, double? radius}) {
    return BoxDecoration(
      border: Border.all(
        color: color ?? AppColors.borderMedium,
        width: width ?? 1.0,
      ),
      borderRadius: BorderRadius.circular(radius ?? AppDesignSystem.radiusMedium),
    );
  }
  
  // ==================== CONTAINER DECORATIONS ====================
  
  /// Icon container with background
  static BoxDecoration iconContainer({
    Color? backgroundColor,
    double? borderRadius,
    bool gradient = false,
  }) {
    return BoxDecoration(
      gradient: gradient
          ? LinearGradient(
              colors: [
                (backgroundColor ?? AppColors.primary).withValues(alpha: 0.08),
                (backgroundColor ?? AppColors.primary).withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: gradient ? null : (backgroundColor ?? AppColors.primary.withValues(alpha: 0.08)),
      borderRadius: BorderRadius.circular(
        borderRadius ?? AppDesignSystem.radiusSmall,
      ),
    );
  }

  /// Gradient container
  static BoxDecoration gradientContainer({
    required Gradient gradient,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
  }) {
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusMedium),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth ?? 1.0)
          : null,
    );
  }

  /// Shimmer effect decoration (for loading skeletons)
  static BoxDecoration shimmer() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.shimmerBase,
          AppColors.shimmerHighlight,
          AppColors.shimmerBase,
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
    );
  }
  
  // ==================== INTERACTION COLORS ====================
  
  /// Ripple/Tap effect color
  static Color get rippleColor => AppColors.primary.withValues(alpha: 0.08);
  
  /// Hover effect color
  static Color get hoverColor => AppColors.primary.withValues(alpha: 0.04);
  
  /// Focus effect color
  static Color get focusColor => AppColors.primary.withValues(alpha: 0.12);

  /// Splash effect color
  static Color get splashColor => AppColors.primary.withValues(alpha: 0.16);

  // ==================== BUTTON STYLES ====================
  
  /// Primary button style
  static ButtonStyle primaryButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.getPrimary(context),
      foregroundColor: AppColors.getTextInverse(context),
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space24 * s,
        vertical: AppDesignSystem.space16 * s,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
      ),
      textStyle: AppTypography.label(context, color: AppColors.getTextInverse(context), weight: AppTypography.semiBold),
    );
  }

  /// Secondary button style (outlined)
  static ButtonStyle secondaryButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.getPrimary(context),
      backgroundColor: Colors.transparent,
      elevation: 0,
      side: BorderSide(color: AppColors.getPrimary(context), width: 1.5 * s),
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space24 * s,
        vertical: AppDesignSystem.space16 * s,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
      ),
      textStyle: AppTypography.label(context, color: AppColors.getPrimary(context), weight: AppTypography.semiBold),
    );
  }

  /// Text button style
  static ButtonStyle textButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextButton.styleFrom(
      foregroundColor: AppColors.getPrimary(context),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space12 * s,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      ),
      textStyle: AppTypography.label(context, color: AppColors.getPrimary(context), weight: AppTypography.semiBold),
    );
  }

  /// Small button style
  static ButtonStyle smallButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.getPrimary(context),
      foregroundColor: AppColors.getTextInverse(context),
      elevation: 0,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space8 * s,
      ),
      minimumSize: Size(0, AppDesignSystem.buttonHeightSmall * s),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      ),
      textStyle: AppTypography.labelSmall(context, color: AppColors.getTextInverse(context), weight: AppTypography.semiBold),
    );
  }

  /// Icon button decoration
  static BoxDecoration iconButtonDecoration({
    Color? backgroundColor,
    bool isSelected = false,
  }) {
    return BoxDecoration(
      color: isSelected
          ? AppColors.primaryWithOpacity(0.1)
          : backgroundColor ?? Colors.transparent,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
    );
  }

  // ==================== INPUT FIELD DECORATION ====================
  
  /// Standard input decoration
  static InputDecoration inputDecoration({
    required BuildContext context,
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool filled = true,
    Color? fillColor,
    Color? borderColor,
    bool error = false,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: AppTypography.body(context, color: AppColors.getTextHint(context)),
      labelStyle: AppTypography.body(context, color: AppColors.getTextTertiary(context)),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: fillColor ?? AppColors.getSurfaceContainerLowest(context),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space12 * s,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.getBorderLight(context),
          width: 1.0 * s,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.getBorderLight(context),
          width: 1.0 * s,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: error ? AppColors.getError(context) : AppColors.getBorderFocus(context),
          width: 1.5 * s,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: AppColors.getBorderError(context),
          width: 1.5 * s,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: AppColors.getError(context),
          width: 2.0 * s,
        ),
      ),
    );
  }

  // ==================== SNACKBAR STYLE ====================
  
  /// Success snackbar
  static SnackBar successSnackBar({
    required String message,
    Duration? duration,
    BuildContext? context,
  }) {
    return SnackBar(
      content: Text(message),
      backgroundColor: context != null ? AppColors.getSuccess(context) : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
      ),
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  /// Error snackbar
  static SnackBar errorSnackBar({
    required String message,
    Duration? duration,
    BuildContext? context,
  }) {
    return SnackBar(
      content: Text(message),
      backgroundColor: context != null ? AppColors.getError(context) : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
      ),
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Info snackbar
  static SnackBar infoSnackBar({
    required String message,
    Duration? duration,
    BuildContext? context,
  }) {
    return SnackBar(
      content: Text(message),
      backgroundColor: context != null ? AppColors.getInfo(context) : AppColors.info,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
      ),
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  // ==================== BOTTOM SHEET DECORATION ====================
  
  static BoxDecoration bottomSheetDecoration() {
    return const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppDesignSystem.radiusXLarge),
        topRight: Radius.circular(AppDesignSystem.radiusXLarge),
      ),
    );
  }

  // ==================== DIALOG DECORATION ====================
  
  static BoxDecoration dialogDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowDark,
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ==================== APP BAR THEME ====================
  
  static AppBarTheme appBarTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AppBarTheme(
      backgroundColor: AppColors.getSurface(context),
      foregroundColor: AppColors.getTextPrimary(context),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.titleLarge(context, color: AppColors.getTextPrimary(context)),
      iconTheme: IconThemeData(
        color: AppColors.getTextPrimary(context),
        size: AppDesignSystem.iconLarge,
      ),
      systemOverlayStyle: brightness == Brightness.dark 
          ? SystemUiOverlayStyle.light 
          : SystemUiOverlayStyle.dark,
    );
  }

  // ==================== TAB BAR THEME ====================
  
  static TabBarThemeData tabBarTheme(BuildContext context) {
    return TabBarThemeData(
      labelColor: AppColors.getPrimary(context),
      unselectedLabelColor: AppColors.getTextDisabled(context),
      labelStyle: AppTypography.label(context, color: AppColors.getPrimary(context), weight: AppTypography.semiBold),
      unselectedLabelStyle: AppTypography.label(context, color: AppColors.getTextDisabled(context)),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.getPrimary(context),
          width: 2.5,
        ),
      ),
    );
  }
}

/// ==================== HAPTIC FEEDBACK HELPER ====================
class AppHaptics {
  /// Light impact (for subtle interactions)
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact (for normal interactions)
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact (for important actions)
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click (for switches, checkboxes)
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibrate (for errors, alerts)
  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }
}

/// ==================== ANIMATION HELPER ====================
class AppAnimations {
  /// Fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? AppDesignSystem.durationNormal,
      curve: curve ?? Curves.easeIn,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }

  /// Slide in from bottom
  static Widget slideInFromBottom({
    required Widget child,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: const Offset(0, 1), end: Offset.zero),
      duration: duration ?? AppDesignSystem.durationNormal,
      curve: curve ?? Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value.dy * 50),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Scale animation
  static Widget scale({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double? begin,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin ?? 0.8, end: 1.0),
      duration: duration ?? AppDesignSystem.durationNormal,
      curve: curve ?? Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }
}

/// ==================== THEME DATA ====================
class AppTheme {
  /// Get complete ThemeData for light theme
  static ThemeData lightTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppComponentStyles.appBarTheme(context),
      tabBarTheme: AppComponentStyles.tabBarTheme(context),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppComponentStyles.primaryButton(context),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppComponentStyles.secondaryButton(context),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppComponentStyles.textButton(context),
      ),
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1.0,
        space: 1.0,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge(context),
        displayMedium: AppTypography.displayMedium(context),
        displaySmall: AppTypography.displaySmall(context),
        headlineLarge: AppTypography.h1(context),
        headlineMedium: AppTypography.h2(context),
        headlineSmall: AppTypography.h3(context),
        titleLarge: AppTypography.titleLarge(context),
        titleMedium: AppTypography.title(context),
        titleSmall: AppTypography.titleSmall(context),
        bodyLarge: AppTypography.bodyLarge(context),
        bodyMedium: AppTypography.body(context),
        bodySmall: AppTypography.bodySmall(context),
        labelLarge: AppTypography.labelLarge(context),
        labelMedium: AppTypography.label(context),
        labelSmall: AppTypography.labelSmall(context),
      ),
    );
  }
  
  /// Get complete ThemeData for dark theme
  static ThemeData darkTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryDarkTheme,
        brightness: Brightness.dark,
        primary: AppColors.primaryDarkTheme,
        secondary: AppColors.secondaryDarkTheme,
        error: AppColors.error,
        surface: AppColors.surfaceDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark, // keep explicit background for scaffold
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.titleLarge(context, color: AppColors.textPrimaryDark),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryDark,
          size: AppDesignSystem.iconLarge,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryDarkTheme,
        unselectedLabelColor: AppColors.textDisabledDark,
        labelStyle: AppTypography.label(context, color: AppColors.primaryDarkTheme, weight: AppTypography.semiBold),
        unselectedLabelStyle: AppTypography.label(context, color: AppColors.textDisabledDark),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppColors.primaryDarkTheme,
            width: 2.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDarkTheme,
          foregroundColor: AppColors.textInverseDark,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space24 * AppDesignSystem.getScaleFactor(context),
            vertical: AppDesignSystem.space16 * AppDesignSystem.getScaleFactor(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * AppDesignSystem.getScaleFactor(context)),
          ),
          textStyle: AppTypography.label(context, color: AppColors.textInverseDark, weight: AppTypography.semiBold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDarkTheme,
          backgroundColor: Colors.transparent,
          elevation: 0,
          side: BorderSide(color: AppColors.primaryDarkTheme, width: 1.5 * AppDesignSystem.getScaleFactor(context)),
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space24 * AppDesignSystem.getScaleFactor(context),
            vertical: AppDesignSystem.space16 * AppDesignSystem.getScaleFactor(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * AppDesignSystem.getScaleFactor(context)),
          ),
          textStyle: AppTypography.label(context, color: AppColors.primaryDarkTheme, weight: AppTypography.semiBold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDarkTheme,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space16 * AppDesignSystem.getScaleFactor(context),
            vertical: AppDesignSystem.space12 * AppDesignSystem.getScaleFactor(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * AppDesignSystem.getScaleFactor(context)),
          ),
          textStyle: AppTypography.label(context, color: AppColors.primaryDarkTheme, weight: AppTypography.semiBold),
        ),
      ),
      dividerColor: AppColors.dividerDark, // Dark theme divider
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark, // Dark theme divider
        thickness: 1.0,
        space: 1.0,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge(context, color: AppColors.textPrimaryDark),
        displayMedium: AppTypography.displayMedium(context, color: AppColors.textPrimaryDark),
        displaySmall: AppTypography.displaySmall(context, color: AppColors.textPrimaryDark),
        headlineLarge: AppTypography.h1(context, color: AppColors.textPrimaryDark),
        headlineMedium: AppTypography.h2(context, color: AppColors.textPrimaryDark),
        headlineSmall: AppTypography.h3(context, color: AppColors.textPrimaryDark),
        titleLarge: AppTypography.titleLarge(context, color: AppColors.textPrimaryDark),
        titleMedium: AppTypography.title(context, color: AppColors.textPrimaryDark),
        titleSmall: AppTypography.titleSmall(context, color: AppColors.textPrimaryDark),
        bodyLarge: AppTypography.bodyLarge(context, color: AppColors.textSecondaryDark),
        bodyMedium: AppTypography.body(context, color: AppColors.textSecondaryDark),
        bodySmall: AppTypography.bodySmall(context, color: AppColors.textSecondaryDark),
        labelLarge: AppTypography.labelLarge(context, color: AppColors.textSecondaryDark),
        labelMedium: AppTypography.label(context, color: AppColors.textSecondaryDark),
        labelSmall: AppTypography.labelSmall(context, color: AppColors.textSecondaryDark),
      ),
    );
  }
}

/// ==================== PADDING PRESETS ====================
class AppPadding {
  /// Page padding (edges of screen)
  static EdgeInsets page(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.all(AppDesignSystem.space20 * s);
  }

  /// Section padding
  static EdgeInsets section(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.symmetric(
      horizontal: AppDesignSystem.space20 * s,
      vertical: AppDesignSystem.space16 * s,
    );
  }

  /// Card padding
  static EdgeInsets card(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.all(AppDesignSystem.space16 * s);
  }

  /// List tile padding
  static EdgeInsets listTile(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.symmetric(
      horizontal: AppDesignSystem.space20 * s,
      vertical: AppDesignSystem.space16 * s,
    );
  }

  /// Horizontal only
  static EdgeInsets horizontal(BuildContext context, double value) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.symmetric(horizontal: value * s);
  }

  /// Vertical only
  static EdgeInsets vertical(BuildContext context, double value) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.symmetric(vertical: value * s);
  }

  /// All sides equal
  static EdgeInsets all(BuildContext context, double value) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.all(value * s);
  }

  /// Only specific sides
  static EdgeInsets only(
    BuildContext context, {
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.only(
      left: (left ?? 0) * s,
      top: (top ?? 0) * s,
      right: (right ?? 0) * s,
      bottom: (bottom ?? 0) * s,
    );
  }

  /// Custom padding
  static EdgeInsets custom(
    BuildContext context, {
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    final s = AppDesignSystem.getScaleFactor(context);
    return EdgeInsets.only(
      left: (left ?? 0) * s,
      top: (top ?? 0) * s,
      right: (right ?? 0) * s,
      bottom: (bottom ?? 0) * s,
    );
  }
}

/// ==================== MARGIN PRESETS ====================
class AppMargin {
  /// Small gap between elements
  static SizedBox gapSmall(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(height: AppDesignSystem.space8 * s);
  }

  /// Medium gap
  static SizedBox gap(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(height: AppDesignSystem.space16 * s);
  }

  /// Large gap
  static SizedBox gapLarge(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(height: AppDesignSystem.space24 * s);
  }

  /// Extra large gap
  static SizedBox gapXLarge(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(height: AppDesignSystem.space32 * s);
  }

  /// Horizontal gap small
  static SizedBox gapHSmall(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(width: AppDesignSystem.space8 * s);
  }

  /// Horizontal gap
  static SizedBox gapH(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(width: AppDesignSystem.space16 * s);
  }

  /// Horizontal gap large
  static SizedBox gapHLarge(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(width: AppDesignSystem.space24 * s);
  }

  /// Custom gap
  static SizedBox customGap(BuildContext context, double value) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(height: value * s);
  }

  /// Custom horizontal gap
  static SizedBox customGapH(BuildContext context, double value) {
    final s = AppDesignSystem.getScaleFactor(context);
    return SizedBox(width: value * s);
  }
}