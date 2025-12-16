import 'package:cuda_qurani/screens/main/home/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import './main/auth/login/login_page.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _wasAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // 🔍 DEBUG: Log auth state
        print('🎯 AuthWrapper: Building...');
        print('   - isLoading: ${auth.isLoading}');
        print('   - isAuthenticated: ${auth.isAuthenticated}');
        print('   - currentUser: ${auth.currentUser?.email ?? "null"}');
        
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.getPrimary(context)),
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
          // ✅ Refresh PremiumProvider ketika baru login
          if (!_wasAuthenticated) {
            _wasAuthenticated = true;
            // Use addPostFrameCallback to avoid calling during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              print('🔓 AuthWrapper: User authenticated, refreshing PremiumProvider...');
              context.read<PremiumProvider>().refresh();
            });
          }
          print('   → Navigating to HOME');
          return const HomePage();
        }

        // Not authenticated -> Login
        _wasAuthenticated = false;
        print('   → Navigating to LOGIN');
        return const LoginPage();
      },
    );
  }
}



