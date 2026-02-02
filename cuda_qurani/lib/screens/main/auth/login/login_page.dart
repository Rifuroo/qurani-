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
      _isEmailLoginLoading = true;
    });

    print('🔐 LoginPage: Starting login for ${_emailController.text.trim()}');

    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    print('🔐 LoginPage: Login result = $success');

    if (mounted) {
      setState(() {
        _isEmailLoginLoading = false;
      });
    }

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } else if (!success && mounted) {
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
      _isGoogleLoginLoading = true;
    });

    try {
      final success = await authProvider.signInWithGoogle();
      print('🔐 LoginPage: Google Sign In completed! Result: $success');

      if (!mounted) return;

      setState(() {
        _isGoogleLoginLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppComponentStyles.successSnackBar(
            message: 'Login berhasil!',
            duration: const Duration(seconds: 1),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          AppComponentStyles.errorSnackBar(
            message: authProvider.errorMessage ?? 'Google Sign In gagal',
          ),
        );
      }
    } catch (e) {
      print('❌ LoginPage: Exception caught: $e');
      if (mounted) {
        setState(() {
          _isGoogleLoginLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          AppComponentStyles.errorSnackBar(message: 'Terjadi kesalahan saat login'),
        );
      }
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
          Hero(
            tag: 'auth_logo',
            child: Material(
              color: Colors.transparent,
              child: Container(
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
            ),
          ),
          AppMargin.gap(context),
          Hero(
            tag: 'auth_title',
            child: Material(
              color: Colors.transparent,
              child: Image.asset(
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
            ),
          ),
          SizedBox(height: 4 * s),
          Hero(
            tag: 'auth_subtitle',
            child: Material(
              color: Colors.transparent,
              child: Text(
                'Hafidz',
                style: AppTypography.label(
                  context,
                  color: AppColors.getPrimary(context),
                  weight: AppTypography.semiBold,
                ).copyWith(letterSpacing: 2 * s),
              ),
            ),
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
          _buildTextField(
            controller: _emailController,
            label: _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'login.email_or_username_text')
                : 'Email or Username',
            icon: Icons.person_outline_rounded, // Changed to person icon as it's more general
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'login.null_email_text')
                    : 'Email or Username cannot be empty';
              }
              // Removed regex to allow username login
              return null;
            },
            s: s,
          ),

          AppMargin.gap(context),

          _buildPasswordField(
            controller: _passwordController,
            label: _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'login.password_text')
                : 'Password',
            isVisible: _isPasswordVisible,
            onToggle: (val) => setState(() => _isPasswordVisible = val),
            s: s,
          ),

          AppMargin.gap(context),

          _buildRememberAndForgot(context, s),

          AppMargin.gapLarge(context),

          _buildLoginButton(context),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double s,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: AppTypography.body(
        context,
        color: AppColors.getTextPrimary(context),
        weight: AppTypography.medium,
      ),
      decoration: AppComponentStyles.inputDecoration(
        context: context,
        labelText: label,
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            left: AppDesignSystem.space16 * s,
            right: AppDesignSystem.space12 * s,
          ),
          child: Icon(
            icon,
            color: AppColors.getTextTertiary(context),
            size: AppDesignSystem.iconLarge * s,
          ),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required Function(bool) onToggle,
    required double s,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      style: AppTypography.body(
        context,
        color: AppColors.getTextPrimary(context),
        weight: AppTypography.medium,
      ),
      decoration: AppComponentStyles.inputDecoration(
        context: context,
        labelText: label,
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
            isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.getTextTertiary(context),
            size: AppDesignSystem.iconLarge * s,
          ),
          onPressed: () => onToggle(!isVisible),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'login.null_password_text')
              : 'Password cannot be empty';
        }
        if (value.length < 6) {
          return _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'login.error_password_length_text')
              : 'Password must be at least 6 characters';
        }
        return null;
      },
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
