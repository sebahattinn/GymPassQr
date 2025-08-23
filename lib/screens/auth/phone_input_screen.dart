import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_overlay.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  String _completePhoneNumber = '';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();

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
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.sendOtp(_completePhoneNumber);

      if (!mounted) return;
      context.push(
        AppRouter.otpVerification,
        extra: _completePhoneNumber,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Failed to send code',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // içerik geniş ekranda ortalansın, telefonda tam genişlik kullansın
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),

                          // Logo/Icon (scaleDown ile overflow olmaz)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: const Icon(
                                Icons.fitness_center,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Welcome Text
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Hoşgeldiniz',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'GymPassQR',
                              style: AppTheme.heading1.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Instruction Text
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Telefon numaranızı giriniz',
                              style: AppTheme.heading3,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Doğrulama kodu göndereceğiz',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Phone Input Form
                          Form(
                            key: _formKey,
                            child: IntlPhoneField(
                              controller: _phoneController,
                              decoration: AppTheme.inputDecoration(
                                'Telefon Numarası',
                                prefix: const Icon(Icons.phone_outlined),
                              ),
                              initialCountryCode: 'TR',
                              onChanged: (phone) {
                                setState(() {
                                  _completePhoneNumber = phone.completeNumber;
                                  _isValid = phone.isValidNumber();
                                });
                              },
                              validator: (phone) {
                                if (phone == null || phone.number.isEmpty) {
                                  return 'Lütfen telefon numaranızı giriniz';
                                }
                                if (!phone.isValidNumber()) {
                                  return 'Geçersiz telefon numarası';
                                }
                                return null;
                              },
                              style: AppTheme.bodyLarge,
                              dropdownTextStyle: AppTheme.bodyMedium,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Send Code Button
                          CustomButton(
                            key: const ValueKey('send_code_btn'),
                            text: 'Doğrulama Kodunu Gönder',
                            onPressed: _isValid ? _sendOtp : null,
                            isLoading: authProvider.isLoading,
                            icon: Icons.arrow_forward,
                          ),
                          const SizedBox(height: 16),

                          // Test Numbers (Debug Only)
                          if (const bool.fromEnvironment('dart.vm.product') ==
                              false)
                            _DebugNumbers(
                              onPick: (number) {
                                final cleaned =
                                    number.replaceAll(RegExp(r'[^\d]'), '');
                                if (cleaned.startsWith('90') &&
                                    cleaned.length >= 12) {
                                  _phoneController.text = cleaned.substring(2);
                                } else {
                                  _phoneController.text = cleaned;
                                }
                                setState(() {
                                  _completePhoneNumber =
                                      number.replaceAll(' ', '');
                                  _isValid = true;
                                });
                              },
                            ),

                          const SizedBox(height: 20),

                          // Terms and Privacy (Wrap -> taşma olmaz)
                          Text(
                            'Devam ederek onaylamış olursunuz',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 0,
                            children: [
                              TextButton(
                                onPressed: () {},
                                child: const Text('Hizmet Şartları'),
                              ),
                              Text(
                                've',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Gizlilik Politikası'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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

class _DebugNumbers extends StatelessWidget {
  final void Function(String number) onPick;
  const _DebugNumbers({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report,
                  color: AppTheme.warningColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Test Modu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Test Telefon Numaraları:',
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _row('+90 555 123 4567', 'Premium Üye'),
          _row('+90 555 987 6543', 'Süresi Yakında Doluyor'),
          _row('+90 555 555 5555', 'Süresi Dolmuş'),
          const SizedBox(height: 6),
          Text(
            'OTP Code: 123456',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String number, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => onPick(number),
        child: Row(
          children: [
            const Icon(Icons.phone, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
