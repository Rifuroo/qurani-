// lib/core/widgets/premium_gate.dart
// Widget to gate premium features with lock overlay

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';
import 'package:cuda_qurani/models/premium_features.dart';
import 'package:cuda_qurani/core/widgets/premium_dialog.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

/// Wraps a widget and shows lock overlay if user doesn't have premium access
class PremiumGate extends StatelessWidget {
  final PremiumFeature feature;
  final Widget child;
  final Widget? lockedChild;
  final bool showLockIcon;
  final bool showLabel;

  const PremiumGate({
    Key? key,
    required this.feature,
    required this.child,
    this.lockedChild,
    this.showLockIcon = true,
    this.showLabel = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumProvider>(
      builder: (context, premium, _) {
        if (premium.canAccess(feature)) {
          return child;
        }

        // Show locked state
        return lockedChild ?? _buildLockedWidget(context, feature);
      },
    );
  }

  Widget _buildLockedWidget(BuildContext context, PremiumFeature feature) {
    final s = AppDesignSystem.getScaleFactor(context);

    return GestureDetector(
      onTap: () => showPremiumFeatureDialog(context, feature),
      child: Stack(
        children: [
          // Blurred/disabled content
          Opacity(
            opacity: 0.4,
            child: IgnorePointer(child: child),
          ),
          // Lock overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(8 * s),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF39C12).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: const Color(0xFFF39C12),
                      size: 20 * s,
                    ),
                  ),
                  if (showLabel) ...[
                    SizedBox(height: 4 * s),
                    Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 10 * s,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF39C12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simpler gate that just shows a lock icon badge
class PremiumBadge extends StatelessWidget {
  final PremiumFeature feature;
  final Widget child;

  const PremiumBadge({
    Key? key,
    required this.feature,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumProvider>(
      builder: (context, premium, _) {
        if (premium.canAccess(feature)) {
          return child;
        }

        final s = AppDesignSystem.getScaleFactor(context);

        return GestureDetector(
          onTap: () => showPremiumFeatureDialog(context, feature),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: 0.5,
                child: IgnorePointer(child: child),
              ),
              Positioned(
                top: -4 * s,
                right: -4 * s,
                child: Container(
                  padding: EdgeInsets.all(4 * s),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF39C12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 10 * s,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Gate for switches/toggles - shows disabled switch for free users
class PremiumSwitch extends StatelessWidget {
  final PremiumFeature feature;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  const PremiumSwitch({
    Key? key,
    required this.feature,
    required this.value,
    this.onChanged,
    this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumProvider>(
      builder: (context, premium, _) {
        final canAccess = premium.canAccess(feature);
        final s = AppDesignSystem.getScaleFactor(context);

        return Row(
          children: [
            if (label != null) ...[
              Expanded(
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 14 * s,
                    color: canAccess ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
            if (!canAccess)
              Padding(
                padding: EdgeInsets.only(right: 8 * s),
                child: GestureDetector(
                  onTap: () => showPremiumFeatureDialog(context, feature),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 2 * s),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4 * s),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock,
                          size: 10 * s,
                          color: const Color(0xFFF39C12),
                        ),
                        SizedBox(width: 2 * s),
                        Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 8 * s,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF39C12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Switch(
              value: canAccess ? value : false,
              onChanged: canAccess
                  ? onChanged
                  : (_) => showPremiumFeatureDialog(context, feature),
              activeTrackColor: const Color(0xFF4CAF50),
              inactiveThumbColor: AppColors.borderMedium,
            ),
          ],
        );
      },
    );
  }
}

/// Check access and show dialog if not premium
bool checkPremiumAccess(BuildContext context, PremiumFeature feature) {
  final premium = context.read<PremiumProvider>();
  if (premium.canAccess(feature)) {
    return true;
  }
  showPremiumFeatureDialog(context, feature);
  return false;
}



