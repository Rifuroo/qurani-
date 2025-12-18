// lib/core/widgets/app_components.dart
import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';

/// ==================== LIST TILE COMPONENT ====================
/// Standardized list tile with icon, title, subtitle, and trailing

class AppListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets? padding;
  final bool showDivider;
  final bool enabled;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const AppListTile({
    Key? key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.showDivider = true,
    this.enabled = true,
    this.backgroundColor,
    this.titleStyle,
    this.subtitleStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        splashColor: AppComponentStyles.rippleColor,
        highlightColor: AppComponentStyles.rippleColor.withValues(alpha: 0.5),
        child: Container(
          padding: padding ?? AppPadding.listTile(context),
          decoration: showDivider ? AppComponentStyles.divider() : null,
          child: Row(
            children: [
              if (leading != null) ...[leading!, AppMargin.gapH(context)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: titleStyle ?? AppTypography.title(
                        context,
                        color: enabled ? AppColors.getTextPrimary(context) : AppColors.getTextDisabled(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      AppMargin.gapSmall(context),
                      Text(
                        subtitle!,
                        style: subtitleStyle ?? AppTypography.caption(
                          context,
                          color: enabled ? AppColors.getTextSecondary(context) : AppColors.getTextDisabled(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                AppMargin.gapHSmall(context),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ==================== ICON CONTAINER ====================
/// Standardized circular/rounded icon container with background

class AppIconContainer extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? borderRadius;
  final EdgeInsets? padding;
  final bool gradient;
  final VoidCallback? onTap;

  const AppIconContainer({
    Key? key,
    required this.icon,
    this.size,
    this.iconColor,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
    this.gradient = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final containerSize = (size ?? 40) * s;
    final iconSize = (size ?? 40) * 0.5 * s;

    final container = Container(
      width: containerSize,
      height: containerSize,
      padding: padding,
      decoration: AppComponentStyles.iconContainer(
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        gradient: gradient,
      ),
      child: Icon(icon, color: iconColor ?? AppColors.primary, size: iconSize),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDesignSystem.radiusSmall * s,
        ),
        child: container,
      );
    }

    return container;
  }
}

/// ==================== NUMBER BADGE ====================
/// Circular badge with number (for Surah/Juz numbering)

class AppNumberBadge extends StatelessWidget {
  final String number;
  final double? size;
  final Color? backgroundColor;
  final Color? textColor;
  final bool gradient;
  final VoidCallback? onTap;

  const AppNumberBadge({
    Key? key,
    required this.number,
    this.size,
    this.backgroundColor,
    this.textColor,
    this.gradient = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final containerSize = (size ?? 42) * s;

    final container = Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
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
        color: gradient
            ? null
            : (backgroundColor ?? AppColors.getSurfaceContainerLowest(context)),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        style: AppTypography.title(
          context,
          color: textColor ?? AppColors.primary,
          weight: AppTypography.semiBold,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
        child: container,
      );
    }

    return container;
  }
}

/// ==================== CATEGORY HEADER ====================
/// Section header with uppercase label

class AppCategoryHeader extends StatelessWidget {
  final String title;
  final String? count;
  final EdgeInsets? padding;
  final Widget? trailing;

  const AppCategoryHeader({
    Key? key,
    required this.title,
    this.count,
    this.padding,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            AppDesignSystem.space20 * s,
            AppDesignSystem.space12 * s,
            AppDesignSystem.space20 * s,
            AppDesignSystem.space8 * s,
          ),
      child: Row(
        children: [
          Text(
            count != null ? '$title ($count)' : title,
            style: AppTypography.overline(context),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// ==================== EMPTY STATE ====================
/// Standardized empty/no results view

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double? iconSize;

  const AppEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Center(
      child: Padding(
        padding: AppPadding.all(context, AppDesignSystem.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: (iconSize ?? 80) * s,
              height: (iconSize ?? 80) * s,
              decoration: BoxDecoration(
                color: AppColors.getSurfaceContainerLowest(context),
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusRound * s,
                ),
              ),
              child: Icon(
                icon,
                size: (iconSize ?? 40) * s,
                color: AppColors.borderDark,
              ),
            ),
            AppMargin.gapLarge(context),
            Text(
              title,
              style: AppTypography.titleLarge(context),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppMargin.gapSmall(context),
              Text(
                subtitle!,
                style: AppTypography.caption(context),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[AppMargin.gapXLarge(context), action!],
          ],
        ),
      ),
    );
  }
}

/// ==================== ERROR STATE ====================
/// Standardized error view with retry button

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  const AppErrorState({
    Key? key,
    this.title = 'An Error Occurred',
    required this.message,
    this.onRetry,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Center(
      child: Padding(
        padding: AppPadding.all(context, AppDesignSystem.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80 * s,
              height: 80 * s,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusRound * s,
                ),
              ),
              child: Icon(
                icon ?? Icons.error_outline_rounded,
                color: AppColors.error,
                size: AppDesignSystem.iconXLarge * s,
              ),
            ),
            AppMargin.gapLarge(context),
            Text(
              title,
              style: AppTypography.h2(context),
              textAlign: TextAlign.center,
            ),
            AppMargin.gapSmall(context),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(context, color: AppColors.getTextTertiary(context)),
            ),
            if (onRetry != null) ...[
              AppMargin.gapXLarge(context),
              ElevatedButton(
                style: AppComponentStyles.primaryButton(context),
                onPressed: onRetry,
                child: Text(
                  'Try Again',
                  style: AppTypography.label(context, color: AppColors.textInverse),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ==================== LOADING INDICATOR ====================
/// Standardized loading spinner

class AppLoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;
  final String? message;

  const AppLoadingIndicator({Key? key, this.size, this.color, this.message})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? 24,
            height: size ?? 24,
            child: CircularProgressIndicator(
              color: color ?? AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
          if (message != null) ...[
            AppMargin.gap(context),
            Text(
              message!,
              style: AppTypography.caption(context),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// ==================== CHIP/BADGE ====================
/// Small label chip (e.g., "Makkiyah", "12 Ayat")

class AppChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const AppChip({
    Key? key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.padding,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    final chipContent = Container(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space12 * s,
            vertical: AppDesignSystem.space6 * s,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryWithOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppDesignSystem.iconSmall * s,
              color: textColor ?? AppColors.primary,
            ),
            SizedBox(width: AppDesignSystem.space4 * s),
          ],
          Text(
            label,
            style: AppTypography.label(
              context,
              color: textColor ?? AppColors.primary,
              weight: AppTypography.semiBold,
            ),
          ),
          if (onDelete != null) ...[
            SizedBox(width: AppDesignSystem.space4 * s),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                size: AppDesignSystem.iconSmall * s,
                color: textColor ?? AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
        child: chipContent,
      );
    }

    return chipContent;
  }
}

/// ==================== CARD ====================
/// Standardized card container

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? borderRadius;
  final bool shadow;
  final VoidCallback? onTap;
  final Color? borderColor;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.shadow = true,
    this.onTap,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin,
      padding: padding ?? AppPadding.card(context),
      decoration: AppComponentStyles.card(
        color: color ?? AppColors.getSurface(context),
        borderRadius: borderRadius,
        shadow: shadow,
        borderColor: borderColor,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDesignSystem.radiusMedium,
        ),
        child: container,
      );
    }

    return container;
  }
}

/// ==================== BUTTON ====================
/// Standardized primary button

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final ButtonStyle? style;

  const AppButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.fullWidth = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget buttonChild = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: textColor ?? AppColors.getTextInverse(context),
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppDesignSystem.iconMedium),
                AppMargin.gapHSmall(context),
              ],
              Text(text),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style:
            style ??
            AppComponentStyles.primaryButton(context).copyWith(
              backgroundColor: backgroundColor != null
                  ? WidgetStateProperty.all(backgroundColor)
                  : null,
              foregroundColor: textColor != null
                  ? WidgetStateProperty.all(textColor)
                  : null,
            ),
        child: buttonChild,
      ),
    );
  }
}

/// ==================== SECONDARY BUTTON ====================
class AppSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;

  const AppSecondaryButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.fullWidth = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget buttonChild = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppDesignSystem.iconMedium),
                AppMargin.gapHSmall(context),
              ],
              Text(text),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: AppComponentStyles.secondaryButton(context),
        child: buttonChild,
      ),
    );
  }
}

