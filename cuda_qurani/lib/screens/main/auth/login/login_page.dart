// lib/screens/auth/login_page.dart

import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/screens/main/auth/register/register_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/design_system/app_design_system.dart';
import '../../../../core/widgets/app_components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('auth');
    setState(() {
      _translations = trans;
    });
  }

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isEmailLoginLoading = false; // ✅ Separate loading for email login
  bool _isGoogleLoginLoading = false; // ✅ Separate loading for Google login
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // Warm up Google Sign In early to reduce chooser delay
    AuthService().warmUpGoogleSignIn();
    _loadTranslations();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isEmailLoginLoading = true; // ✅ Only email login loading
    });

    print('🔐 LoginPage: Starting login for ${_emailController.text.trim()}');

    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    print('🔐 LoginPage: Login result = $success');

    setState(() {
      _isEmailLoginLoading = false; // ✅ Stop email login loading
    });

    if (success && mounted) {
      // print('✅ LoginPage: Login SUCCESS! Navigating to HomePage...');

      // ScaffoldMessenger.of(context).showSnackBar(
      //   AppComponentStyles.successSnackBar(
      //     message: 'Login berhasil!',
      //     duration: const Duration(seconds: 1),
      //   ),
      // );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } else if (!success && mounted) {
      // print('❌ LoginPage: Login FAILED - ${authProvider.errorMessage}');
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(
          message: authProvider.errorMessage ?? 'Login gagal',
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    print('🔐 LoginPage: ===== STARTING Google Sign In =====');

    setState(() {
      _isGoogleLoginLoading = true; // ✅ Only Google login loading
    });

    print(
      '🔐 LoginPage: Button clicked, calling authProvider.signInWithGoogle()...',
    );

    try {
      print('🔐 LoginPage: Waiting for Google Sign In to complete...');
      final success = await authProvider.signInWithGoogle();
      print('🔐 LoginPage: Google Sign In completed! Result: $success');

      if (!mounted) {
        print(
          '⚠️ LoginPage: Widget not mounted after sign in, skipping navigation',
        );
        return;
      }

      setState(() {
        _isGoogleLoginLoading = false; // ✅ Stop Google login loading
      });

      print('🔐 LoginPage: ===== SIGN IN RESULT =====');
      print('   - Success: $success');
      print('   - Error message: ${authProvider.errorMessage ?? "null"}');
      print('   - Is authenticated: ${authProvider.isAuthenticated}');
      print('   - Current user: ${authProvider.currentUser?.email ?? "null"}');
      print('   - User ID: ${authProvider.userId ?? "null"}');

      if (success) {
        print('✅ LoginPage: Google Sign In SUCCESS! Preparing navigation...');

        // Double check authentication status
        bool isAuth = authProvider.isAuthenticated;
        print('   - Initial isAuthenticated check: $isAuth');

        if (!isAuth) {
          print('⚠️ isAuthenticated is false, waiting for state update...');
          // Wait a bit longer for auth state to update
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 200));
            isAuth = authProvider.isAuthenticated;
            print('   - Check ${i + 1}/5: isAuthenticated = $isAuth');
            if (isAuth) break;
          }
        }

        if (!mounted) {
          print('⚠️ LoginPage: Widget not mounted before navigation');
          return;
        }

        print('✅ LoginPage: Showing success message...');
        ScaffoldMessenger.of(context).showSnackBar(
          AppComponentStyles.successSnackBar(
            message: 'Login berhasil!',
            duration: const Duration(seconds: 1),
          ),
        );

        print('✅ LoginPage: Navigating to HomePage...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );

        print('✅ LoginPage: ===== NAVIGATION COMPLETED =====');
      } else {
        print('❌ LoginPage: ===== SIGN IN FAILED =====');
        print('   - Success: $success');
        print('   - Is authenticated: ${authProvider.isAuthenticated}');
        print('   - Error: ${authProvider.errorMessage ?? "No error message"}');

        ScaffoldMessenger.of(context).showSnackBar(
          AppComponentStyles.errorSnackBar(
            message:
                authProvider.errorMessage ??
                'Google Sign In gagal. Silakan coba lagi.',
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ LoginPage: ===== EXCEPTION CAUGHT =====');
      print('   - Error: $e');
      print('   - Type: ${e.runtimeType}');
      print('   - Stack trace: $stackTrace');

      if (!mounted) {
        print('⚠️ LoginPage: Widget not mounted in catch block');
        return;
      }

      setState(() {
        _isGoogleLoginLoading = false; // ✅ Stop Google login loading
      });

      String errorMessage = 'Terjadi kesalahan saat login dengan Google';

      // Handle specific errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('dibatalkan') ||
          errorString.contains('cancelled')) {
        errorMessage = 'Login dibatalkan';
      } else if (errorString.contains('network') ||
          errorString.contains('connection')) {
        errorMessage = 'Periksa koneksi internet Anda';
      } else if (errorString.contains('id token')) {
        errorMessage =
            'Gagal mendapatkan token. Pastikan konfigurasi Google Sign In sudah benar.';
      } else if (errorString.contains('supabase')) {
        errorMessage = 'Gagal menghubungkan ke server. Silakan coba lagi.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppComponentStyles.errorSnackBar(message: errorMessage));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppPadding.horizontal(context, AppDesignSystem.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppMargin.customGap(context, AppDesignSystem.space40),

                // Logo Section
                _buildLogoSection(s),

                AppMargin.customGap(context, AppDesignSystem.space32),

                // Welcome Text
                _buildWelcomeText(context),

                AppMargin.customGap(context, AppDesignSystem.space32),

                // Form Section
                _buildFormSection(context, s),

                AppMargin.customGap(context, AppDesignSystem.space24),

                // Divider
                _buildDivider(context, s),

                AppMargin.customGap(context, AppDesignSystem.space24),

                // Google Sign In Button
                _buildGoogleButton(context, s),

                AppMargin.gap(context),

                // Register Link
                _buildRegisterLink(context),

                AppMargin.customGap(context, AppDesignSystem.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== LOGO SECTION ====================
  Widget _buildLogoSection(double s) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 140 * s,
            height: 140 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppDesignSystem.radiusLarge * s,
              ),
            ),
            child: Center(
              child: Text(
                'ﲐ',
                style: TextStyle(
                  fontFamily: 'surah_names',
                  fontSize: 90 * s,
                  color: AppColors.getPrimary(context),
                  height: 1.0,
                ),
              ),
            ),
          ),
          AppMargin.gap(context),
          Image.asset(
            'assets/images/qurani-white-text.png',
            height: 28 * s,
            color: AppColors.getPrimary(context),
            errorBuilder: (context, error, stackTrace) {
              return Text(
                'Qurani',
                style: AppTypography.h2(
                  context,
                  color: AppColors.getPrimary(context),
                  weight: AppTypography.bold,
                ),
              );
            },
          ),
          SizedBox(height: 4 * s),
          Text(
            'Hafidz',
            style: AppTypography.label(
              context,
              color: AppColors.getPrimary(context),
              weight: AppTypography.semiBold,
            ).copyWith(letterSpacing: 2 * s),
          ),
        ],
      ),
    );
  }

  // ==================== WELCOME TEXT ====================
  Widget _buildWelcomeText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'login.login_text')
              : 'Login',
          style: AppTypography.displaySmall(
            context,
            color: AppColors.getTextPrimary(context),
            weight: AppTypography.bold,
          ),
        ),
      ],
    );
  }

  // ==================== FORM SECTION ====================
  Widget _buildFormSection(BuildContext context, double s) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppTypography.body(
              context,
              color: AppColors.getTextPrimary(context),
              weight: AppTypography.medium,
            ),
            decoration: AppComponentStyles.inputDecoration(
              context: context,
              labelText: _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'login.email_text')
                  : 'Email',
              prefixIcon: Padding(
                padding: EdgeInsets.only(
                  left: AppDesignSystem.space16 * s,
                  right: AppDesignSystem.space12 * s,
                ),
                child: Icon(
                  Icons.email_outlined,
                  color: AppColors.getTextTertiary(context),
                  size: AppDesignSystem.iconLarge * s,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'login.null_email_text')
                    : 'Email cannot be empty';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(
                        _translations,
                        'login.error_email_format_text',
                      )
                    : 'Invalid email format';
              }
              return null;
            },
          ),

          AppMargin.gap(context),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: AppTypography.body(
              context,
              color: AppColors.getTextPrimary(context),
              weight: AppTypography.medium,
            ),
            decoration: AppComponentStyles.inputDecoration(
              context: context,
              labelText: _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'login.password_text')
                  : 'Password',
              prefixIcon: Padding(
                padding: EdgeInsets.only(
                  left: AppDesignSystem.space16 * s,
                  right: AppDesignSystem.space12 * s,
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: AppColors.getTextTertiary(context),
                  size: AppDesignSystem.iconLarge * s,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.getTextTertiary(context),
                  size: AppDesignSystem.iconLarge * s,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(
                        _translations,
                        'login.null_password_text',
                      )
                    : 'Password cannot be empty';
              }
              if (value.length < 6) {
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(
                        _translations,
                        'login.error_password_length_text',
                      )
                    : 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          AppMargin.gap(context),

          // Remember Me & Forgot Password
          _buildRememberAndForgot(context, s),

          AppMargin.gapLarge(context),

          // Login Button
          _buildLoginButton(context),
        ],
      ),
    );
  }

  // ==================== REMEMBER & FORGOT ====================
  Widget _buildRememberAndForgot(BuildContext context, double s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              height: AppDesignSystem.scale(context, 20),
              width: AppDesignSystem.scale(context, 20),
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.getPrimary(context);
                    }
                    return null;
                  },
                ),
                checkColor: AppColors.getTextInverse(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusXSmall * s,
                  ),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            SizedBox(width: AppDesignSystem.space8 * s),
            Text(
              _translations.isNotEmpty
                  ? LanguageHelper.tr(_translations, 'login.remember_me_text')
                  : 'Remember me',
              style: AppTypography.body(
                context,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
        AppTextButton(
          text: _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'login.forgot_password_text')
              : 'Forgot Password?',
          onPressed: () {
            // Handle forgot password
          },
          color: AppColors.getPrimary(context),
        ),
      ],
    );
  }

  // ==================== LOGIN BUTTON ====================
  Widget _buildLoginButton(BuildContext context) {
    return AppButton(
      text: _translations.isNotEmpty
          ? LanguageHelper.tr(_translations, 'login.login_text')
          : 'Login',
      onPressed: _isEmailLoginLoading ? null : _handleLogin,
      loading: _isEmailLoginLoading,
      fullWidth: true,
    );
  }

  // ==================== DIVIDER ====================
  Widget _buildDivider(BuildContext context, double s) {
    return Row(
      children: [
        Expanded(
          child: AppDivider(color: AppColors.getDivider(context), thickness: 1 * s),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space16 * s,
          ),
          child: Text(
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'login.or_text')
                : 'Or',
            style: AppTypography.caption(
              context,
              color: AppColors.getTextTertiary(context),
            ),
          ),
        ),
        Expanded(
          child: AppDivider(color: AppColors.getDivider(context), thickness: 1 * s),
        ),
      ],
    );
  }

  // ==================== GOOGLE BUTTON ====================
  Widget _buildGoogleButton(BuildContext context, double s) {
    final double iconSize = 28 * s;
    // ✅ Disable only when Google login is loading
    final isDisabled = _isGoogleLoginLoading;

    return SizedBox(
      height: AppDesignSystem.scale(context, AppDesignSystem.buttonHeightLarge),
      child: OutlinedButton(
        onPressed: isDisabled ? null : _handleGoogleSignIn,
        style: AppComponentStyles.secondaryButton(context).copyWith(
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(
              horizontal: AppDesignSystem.scale(context, 16),
            ),
          ),
        ),
        child:
            _isGoogleLoginLoading // ✅ Only show loading for Google login
            ? SizedBox(
                height: AppDesignSystem.scale(context, 20),
                width: AppDesignSystem.scale(context, 20),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.getPrimary(context)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google-icon.png',
                    height: iconSize,
                    width: iconSize,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.g_mobiledata,
                        size: AppDesignSystem.iconLarge * s,
                        color: AppColors.getTextPrimary(context),
                      );
                    },
                  ),
                  SizedBox(width: 12 * s),
                  Text(
                    _translations.isNotEmpty
                        ? LanguageHelper.tr(
                            _translations,
                            'login.google_sign_in_text',
                          )
                        : 'Login with Google',
                    style: AppTypography.label(
                      context,
                      color: AppColors.getTextPrimary(context),
                      weight: AppTypography.semiBold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ==================== REGISTER LINK ====================
  Widget _buildRegisterLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'login.null_account_text')
              : 'Don\'t have an account?',
          style: AppTypography.body(context, color: AppColors.getTextSecondary(context)),
        ),
        AppTextButton(
          text: _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'login.sign_up_now_text')
              : 'Sign up now',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            );
          },
          color: AppColors.getPrimary(context),
        ),
      ],
    );
  }
}
