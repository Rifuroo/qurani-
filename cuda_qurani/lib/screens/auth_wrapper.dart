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
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // ✅ Listen for widget clicks when app is running
    HomeWidget.widgetClicked.listen(_handleDeepLink);
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
                     highlightAyahId: ayahNum, // highlightAyahId for scrolling
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
          print('   → Showing LOADING screen');
          return Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.getPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Memuat...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Authenticated -> Home
        if (auth.isAuthenticated) {
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
