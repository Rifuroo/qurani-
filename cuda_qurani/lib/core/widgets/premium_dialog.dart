// lib/core/widgets/premium_dialog.dart
// Dialog to prompt users to upgrade to premium

import 'package:flutter/material.dart';
import 'package:cuda_qurani/models/premium_features.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/screens/main/home/screens/premium_offer_page.dart';

/// Show premium feature dialog for a specific feature
void showPremiumFeatureDialog(BuildContext context, PremiumFeature feature) {
  final s = AppDesignSystem.getScaleFactor(context);
  final featureName = getFeatureName(feature);
  final featureDesc = getFeatureDescription(feature);

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
      ),
      elevation: AppDesignSystem.elevationHigh,
      child: Container(
        padding: EdgeInsets.all(AppDesignSystem.space24 * s),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock Icon with gradient background
            Container(
              width: 64 * s,
              height: 64 * s,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF39C12).withValues(alpha: 0.2),
                    const Color(0xFFF5B041).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                color: const Color(0xFFF39C12),
                size: 32 * s,
              ),
            ),

            SizedBox(height: AppDesignSystem.space16 * s),

            // Title
            Text(
              'Premium Feature',
              style: TextStyle(
                fontSize: 20 * s,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppDesignSystem.space8 * s),

            // Feature name
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * s,
                vertical: 6 * s,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF39C12).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusRound * s),
              ),
              child: Text(
                featureName,
                style: TextStyle(
                  fontSize: 14 * s,
                  fontWeight: AppTypography.semiBold,
                  color: const Color(0xFFF39C12),
                ),
              ),
            ),

            SizedBox(height: AppDesignSystem.space12 * s),

            // Description
            Text(
              featureDesc,
              style: TextStyle(
                fontSize: 14 * s,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppDesignSystem.space8 * s),

            // Upgrade message
            Text(
              'Upgrade to Premium to unlock this feature and many more!',
              style: TextStyle(
                fontSize: 12 * s,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppDesignSystem.space24 * s),

            // Buttons
            Row(
              children: [
                // Maybe Later button
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12 * s),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
                        side: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        fontSize: 14 * s,
                        fontWeight: AppTypography.medium,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12 * s),

                // See Premium button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3FCCB8), Color(0xFF52E8D4)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3FCCB8).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PremiumOfferPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12 * s),
                          child: Text(
                            'See Premium',
                            style: TextStyle(
                              fontSize: 14 * s,
                              fontWeight: AppTypography.semiBold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Show generic premium upgrade dialog
void showPremiumUpgradeDialog(BuildContext context) {
  final s = AppDesignSystem.getScaleFactor(context);

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
      ),
      elevation: AppDesignSystem.elevationHigh,
      child: Container(
        padding: EdgeInsets.all(AppDesignSystem.space24 * s),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge * s),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star Icon
            Container(
              width: 64 * s,
              height: 64 * s,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF39C12).withValues(alpha: 0.2),
                    const Color(0xFFF5B041).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                color: const Color(0xFFF39C12),
                size: 32 * s,
              ),
            ),

            SizedBox(height: AppDesignSystem.space16 * s),

            // Title
            Text(
              'Upgrade to Premium',
              style: TextStyle(
                fontSize: 20 * s,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppDesignSystem.space12 * s),

            // Benefits
            _buildBenefitRow(context, Icons.check_circle, 'Mistake Detection'),
            _buildBenefitRow(context, Icons.check_circle, 'Tajweed Analysis'),
            _buildBenefitRow(context, Icons.check_circle, 'Advanced Analytics'),
            _buildBenefitRow(context, Icons.check_circle, 'Unlimited Goals'),

            SizedBox(height: AppDesignSystem.space24 * s),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Not Now',
                      style: TextStyle(
                        fontSize: 14 * s,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12 * s),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    text: 'See Plans',
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PremiumOfferPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildBenefitRow(BuildContext context, IconData icon, String text) {
  final s = AppDesignSystem.getScaleFactor(context);

  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4 * s),
    child: Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF4CAF50),
          size: 18 * s,
        ),
        SizedBox(width: 8 * s),
        Text(
          text,
          style: TextStyle(
            fontSize: 14 * s,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}



