// lib/core/widgets/rate_limit_banner.dart

import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

/// Red banner widget to show rate limit warnings
class RateLimitBanner extends StatelessWidget {
  final int current;
  final int limit;
  final int remaining;
  final String resetTime;
  final String plan;
  final bool isExceeded;
  final VoidCallback? onUpgradePressed;
  final VoidCallback? onDismiss;

  const RateLimitBanner({
    super.key,
    required this.current,
    required this.limit,
    required this.remaining,
    required this.resetTime,
    required this.plan,
    this.isExceeded = false,
    this.onUpgradePressed,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (isExceeded) {
      return _buildExceededBanner(context);
    }
    
    // Show warning when only 1 session remaining
    if (remaining <= 1 && remaining > 0) {
      return _buildWarningBanner(context);
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildExceededBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.getError(context),
            AppColors.getErrorDark(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.getError(context).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.getTextInverse(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.block_rounded,
                color: AppColors.getTextInverse(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Batas Harian Tercapai',
                    style: TextStyle(
                      color: AppColors.getTextInverse(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reset dalam $resetTime',
                    style: TextStyle(
                      color: AppColors.getTextInverse(context).withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onUpgradePressed != null)
              TextButton(
                onPressed: onUpgradePressed,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.getTextInverse(context),
                  foregroundColor: AppColors.getError(context),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade600,
            Colors.orange.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.getTextInverse(context).withValues(alpha: 0.9),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sisa $remaining dari $limit sesi hari ini',
                style: TextStyle(
                  color: AppColors.getTextInverse(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onUpgradePressed != null)
              GestureDetector(
                onTap: onUpgradePressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.getTextInverse(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Upgrade',
                    style: TextStyle(
                      color: AppColors.getTextInverse(context),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close,
                  color: AppColors.getTextInverse(context).withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small badge showing session count (for non-intrusive display)
class RateLimitBadge extends StatelessWidget {
  final int current;
  final int limit;
  final String plan;
  final VoidCallback? onTap;

  const RateLimitBadge({
    super.key,
    required this.current,
    required this.limit,
    required this.plan,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = (limit - current) <= 1;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLow 
              ? AppColors.getErrorContainer(context)
              : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLow 
                ? AppColors.getError(context)
                : AppColors.getBorderMedium(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLow ? Icons.warning_amber_rounded : Icons.layers_outlined,
              size: 14,
              color: isLow ? AppColors.getError(context) : AppColors.getTextSecondary(context),
            ),
            const SizedBox(width: 4),
            Text(
              '$current/$limit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isLow ? AppColors.getError(context) : AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen overlay when rate limit is exceeded
class RateLimitExceededOverlay extends StatelessWidget {
  final int limit;
  final String resetTime;
  final String plan;
  final VoidCallback? onUpgradePressed;
  final VoidCallback? onClose;

  const RateLimitExceededOverlay({
    super.key,
    required this.limit,
    required this.resetTime,
    required this.plan,
    this.onUpgradePressed,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.getScrim(context),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.getError(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    color: AppColors.getTextInverse(context),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Batas Harian Tercapai',
                  style: TextStyle(
                    color: AppColors.getTextInverse(context),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Kamu sudah menggunakan $limit sesi hari ini.\nReset dalam $resetTime.',
                  style: TextStyle(
                    color: AppColors.getTextInverse(context).withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (onUpgradePressed != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onUpgradePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getWarning(context),
                        foregroundColor: AppColors.getTextPrimary(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Upgrade ke Premium',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sesi unlimited & fitur premium lainnya',
                    style: TextStyle(
                      color: AppColors.getTextInverse(context).withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (onClose != null)
                  TextButton(
                    onPressed: onClose,
                    child: Text(
                      'Kembali',
                      style: TextStyle(
                        color: AppColors.getTextInverse(context).withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// =====================================================
// SURAH MISMATCH WARNING WIDGET
// =====================================================

/// Banner to warn user when they're reading a different surah than selected
// class SurahMismatchBanner extends StatelessWidget {
//   final String warningMessage;
//   final String? detectedSurahName;
//   final VoidCallback? onDismiss;

//   const SurahMismatchBanner({
//     super.key,
//     required this.warningMessage,
//     this.detectedSurahName,
//     this.onDismiss,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             Colors.purple.shade600,
//             Colors.purple.shade800,
//           ],
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.purple.withOpacity(0.3),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const Icon(
//                 Icons.warning_amber_rounded,
//                 color: AppColors.textInverse,
//                 size: 24,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text(
//                     'Surah Tidak Sesuai',
//                     style: TextStyle(
//                       color: AppColors.textInverse,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     warningMessage,
//                     style: TextStyle(
//                       color: AppColors.getTextInverse(context).withOpacity(0.9),
//                       fontSize: 12,
//                     ),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//             if (onDismiss != null)
//               GestureDetector(
//                 onTap: onDismiss,
//                 child: Icon(
//                   Icons.close,
//                   color: AppColors.getTextInverse(context).withOpacity(0.7),
//                   size: 20,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// =====================================================
// DURATION LIMIT WIDGETS
// =====================================================

/// Banner untuk warning durasi (3 menit tersisa)
class DurationWarningBanner extends StatelessWidget {
  final String warningMessage;
  final VoidCallback? onDismiss;

  const DurationWarningBanner({
    super.key,
    required this.warningMessage,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.getWarning(context),
            AppColors.getWarningDark(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              color: AppColors.getTextInverse(context),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                warningMessage,
                style: TextStyle(
                  color: AppColors.getTextInverse(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close,
                  color: AppColors.getTextInverse(context).withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen overlay ketika durasi limit tercapai
class DurationLimitExceededOverlay extends StatelessWidget {
  final String message;
  final VoidCallback? onUpgradePressed;
  final VoidCallback? onClose;

  const DurationLimitExceededOverlay({
    super.key,
    required this.message,
    this.onUpgradePressed,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.getScrim(context),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.getWarning(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_off_outlined,
                    color: AppColors.getTextInverse(context),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Waktu Habis',
                  style: TextStyle(
                    color: AppColors.getTextInverse(context),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.getTextInverse(context).withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upgrade ke Premium untuk sesi tanpa batas waktu',
                  style: TextStyle(
                    color: AppColors.getTextInverse(context).withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (onUpgradePressed != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onUpgradePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getWarning(context),
                        foregroundColor: AppColors.getTextPrimary(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.all_inclusive, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Upgrade ke Premium',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (onClose != null)
                  TextButton(
                    onPressed: onClose,
                    child: Text(
                      'Selesai',
                      style: TextStyle(
                        color: AppColors.getTextInverse(context).withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
