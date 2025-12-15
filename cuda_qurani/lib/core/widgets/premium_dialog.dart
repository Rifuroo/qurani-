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
          color: AppColors.getSurface(context),
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
                    AppColors.getWarning(context).withValues(alpha: 0.2),
                    AppColors.getWarningLight(context).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                color: AppColors.getWarning(context),
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
                color: AppColors.getTextPrimary(context),
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
                color: AppColors.getWarning(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusRound * s),
              ),
              child: Text(
                featureName,
                style: TextStyle(
                  fontSize: 14 * s,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.getWarning(context),
                ),
              ),
            ),

            SizedBox(height: AppDesignSystem.space12 * s),

            // Description
            Text(
              featureDesc,
              style: TextStyle(
                fontSize: 14 * s,
                color: AppColors.getTextSecondary(context),
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
                color: AppColors.getTextTertiary(context),
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
                        side: BorderSide(color: AppColors.getBorderLight(context)),
                      ),
                    ),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        fontSize: 14 * s,
                        fontWeight: AppTypography.medium,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12 * s),

                // See Premium button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.getPrimaryLight(context), AppColors.getPrimaryLight(context)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium * s),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.getPrimaryLight(context).withValues(alpha: 0.3),
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
                              color: AppColors.getTextInverse(context),
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
          color: AppColors.getSurface(context),
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
                    AppColors.getWarning(context).withValues(alpha: 0.2),
                    AppColors.getWarningLight(context).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                color: AppColors.getWarning(context),
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
                color: AppColors.getTextPrimary(context),
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
                        color: AppColors.getTextSecondary(context),
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
          color: AppColors.getSuccess(context),
          size: 18 * s,
        ),
        SizedBox(width: 8 * s),
        Text(
          text,
          style: TextStyle(
            fontSize: 14 * s,
            color: AppColors.getTextPrimary(context),
          ),
        ),
      ],
    ),
  );
}
