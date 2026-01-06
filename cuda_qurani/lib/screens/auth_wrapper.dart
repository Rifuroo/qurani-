import 'package:cuda_qurani/screens/main/home/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import './main/auth/login/login_page.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:home_widget/home_widget.dart'; // ✅ NEW
import 'package:cuda_qurani/screens/main/stt/stt_page.dart'; // ✅ NEW
import 'package:cuda_qurani/services/local_database_service.dart'; // ✅ NEW

class AuthWrapper extends StatefulWidget {
  final int? initialPageId;
  final int? highlightAyahId;

  const AuthWrapper({
    super.key,
    this.initialPageId,
    this.highlightAyahId,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // ✅ Listen for widget clicks when app is already running
    HomeWidget.widgetClicked.listen(_handleDeepLink);
    
    // Only verify deep link if NOT passed via constructor (legacy/fallback)
    if (widget.initialPageId == null) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleDeepLink);
    }
  }

  Future<void> _handleDeepLink(Uri? uri) async {
    if (uri != null && uri.scheme == 'qurani' && uri.host == 'ayah') {
      try {
        final segments = uri.pathSegments; // Expected: [surahId, ayahNum]
        if (segments.length >= 2) {
          final surahId = int.tryParse(segments[0]);
          final ayahNum = int.tryParse(segments[1]);
          
          if (surahId != null && ayahNum != null) {
            final pageId = await LocalDatabaseService.getPageNumber(surahId, ayahNum);
             if (mounted) {
               Navigator.of(context).push(
                 MaterialPageRoute(
                   builder: (_) => SttPage(
                     pageId: pageId,
                     highlightAyahId: ayahNum,
                   ),
                 ),
               );
             }
          }
        }
      } catch (e) {
        print('Deep link error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // ✅ Show loading screen while AuthProvider is initializing
        if (auth.isLoading) {
          return Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.getPrimary(context),
                ),
              ),
            ),
          );
        }

        // Authenticated -> Home or Deep Link Page
        if (auth.isAuthenticated) {
          // ✅ DIRECT NAVIGATION IF DEEP LINK PARAMS EXIST
          if (widget.initialPageId != null && widget.highlightAyahId != null) {
            print('   → Direct Deep Link to SttPage ${widget.initialPageId}');
            // Return SttPage directly instead of pushing it
            // Wrap in Scaffold to be safe, or just return the page
            return SttPage(
              pageId: widget.initialPageId!,
              highlightAyahId: widget.highlightAyahId,
            );
          }

          print('   → Navigating to HOME');
          return const HomePage();
        }

        // Not authenticated -> Login
        print('   → Navigating to LOGIN');
        return const LoginPage();
      },
    );
  }
}
