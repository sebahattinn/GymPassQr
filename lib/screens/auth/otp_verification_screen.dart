import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_pass_qr/config/constans.dart';
import 'package:gym_pass_qr/config/routes.dart';
import 'package:gym_pass_qr/config/theme.dart';
import 'package:gym_pass_qr/providers/auth_provider.dart';
import 'package:gym_pass_qr/providers/user_provider.dart';
import 'package:gym_pass_qr/utils/validators.dart';
import 'package:gym_pass_qr/widgets/common/custom_button.dart';
import 'package:gym_pass_qr/widgets/common/loading_overlay.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _otpController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  StreamController<ErrorAnimationType>? _errorController;

  String _currentOtp = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
    _errorController = StreamController<ErrorAnimationType>();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _animationController.dispose();
    _errorController?.close();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_currentOtp.length != AppConstants.otpLength) {
      _showError('Lütfen gelen kodu giriniz');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    final success = await authProvider.verifyOtp(_currentOtp);
    if (!mounted) return;

    if (success) {
      userProvider.setUser(authProvider.user!);
      context.go(AppRouter.home);
    } else {
      _showError(authProvider.errorMessage ?? 'Geçersiz kod');
      _errorController!.add(ErrorAnimationType.shake);
      setState(() {
        _currentOtp = '';
        _hasError = true;
      });
      _otpController.clear();
    }
  }

  Future<void> _resendOtp() async {
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.resendOtp();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Yeni kod başarıyla gönderildi!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      setState(() {
        _currentOtp = '';
        _hasError = false;
      });
      _otpController.clear();
    } catch (_) {
      _showError(authProvider.errorMessage ?? 'Kod yeniden gönderilemedi');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final formattedPhone = Validators.formatPhoneForDisplay(widget.phoneNumber);

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),

                          // Icon
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                // ignore: deprecated_member_use
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline,
                                size: 40,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Title
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Doğrulama Kodu',
                              style: AppTheme.heading2,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Info
                          Text.rich(
                            TextSpan(
                              style: AppTheme.bodyMedium
                                  .copyWith(color: AppTheme.textSecondary),
                              children: [
                                const TextSpan(
                                  text: 'Size gönderilen 6 haneli kodu girin\n',
                                ),
                                TextSpan(
                                  text: formattedPhone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          // OTP Input (dinamik kutu genişliği)
                          Form(
                            key: _formKey,
                            child: LayoutBuilder(
                              builder: (context, c) {
                                const gap = 10.0;
                                const slots = AppConstants.otpLength;
                                const totalGap = gap * (slots - 1);
                                final avail = c.maxWidth - totalGap - 8;
                                final fw = (avail / slots)
                                    .clamp(42.0, 60.0); // güvenli aralık
                                final fh = (fw * 1.2).clamp(48.0, 64.0);

                                return PinCodeTextField(
                                  key: const ValueKey('otp_field'),
                                  appContext: context,
                                  length: slots,
                                  controller: _otpController,
                                  errorAnimationController: _errorController,
                                  animationType: AnimationType.fade,
                                  validator: Validators.validateOtp,
                                  autoDisposeControllers: false,
                                  pinTheme: PinTheme(
                                    shape: PinCodeFieldShape.box,
                                    borderRadius: BorderRadius.circular(12),
                                    fieldHeight: fh,
                                    fieldWidth: fw,
                                    activeFillColor: Colors.white,
                                    inactiveFillColor: AppTheme.surfaceColor,
                                    selectedFillColor:
                                        // ignore: deprecated_member_use
                                        AppTheme.primaryColor.withOpacity(0.1),
                                    activeColor: AppTheme.primaryColor,
                                    inactiveColor: AppTheme.dividerColor,
                                    selectedColor: AppTheme.primaryColor,
                                    errorBorderColor: AppTheme.errorColor,
                                  ),
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  cursorColor: AppTheme.primaryColor,
                                  animationDuration:
                                      const Duration(milliseconds: 300),
                                  enableActiveFill: true,
                                  keyboardType: TextInputType.number,
                                  textStyle: AppTheme.bodyLarge,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onCompleted: (_) => _verifyOtp(),
                                  onChanged: (value) {
                                    setState(() {
                                      _currentOtp = value;
                                      _hasError = false;
                                    });
                                  },
                                  beforeTextPaste: (text) {
                                    return text != null &&
                                        text.length == AppConstants.otpLength &&
                                        RegExp(r'^\d+$').hasMatch(text);
                                  },
                                );
                              },
                            ),
                          ),

                          if (_hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Geçersiz kod. Lütfen tekrar deneyin.',
                                style: AppTheme.bodySmall
                                    .copyWith(color: AppTheme.errorColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 20),

                          // Verify Button
                          CustomButton(
                            key: const ValueKey('verify_code_btn'),
                            text: 'Doğrulama Kodu',
                            onPressed:
                                _currentOtp.length == AppConstants.otpLength
                                    ? _verifyOtp
                                    : null,
                            isLoading: authProvider.isLoading,
                          ),
                          const SizedBox(height: 16),

                          // Resend Code Section
                          Center(
                            child: authProvider.isResendEnabled
                                ? TextButton(
                                    onPressed: _resendOtp,
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        const Icon(Icons.refresh, size: 20),
                                        Text(
                                          'Kodu Yeniden Gönder',
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      Text(
                                        'Kodu yeniden gönder',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              // ignore: deprecated_member_use
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${authProvider.resendCountdown}s',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 24),

                          // Help Text
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
                              color: AppTheme.infoColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                // ignore: deprecated_member_use
                                color: AppTheme.infoColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppTheme.infoColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Kodu almadınız mı? SMS gelen kutunuzu kontrol edin veya tekrar göndermeyi deneyin.',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
