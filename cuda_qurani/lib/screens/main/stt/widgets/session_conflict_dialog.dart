// lib/screens/main/stt/widgets/session_conflict_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.bookmark, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Session Ditemukan', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anda memiliki progress sebelumnya:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // Progress info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.menu_book, 'Posisi', 'Ayah $ayah, Kata ${position + 1}'),
                  if (ayahsWithProgress > 0)
                    _buildInfoRow(Icons.format_list_numbered, 'Ayat dibaca', '$ayahsWithProgress ayat'),
                  if (totalWords > 0)
                    _buildInfoRow(Icons.text_fields, 'Total kata', '$totalWords kata'),
                  if (matchedWords > 0 || mismatchedWords > 0)
                    _buildWordStatsRow(matchedWords, mismatchedWords),
                  if (accuracy > 0)
                    _buildAccuracyRow(accuracy),
                  if (formattedTime.isNotEmpty)
                    _buildInfoRow(Icons.access_time, 'Terakhir', formattedTime),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Apa yang ingin Anda lakukan?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
            child: const Text('Batal'),
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
                foregroundColor: Colors.orange,
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
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordStatsRow(int matched, int mismatched) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 4),
          Text(
            '$matched benar',
            style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Icon(Icons.cancel, size: 16, color: Colors.red[400]),
          const SizedBox(width: 4),
          Text(
            '$mismatched salah',
            style: TextStyle(color: Colors.red[600], fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyRow(dynamic accuracy) {
    final acc = accuracy is num ? accuracy.toDouble() : 0.0;
    final color = acc >= 80 ? Colors.green : (acc >= 60 ? Colors.orange : Colors.red);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.analytics, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'Akurasi: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
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



