// lib/core/design_system/app_design_system.dart
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
  static const Color backgroundDark = Color(0xFFF5F5F5);

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
  static const Color dividerDark = Color(0xFFBDBDBD);

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
      color: color ?? AppColors.textPrimary,
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
      color: color ?? AppColors.textPrimary,
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
      color: color ?? AppColors.textSecondary,
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
      color: color ?? AppColors.textSecondary,
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
      color: color ?? AppColors.textSecondary,
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
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusMedium),
      border: borderColor != null 
          ? Border.all(color: borderColor, width: borderWidth ?? 1.0)
          : null,
      boxShadow: shadow ? [
        BoxShadow(
          color: AppColors.shadowLight,
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
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusMedium),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowMedium,
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
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusMedium),
      border: borderColor != null
          ? Border.all(color: borderColor, width: 1.0)
          : Border.all(color: AppColors.borderLight, width: 1.0),
    );
  }
  
  // ==================== DIVIDER DECORATIONS ====================
  
  /// Bottom divider
  static BoxDecoration divider({Color? color, double? width}) {
    return BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: color ?? AppColors.borderLight,
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
          color: color ?? AppColors.borderLight,
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
      color: gradient ? null : (backgroundColor ?? AppColors.primaryWithOpacity(0.08)),
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
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space24 * s,
        vertical: AppDesignSystem.space16 * s,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
      ),
      textStyle: AppTypography.label(context, color: Colors.white, weight: AppTypography.semiBold),
    );
  }

  /// Secondary button style (outlined)
  static ButtonStyle secondaryButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      backgroundColor: Colors.transparent,
      elevation: 0,
      side: BorderSide(color: AppColors.primary, width: 1.5 * s),
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space24 * s,
        vertical: AppDesignSystem.space16 * s,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
      ),
      textStyle: AppTypography.label(context, color: AppColors.primary, weight: AppTypography.semiBold),
    );
  }

  /// Text button style
  static ButtonStyle textButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space12 * s,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      ),
      textStyle: AppTypography.label(context, color: AppColors.primary, weight: AppTypography.semiBold),
    );
  }

  /// Small button style
  static ButtonStyle smallButton(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space8 * s,
      ),
      minimumSize: Size(0, AppDesignSystem.buttonHeightSmall * s),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      ),
      textStyle: AppTypography.labelSmall(context, color: Colors.white, weight: AppTypography.semiBold),
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
      hintStyle: AppTypography.body(context, color: AppColors.textHint),
      labelStyle: AppTypography.body(context, color: AppColors.textTertiary),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: fillColor ?? AppColors.surfaceContainerLowest,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space16 * s,
        vertical: AppDesignSystem.space12 * s,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.borderMedium,
          width: 1.0 * s,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: borderColor ?? Colors.transparent,
          width: 1.0 * s,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: error ? AppColors.error : AppColors.borderFocus,
          width: 1.5 * s,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: AppColors.borderError,
          width: 1.5 * s,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
        borderSide: BorderSide(
          color: AppColors.error,
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
  }) {
    return SnackBar(
      content: Text(message),
      backgroundColor: AppColors.success,
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
  }) {
    return SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
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
  }) {
    return SnackBar(
      content: Text(message),
      backgroundColor: AppColors.info,
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
    return AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.titleLarge(context),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: AppDesignSystem.iconLarge,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  // ==================== TAB BAR THEME ====================
  
  static TabBarThemeData tabBarTheme(BuildContext context) {
    return TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textDisabled,
      labelStyle: AppTypography.label(context, weight: AppTypography.semiBold),
      unselectedLabelStyle: AppTypography.label(context),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.primary,
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
  /// Get complete ThemeData for app
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
        background: AppColors.background,
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


