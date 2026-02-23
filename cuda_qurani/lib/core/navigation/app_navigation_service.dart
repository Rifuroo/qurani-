import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/screens/main/stt/controllers/stt_controller.dart';

/// Centralized navigation service to manage standardized exit and jump behaviors.
/// This ensures a consistent 3-level navigation model:
/// - Level 0: Mushaf / Home (Root)
/// - Level 1: Action Screens (Tafsir, Similarity, etc.)
/// - Level 2+: Drill-Down (Phrase Detail, etc.)
class AppNavigationService {
  /// Named route for the Mushaf (Experience Root).
  static const String mushafRoute = '/mushaf';

  /// Safely pops the current screen one level back.
  /// Equivalent to the back arrow (←).
  static void safePop(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.maybePop(context);
    }
  }

  /// Exits the entire action flow and returns to the root Mushaf view.
  /// Equivalent to the Close button (X).
  static void exitToRoot(BuildContext context) {
    // Attempt to pop until the Mushaf route is found.
    // If not found (e.g., deep linked directly), stop at the first route.
    Navigator.popUntil(context, (route) {
      return route.settings.name == mushafRoute || route.isFirst;
    });
  }

  /// Exits the current navigation flow and performs a jump to a specific Ayah.
  /// Used in similarity cards or search results to ensure all auxiliary screens
  /// are closed before displaying the target Ayah in the main view.
  static void exitFlowAndJumpToAyah(
    BuildContext context, {
    required int surahId,
    required int ayahNumber,
  }) {
    try {
      // 1. Get the controller before we lose context/stack
      final sttController = context.read<SttController>();

      // 2. Perform the jump on the controller
      sttController.jumpToAyah(surahId, ayahNumber);

      // 3. Clear the whole stack back to Level 0 (Mushaf)
      exitToRoot(context);
    } catch (e) {
      debugPrint('NavigationService Error: $e');
      // If controller read fails, just try to pop to be safe
      Navigator.maybePop(context);
    }
  }
}
