import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

class AchievementUnlockedDialog extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? description;
  final VoidCallback? onDismiss;
  final VoidCallback? onShare;

  const AchievementUnlockedDialog({
    Key? key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.description,
    this.onDismiss,
    this.onShare,
  }) : super(key: key);

  @override
  State<AchievementUnlockedDialog> createState() => _AchievementUnlockedDialogState();

  static Future<void> show(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    String? description,
    VoidCallback? onShare,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AchievementUnlockedDialog(
        emoji: emoji,
        title: title,
        subtitle: subtitle,
        description: description,
        onShare: onShare,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _AchievementUnlockedDialogState extends State<AchievementUnlockedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getWarning(context).withValues(alpha: 0.2),
                  AppColors.getWarningLight(context).withValues(alpha: 0.1),
                  AppColors.getSurface(context),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getWarning(context).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Confetti/Stars decoration
                const Text(
                  '✨ 🎉 ✨',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 8),
                
                // Achievement Unlocked text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.getWarning(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ACHIEVEMENT UNLOCKED!',
                      style: TextStyle(
                        color: AppColors.getTextInverse(context),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Emoji with glow effect
                Container(
                  width: 80,
                  height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.getSurface(context),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.getWarning(context).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  child: Center(
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // Subtitle
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),

                // Description (optional)
                if (widget.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextTertiary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.onShare != null) ...[
                      OutlinedButton.icon(
                        onPressed: widget.onShare,
                        icon: Icon(Icons.share, size: 18, color: AppColors.getWarning(context)),
                        label: Text('Share', style: TextStyle(color: AppColors.getWarning(context))),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.getWarning(context),
                          side: BorderSide(color: AppColors.getWarning(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton(
                      onPressed: widget.onDismiss ?? () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getWarning(context),
                        foregroundColor: AppColors.getTextInverse(context),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Awesome!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
