import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_pass_qr/config/constans.dart';
import 'package:gym_pass_qr/config/routes.dart';
import 'package:gym_pass_qr/config/theme.dart';
import 'package:gym_pass_qr/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    ));

    // Start animations
    _animationController.forward();

    // Check auth status after delay
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(AppConstants.splashDuration);

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // Debug logs
    debugPrint('AUTH STATE: ${authProvider.state}');
    debugPrint('IS AUTHENTICATED: ${authProvider.isAuthenticated}');
    debugPrint('USER: ${authProvider.user?.fullName}');

    // Force navigation after checking
    if (authProvider.isAuthenticated && authProvider.user != null) {
      context.go(AppRouter.home);
    } else {
      context.go(AppRouter.phoneInput);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    final authProvider = context.watch<AuthProvider>();

    // Auto-navigate if state changes after initial load
    if (!_isInitialized && authProvider.state != AuthState.initial) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (authProvider.state == AuthState.authenticated) {
          context.go(AppRouter.home);
        } else if (authProvider.state == AuthState.unauthenticated) {
          context.go(AppRouter.phoneInput);
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            size: 60,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // App Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    AppConstants.appName,
                    style: AppTheme.heading1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Spor Salonu Erişimi',
                    style: AppTheme.bodyLarge.copyWith(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // Loading indicator
                const SpinKitDoubleBounce(
                  color: Colors.white,
                  size: 40,
                ),

                const SizedBox(height: 20),

                // Loading text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Yükleniyor...',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