/// ==================== TEXT BUTTON ====================
class AppTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const AppTextButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: AppComponentStyles.textButton(context).copyWith(
        foregroundColor: color != null
            ? WidgetStateProperty.all(color)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppDesignSystem.iconMedium),
            AppMargin.gapHSmall(context),
          ],
          Text(text),
        ],
      ),
    );
  }
}

/// ==================== ICON BUTTON ====================
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? size;
  final String? tooltip;
  final bool isSelected;

  const AppIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size,
    this.tooltip,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final containerSize = (size ?? 40) * s;

    final button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall * s),
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: AppComponentStyles.iconButtonDecoration(
          backgroundColor: backgroundColor,
          isSelected: isSelected,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? AppColors.primary
              : (iconColor ?? AppColors.getTextSecondary(context)),
          size: (size ?? 40) * 0.5 * s,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

/// ==================== DIVIDER ====================
class AppDivider extends StatelessWidget {
  final double? height;
  final double? thickness;
  final Color? color;
  final EdgeInsets? padding;

  const AppDivider({
    Key? key,
    this.height,
    this.thickness,
    this.color,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Divider(
        height: height ?? 1,
        thickness: thickness ?? 1,
        color: color ?? AppColors.divider,
      ),
    );
  }
}

/// ==================== SHIMMER LOADING (Skeleton) ====================
class AppShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double? borderRadius;

  const AppShimmer({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.shimmerBase,
                AppColors.shimmerHighlight,
                AppColors.shimmerBase,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(
              widget.borderRadius ?? AppDesignSystem.radiusSmall,
            ),
          ),
        );
      },
    );
  }
}

