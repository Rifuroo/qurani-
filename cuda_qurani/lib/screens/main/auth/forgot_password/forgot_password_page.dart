import 'dart:async';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/design_system/app_design_system.dart';
import '../../../../core/widgets/app_components.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _translations = {};

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _isOtpSent = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _hasOtpError = false;

  /// True when all 6 OTP digits are filled
  bool get _isOtpComplete => _otpController.text.length == 6;

  // Countdown timer for resend
  Timer? _resendTimer;
  int _resendCountdown = 0;
  static const int _resendDuration = 60;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('auth');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _tr(String key) {
    if (_translations.isEmpty) return '';
    return LanguageHelper.tr(_translations, key);
  }

  String _getOtpCode() {
    return _otpController.text;
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = _resendDuration;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  // ==================== HANDLERS ====================

  Future<void> _handleSendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.requestForgotPassword(
      _emailController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      _startResendTimer();
      _animController.reset();
      setState(() {
        _isOtpSent = true;
      });
      _animController.forward();
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.successSnackBar(
          message: _tr('forgot_password.otp_sent_message').isNotEmpty
              ? _tr('forgot_password.otp_sent_message')
              : 'OTP has been sent to your email',
          context: context,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(
          message: authProvider.errorMessage ?? 'Request failed',
          context: context,
        ),
      );
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.requestForgotPassword(
      _emailController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      _startResendTimer();
      // Clear old OTP
      _otpController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.successSnackBar(
          message: _tr('forgot_password.otp_sent_message').isNotEmpty
              ? _tr('forgot_password.otp_sent_message')
              : 'OTP has been sent to your email',
          context: context,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(
          message: authProvider.errorMessage ?? 'Resend failed',
          context: context,
        ),
      );
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    final otpCode = _getOtpCode();
    if (otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(
          message: _tr('forgot_password.null_otp_text').isNotEmpty
              ? _tr('forgot_password.null_otp_text')
              : 'Please enter the complete 6-digit OTP',
          context: context,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resetPasswordWithOtp(
      email: _emailController.text.trim(),
      otpCode: otpCode,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _hasOtpError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.successSnackBar(
          message: _tr('forgot_password.success_message').isNotEmpty
              ? _tr('forgot_password.success_message')
              : 'Password reset successfully!',
          context: context,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final errorMessage = authProvider.errorMessage ?? 'Reset failed';
      // If error is about OTP, highlight the OTP boxes
      if (errorMessage.toLowerCase().contains('otp') ||
          errorMessage.toLowerCase().contains('code')) {
        setState(() {
          _hasOtpError = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(
          message: errorMessage,
          context: context,
        ),
      );
    }
  }

  void _handleBackToEmail() {
    _animController.reset();
    setState(() {
      _isOtpSent = false;
      _otpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
    _animController.forward();
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final s = AppDesignSystem.getScaleFactor(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            _buildAppBar(context, s),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: AppPadding.horizontal(
                    context,
                    AppDesignSystem.space24,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _isOtpSent
                        ? _buildResetScreen(context, s)
                        : _buildEmailScreen(context, s),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CUSTOM APPBAR ====================

  Widget _buildAppBar(BuildContext context, double s) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesignSystem.space8 * s,
        vertical: AppDesignSystem.space8 * s,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_isOtpSent) {
                _handleBackToEmail();
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.getTextPrimary(context),
              size: AppDesignSystem.iconMedium * s,
            ),
          ),
          Expanded(child: Center(child: _buildStepIndicator(s))),
          // Invisible placeholder to center the step indicator
          SizedBox(width: 48 * s),
        ],
      ),
    );
  }

  // ==================== STEP INDICATOR ====================

  Widget _buildStepIndicator(double s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step 1: Email
        _buildStepDot(isActive: true, s: s),
        _buildStepLine(isActive: _isOtpSent, s: s),
        // Step 2: OTP
        _buildStepDot(isActive: _isOtpSent, s: s),
        _buildStepLine(isActive: _isOtpSent && _isOtpComplete, s: s),
        // Step 3: New Password
        _buildStepDot(isActive: _isOtpSent && _isOtpComplete, s: s),
      ],
    );
  }

  Widget _buildStepLine({required bool isActive, required double s}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 20 * s,
        height: 3 * s,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.getPrimary(context)
              : AppColors.getBorderLight(context),
          borderRadius: BorderRadius.circular(2 * s),
        ),
      ),
    );
  }

  Widget _buildStepDot({required bool isActive, required double s}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 10 * s,
      height: 10 * s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.getPrimary(context) : Colors.transparent,
        border: Border.all(
          color: isActive
              ? AppColors.getPrimary(context)
              : AppColors.getBorderMedium(context),
          width: 2 * s,
        ),
      ),
    );
  }

  // ==================== SCREEN 1: EMAIL ====================

  Widget _buildEmailScreen(BuildContext context, double s) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppMargin.customGap(context, AppDesignSystem.space32),

          // Illustration
          _buildIllustration(icon: Icons.lock_outline_rounded, s: s),

          AppMargin.customGap(context, AppDesignSystem.space32),

          // Title
          Text(
            _tr('forgot_password.title').isNotEmpty
                ? _tr('forgot_password.title')
                : 'Forgot Password',
            textAlign: TextAlign.center,
            style: AppTypography.h2(
              context,
              color: AppColors.getTextPrimary(context),
              weight: AppTypography.bold,
            ),
          ),

          SizedBox(height: 8 * s),

          // Subtitle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * s),
            child: Text(
              _tr('forgot_password.email_hint').isNotEmpty
                  ? _tr('forgot_password.email_hint')
                  : 'Enter your registered email address and we\'ll send you a verification code.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                context,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ),

          AppMargin.customGap(context, AppDesignSystem.space32),

          // Email input
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSendOtp(),
            style: AppTypography.body(
              context,
              color: AppColors.getTextPrimary(context),
              weight: AppTypography.medium,
            ),
            decoration: AppComponentStyles.inputDecoration(
              context: context,
              labelText: _tr('forgot_password.email_label').isNotEmpty
                  ? _tr('forgot_password.email_label')
                  : 'Email Address',
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
                return _tr('forgot_password.null_email_text').isNotEmpty
                    ? _tr('forgot_password.null_email_text')
                    : 'Email cannot be empty';
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(value)) {
                return _tr('forgot_password.error_email_format_text').isNotEmpty
                    ? _tr('forgot_password.error_email_format_text')
                    : 'Invalid email format';
              }
              return null;
            },
          ),

          AppMargin.customGap(context, AppDesignSystem.space32),

          // Send OTP button
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return AppButton(
                text: _tr('forgot_password.send_otp_button').isNotEmpty
                    ? _tr('forgot_password.send_otp_button')
                    : 'Send OTP',
                onPressed: authProvider.isLoadingForgot ? null : _handleSendOtp,
                loading: authProvider.isLoadingForgot,
                fullWidth: true,
              );
            },
          ),

          AppMargin.customGap(context, AppDesignSystem.space24),

          // Back to login link
          Center(
            child: AppTextButton(
              text: _tr('forgot_password.back_to_login').isNotEmpty
                  ? _tr('forgot_password.back_to_login')
                  : 'Back to Login',
              onPressed: () => Navigator.of(context).pop(),
              color: AppColors.getTextSecondary(context),
            ),
          ),

          AppMargin.customGap(context, AppDesignSystem.space32),
        ],
      ),
    );
  }

  // ==================== SCREEN 2: OTP + RESET ====================

  Widget _buildResetScreen(BuildContext context, double s) {
    final otpComplete = _isOtpComplete;

    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppMargin.customGap(context, AppDesignSystem.space24),

          // Illustration - switches icon when OTP complete
          _buildIllustration(
            icon: otpComplete
                ? Icons.lock_reset_rounded
                : Icons.verified_user_outlined,
            s: s,
          ),

          AppMargin.customGap(context, AppDesignSystem.space24),

          // Title - changes based on progress
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              otpComplete
                  ? (_tr('forgot_password.new_password_label').isNotEmpty
                        ? _tr('forgot_password.new_password_label')
                        : 'New Password')
                  : (_tr('forgot_password.otp_label').isNotEmpty
                        ? _tr('forgot_password.otp_label')
                        : 'Verify OTP'),
              key: ValueKey(otpComplete ? 'title_pw' : 'title_otp'),
              textAlign: TextAlign.center,
              style: AppTypography.h2(
                context,
                color: AppColors.getTextPrimary(context),
                weight: AppTypography.bold,
              ),
            ),
          ),

          SizedBox(height: 8 * s),

          // Instruction (Only show for OTP step)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: otpComplete
                  ? const SizedBox.shrink(key: ValueKey('sub_pw'))
                  : Text(
                      _tr('forgot_password.otp_instruction').isNotEmpty
                          ? _tr('forgot_password.otp_instruction')
                          : 'Enter the 6-digit code sent to your email',
                      key: const ValueKey('sub_otp'),
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        context,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
            ),
          ),

          SizedBox(height: 4 * s),

          // Email badge
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 4 * s),
              padding: EdgeInsets.symmetric(
                horizontal: 12 * s,
                vertical: 4 * s,
              ),
              decoration: BoxDecoration(
                color: AppColors.getPrimary(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusXLarge * s,
                ),
              ),
              child: Text(
                _emailController.text.trim(),
                style: AppTypography.label(
                  context,
                  color: AppColors.getPrimary(context),
                  weight: AppTypography.semiBold,
                ),
              ),
            ),
          ),

          AppMargin.customGap(context, AppDesignSystem.space24),

          // OTP fields - always visible
          _buildOtpFields(context, s),

          SizedBox(height: 16 * s),

          // Resend row
          _buildResendRow(s),

          // ===== PASSWORD SECTION — Progressive Disclosure =====
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: otpComplete ? 1.0 : 0.0,
              child: otpComplete
                  ? _buildPasswordSection(s)
                  : const SizedBox.shrink(),
            ),
          ),

          AppMargin.customGap(context, AppDesignSystem.space32),
        ],
      ),
    );
  }

  // ==================== PASSWORD SECTION (revealed on OTP complete) ====================

  Widget _buildPasswordSection(double s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMargin.customGap(context, AppDesignSystem.space24),

        // Divider with checkmark
        Row(
          children: [
            Expanded(
              child: AppDivider(
                color: AppColors.getPrimary(context).withValues(alpha: 0.3),
                thickness: 1 * s,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * s),
              child: Container(
                padding: EdgeInsets.all(4 * s),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 14 * s,
                  color: AppColors.getPrimary(context),
                ),
              ),
            ),
            Expanded(
              child: AppDivider(
                color: AppColors.getPrimary(context).withValues(alpha: 0.3),
                thickness: 1 * s,
              ),
            ),
          ],
        ),

        AppMargin.customGap(context, AppDesignSystem.space20),

        // New Password
        _buildPasswordField(
          controller: _newPasswordController,
          label: _tr('forgot_password.new_password_label').isNotEmpty
              ? _tr('forgot_password.new_password_label')
              : 'New Password',
          isVisible: _isNewPasswordVisible,
          onToggle: (val) => setState(() => _isNewPasswordVisible = val),
          s: s,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _tr('forgot_password.null_password_text').isNotEmpty
                  ? _tr('forgot_password.null_password_text')
                  : 'Password cannot be empty';
            }
            if (value.length < 6) {
              return _tr(
                    'forgot_password.error_password_length_text',
                  ).isNotEmpty
                  ? _tr('forgot_password.error_password_length_text')
                  : 'Password must be at least 6 characters';
            }
            return null;
          },
        ),

        AppMargin.gap(context),

        // Confirm Password
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: _tr('forgot_password.confirm_password_label').isNotEmpty
              ? _tr('forgot_password.confirm_password_label')
              : 'Confirm Password',
          isVisible: _isConfirmPasswordVisible,
          onToggle: (val) => setState(() => _isConfirmPasswordVisible = val),
          s: s,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _tr('forgot_password.null_password_text').isNotEmpty
                  ? _tr('forgot_password.null_password_text')
                  : 'Password cannot be empty';
            }
            if (value != _newPasswordController.text) {
              return _tr('forgot_password.error_password_match_text').isNotEmpty
                  ? _tr('forgot_password.error_password_match_text')
                  : 'Passwords do not match';
            }
            return null;
          },
        ),

        AppMargin.customGap(context, AppDesignSystem.space24),

        // Reset button
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return AppButton(
              text: _tr('forgot_password.reset_button').isNotEmpty
                  ? _tr('forgot_password.reset_button')
                  : 'Reset Password',
              onPressed: authProvider.isLoadingReset
                  ? null
                  : _handleResetPassword,
              loading: authProvider.isLoadingReset,
              fullWidth: true,
            );
          },
        ),
      ],
    );
  }

  // ==================== ILLUSTRATION ICON ====================

  Widget _buildIllustration({required IconData icon, required double s}) {
    return Center(
      child: Container(
        width: 100 * s,
        height: 100 * s,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.getPrimary(context).withValues(alpha: 0.15),
              AppColors.getPrimary(context).withValues(alpha: 0.05),
            ],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 64 * s,
            height: 64 * s,
            decoration: BoxDecoration(
              color: AppColors.getPrimary(context).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32 * s,
              color: AppColors.getPrimary(context),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== OTP INPUT CELLS ====================

  Widget _buildOtpFields(BuildContext context, double s) {
    final otpText = _otpController.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_otpFocusNode.hasFocus) {
          FocusScope.of(context).requestFocus(_otpFocusNode);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden TextField that captures ALL input
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 54 * s,
              child: TextField(
                controller: _otpController,
                focusNode: _otpFocusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: false,
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  if (_hasOtpError) {
                    setState(() {
                      _hasOtpError = false;
                    });
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
          ),

          // Visual OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final bool hasFocus =
                  _otpFocusNode.hasFocus && index == otpText.length;
              final bool isFilled = index < otpText.length;
              final bool addGap = index == 3;

              return Row(
                children: [
                  if (addGap) SizedBox(width: 12 * s),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44 * s,
                    height: 54 * s,
                    margin: EdgeInsets.symmetric(horizontal: 3 * s),
                    decoration: BoxDecoration(
                      color: isFilled
                          ? AppColors.getPrimary(
                              context,
                            ).withValues(alpha: 0.06)
                          : AppColors.getSurfaceContainerLowest(context),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusMedium * s,
                      ),
                      border: Border.all(
                        color: _hasOtpError
                            ? AppColors.getError(context)
                            : hasFocus
                            ? AppColors.getPrimary(context)
                            : isFilled
                            ? AppColors.getPrimary(
                                context,
                              ).withValues(alpha: 0.3)
                            : AppColors.getBorderLight(context),
                        width: hasFocus ? 2 * s : 1.5 * s,
                      ),
                    ),
                    child: Center(
                      child: isFilled
                          ? Text(
                              otpText[index],
                              style: AppTypography.h3(
                                context,
                                color: _hasOtpError
                                    ? AppColors.getError(context)
                                    : AppColors.getTextPrimary(context),
                                weight: AppTypography.bold,
                              ),
                            )
                          : hasFocus
                          ? _buildCursor(s)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Blinking cursor indicator for active OTP cell
  Widget _buildCursor(double s) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value < 0.5 ? 1.0 : 0.0,
          child: Container(
            width: 2 * s,
            height: 24 * s,
            decoration: BoxDecoration(
              color: AppColors.getPrimary(context),
              borderRadius: BorderRadius.circular(1 * s),
            ),
          ),
        );
      },
    );
  }

  // ==================== RESEND ROW ====================

  Widget _buildResendRow(double s) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _tr('forgot_password.resend_otp_prompt').isNotEmpty
                  ? '${_tr('forgot_password.resend_otp_prompt')} '
                  : 'Didn\'t receive code? ',
              style: AppTypography.body(
                context,
                color: AppColors.getTextTertiary(context),
              ),
            ),
            if (_resendCountdown > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * s,
                  vertical: 4 * s,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12 * s),
                ),
                child: Text(
                  '${_resendCountdown}s',
                  style: AppTypography.label(
                    context,
                    color: AppColors.getPrimary(context),
                    weight: AppTypography.bold,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: authProvider.isLoadingForgot ? null : _handleResendOtp,
                child: Text(
                  _tr('forgot_password.resend_otp').isNotEmpty
                      ? _tr('forgot_password.resend_otp')
                      : 'Resend',
                  style: AppTypography.body(
                    context,
                    color: AppColors.getPrimary(context),
                    weight: AppTypography.semiBold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ==================== PASSWORD FIELD ====================

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required Function(bool) onToggle,
    required double s,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      textInputAction: TextInputAction.done,
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
      validator: validator,
    );
  }
}
