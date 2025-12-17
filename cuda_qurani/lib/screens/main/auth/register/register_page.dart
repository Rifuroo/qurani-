// lib/screens/auth/register_page.dart

import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/providers/auth_provider.dart';
import 'package:cuda_qurani/screens/main/home/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('auth');
    setState(() {
      _translations = trans;
    });
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_agreeToTerms) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   AppComponentStyles.errorSnackBar(
      //     message: '',
      //     duration: const Duration(seconds: 2),
      //   ),
      // );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      if (authProvider.errorMessage?.contains('email') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppComponentStyles.successSnackBar(
            message: 'Registrasi berhasil! Silakan cek email untuk verifikasi',
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          AppComponentStyles.successSnackBar(
            message: 'Registrasi berhasil! Selamat datang',
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(
          message: authProvider.errorMessage ?? 'Registrasi gagal',
        ),
      );
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
                _buildLogoSection(s),
                AppMargin.customGap(context, AppDesignSystem.space32),
                _buildWelcomeSection(),
                AppMargin.customGap(context, AppDesignSystem.space32),
                _buildForm(s),
                AppMargin.gapLarge(context),
                _buildRegisterButton(),
                AppMargin.gap(context),
                _buildLoginLink(context),
                AppMargin.customGap(context, AppDesignSystem.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'register.register_text')
              : 'Register',
          style: AppTypography.displaySmall(
            context,
            color: AppColors.getTextPrimary(context),
            weight: AppTypography.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(double s) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'register.username_text')
                : 'Username',
            icon: Icons.person_outline_rounded,
            validator: (value) {
              if (value == null || value.isEmpty)
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(
                        _translations,
                        'register.null_username_text',
                      )
                    : 'Username tidak boleh kosong';
              if (value.length < 3)
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(
                        _translations,
                        'register.error_username_length_text',
                      )
                    : 'Username minimal 3 karakter';
              return null;
            },
            s: s,
          ),
          AppMargin.gap(context),
          _buildTextField(
            controller: _emailController,
            label: _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'register.email_text')
                : 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty)
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'login.null_email_text')
                    : 'Email tidak boleh kosong';
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return _translations.isNotEmpty
                    ? LanguageHelper.tr(
                        _translations,
                        'login.error_email_format_text',
                      )
                    : 'Format email tidak valid';
              }
              return null;
            },
            s: s,
          ),
          AppMargin.gap(context),
          _buildPasswordField(
            _passwordController,
            _translations.isNotEmpty
                ? LanguageHelper.tr(_translations, 'register.password_text')
                : 'Password',
            _isPasswordVisible,
            (val) {
              setState(() => _isPasswordVisible = val);
            },
            s,
          ),
          AppMargin.gap(context),
          _buildPasswordField(
            _confirmPasswordController,
            _translations.isNotEmpty
                ? LanguageHelper.tr(
                    _translations,
                    'register.confirm_password_text',
                  )
                : 'Confirm Password',
            _isConfirmPasswordVisible,
            (val) {
              setState(() => _isConfirmPasswordVisible = val);
            },
            s,
            confirmPassword: true,
          ),
          AppMargin.gap(context),
          _buildTermsCheckbox(s),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required double s,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: label == 'Username'
          ? TextCapitalization.words
          : TextCapitalization.none,
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

  Widget _buildPasswordField(
    TextEditingController controller,
    String label,
    bool isVisible,
    Function(bool) onToggle,
    double s, {
    bool confirmPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
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
            Icons.lock_outline_rounded,
            color: AppColors.getTextTertiary(context),
            size: AppDesignSystem.iconLarge * s,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppColors.getTextTertiary(context),
            size: AppDesignSystem.iconLarge * s,
          ),
          onPressed: () => onToggle(!isVisible),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '$label tidak boleh kosong';
        if (value.length < 6)
          return _translations.isNotEmpty
              ? LanguageHelper.tr(
                  _translations,
                  'login.error_password_length_text',
                )
              : 'Password must be at least 6 characters';
        if (confirmPassword && value != _passwordController.text)
          return _translations.isNotEmpty
              ? LanguageHelper.tr(
                  _translations,
                  'login.error_password_match_text',
                )
              : 'Passwords do not match';
        return null;
      },
    );
  }

  Widget _buildTermsCheckbox(double s) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: EdgeInsets.only(top: 2 * s),
        child: SizedBox(
          height: 18 * s,
          width: 18 * s,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
            fillColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.getPrimary(context);
                }
                return null;
              },
            ),
            checkColor: AppColors.getTextInverse(context),
            side: WidgetStateBorderSide.resolveWith(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return BorderSide(
                    color: AppColors.getPrimary(context),
                    width: 2.0,
                  );
                }
                return BorderSide(
                  color: AppColors.getBorderMedium(context),
                  width: 1.5,
                );
              },
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3 * s),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
      SizedBox(width: AppDesignSystem.space10 * s),
      Expanded(
        child: Text.rich(
          TextSpan(
            style: AppTypography.body(
              context,
              color: AppColors.getTextSecondary(context),
            ),
            children: [
              TextSpan(
                text: (_translations.isNotEmpty
                        ? LanguageHelper.tr(_translations, 'register.agreement_text')
                        : 'I agree to the ')
                    .trimRight(),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: (_translations.isNotEmpty
                        ? LanguageHelper.tr(_translations, 'register.terms_and_conditions_text')
                        : 'Terms and Conditions')
                    .trimRight(),
                style: TextStyle(
                  color: AppColors.getPrimary(context),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.getPrimary(context),
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: (_translations.isNotEmpty
                        ? LanguageHelper.tr(_translations, 'register.and_text')
                        : 'and')
                    .trim(),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: _translations.isNotEmpty
                    ? LanguageHelper.tr(_translations, 'register.privacy_policy_text')
                    : 'Privacy Policy',
                style: TextStyle(
                  color: AppColors.getPrimary(context),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.getPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  Widget _buildRegisterButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return AppButton(
          text: _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'register.register_text')
              : 'Signup',
          onPressed: auth.isLoading ? null : _handleRegister,
          loading: auth.isLoading,
          fullWidth: true,
        );
      },
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _translations.isNotEmpty
              ? LanguageHelper.tr(
                  _translations,
                  'register.not_null_account_text',
                )
              : 'Already have an account?',
          style: AppTypography.body(context, color: AppColors.getTextSecondary(context)),
        ),
        AppTextButton(
          text: _translations.isNotEmpty
              ? LanguageHelper.tr(_translations, 'login.login_text')
              : 'Login',
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.getPrimary(context),
        ),
      ],
    );
  }
}