/// ==================== BADGE ====================
class AppBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? child;

  const AppBadge({
    Key? key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    if (child != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child!,
          Positioned(
            top: -4 * s,
            right: -4 * s,
            child: _buildBadge(context, s),
          ),
        ],
      );
    }

    return _buildBadge(context, s);
  }

  Widget _buildBadge(BuildContext context, double s) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space6 * s,
        vertical: AppDesignSystem.space2 * s,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.error,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusRound * s),
      ),
      child: Text(
        text,
        style:         AppTypography.captionSmall(
          context,
          color: textColor ?? AppColors.getTextInverse(context),
          weight: AppTypography.bold,
        ),
      ),
    );
  }
}

/// ==================== AVATAR ====================
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final IconData? icon;
  final double? size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;

  const AppAvatar({
    Key? key,
    this.imageUrl,
    this.initials,
    this.icon,
    this.size,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);
    final avatarSize = (size ?? 40) * s;

    Widget avatarChild;
    if (imageUrl != null) {
      avatarChild = CircleAvatar(
        radius: avatarSize / 2,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: backgroundColor ?? AppColors.getSurfaceContainerLow(context),
      );
    } else if (initials != null) {
      avatarChild = CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: backgroundColor ?? AppColors.primary,
        child: Text(
          initials!,
          style: AppTypography.title(
            context,
            color: foregroundColor ?? AppColors.getTextInverse(context),
            weight: AppTypography.semiBold,
          ),
        ),
      );
    } else {
      avatarChild = CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: backgroundColor ?? AppColors.getSurfaceContainerLow(context),
        child: Icon(
          icon ?? Icons.person,
          color: foregroundColor ?? AppColors.getTextTertiary(context),
          size: avatarSize * 0.5,
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarChild);
    }

    return avatarChild;
  }
}



