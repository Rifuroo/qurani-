// lib/screens/main/stt/widgets/session_conflict_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

class SessionConflictDialog extends StatelessWidget {
  final Map<String, dynamic> existingSession;
  final VoidCallback onContinue;
  final VoidCallback onStartFresh;
  final VoidCallback? onCancel;

  const SessionConflictDialog({
    super.key,
    required this.existingSession,
    required this.onContinue,
    required this.onStartFresh,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Extract dynamic data from backend
    final ayah = existingSession['ayah'] ?? 0;
    final position = existingSession['position'] ?? 0;
    final updatedAt = existingSession['updated_at'] ?? '';
    
    // Stats from backend calculation
    final stats = existingSession['stats'] as Map<String, dynamic>? ?? {};
    final totalWords = stats['total_words'] ?? 0;
    final matchedWords = stats['matched_words'] ?? 0;
    final mismatchedWords = stats['mismatched_words'] ?? 0;
    final accuracy = stats['accuracy'] ?? 0.0;
    final ayahsWithProgress = stats['ayahs_with_progress'] ?? 0;

    // Format updated_at timestamp
    String formattedTime = '';
    if (updatedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(updatedAt);
        formattedTime = DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
      } catch (_) {
        formattedTime = updatedAt;
      }
    }

    return AlertDialog(
      backgroundColor: AppColors.getSurface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Session Ditemukan',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda memiliki progress sebelumnya:',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            
            // Progress info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceContainerLow(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.menu_book, 'Posisi', 'Ayah $ayah, Kata ${position + 1}', context),
                  if (ayahsWithProgress > 0)
                    _buildInfoRow(Icons.format_list_numbered, 'Ayat dibaca', '$ayahsWithProgress ayat', context),
                  if (totalWords > 0)
                    _buildInfoRow(Icons.text_fields, 'Total kata', '$totalWords kata', context),
                  if (matchedWords > 0 || mismatchedWords > 0)
                    _buildWordStatsRow(matchedWords, mismatchedWords, context),
                  if (accuracy > 0)
                    _buildAccuracyRow(accuracy, context),
                  if (formattedTime.isNotEmpty)
                    _buildInfoRow(Icons.access_time, 'Terakhir', formattedTime, context),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Text(
              'Apa yang ingin Anda lakukan?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel!();
            },
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.getTextSecondary(context)),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onStartFresh();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Mulai Baru'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.getWarning(context),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onContinue();
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Lanjutkan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: AppColors.getTextInverse(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.getTextSecondary(context)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: AppColors.getTextPrimary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordStatsRow(int matched, int mismatched, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: AppColors.getSuccess(context)),
          const SizedBox(width: 4),
          Text(
            '$matched benar',
            style: TextStyle(color: AppColors.getSuccess(context), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Icon(Icons.cancel, size: 16, color: AppColors.getError(context)),
          const SizedBox(width: 4),
          Text(
            '$mismatched salah',
            style: TextStyle(color: AppColors.getError(context), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyRow(dynamic accuracy, BuildContext context) {
    final acc = accuracy is num ? accuracy.toDouble() : 0.0;
    final color = acc >= 80 ? AppColors.getSuccess(context) : (acc >= 60 ? AppColors.getWarning(context) : AppColors.getError(context));
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.analytics, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'Akurasi: ',
            style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${acc.toStringAsFixed(1)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> existingSession,
    required VoidCallback onContinue,
    required VoidCallback onStartFresh,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionConflictDialog(
        existingSession: existingSession,
        onContinue: onContinue,
        onStartFresh: onStartFresh,
        onCancel: onCancel,
      ),
    );
  }
}



