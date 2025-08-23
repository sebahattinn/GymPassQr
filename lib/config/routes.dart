import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/phone_input_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/home/home_screen.dart';

/// App routing configuration
/// WHY: Centralized navigation with auth guards
/// Uses go_router for declarative routing

class AppRouter {
  static const String splash = '/';
  static const String phoneInput = '/phone';
  static const String otpVerification = '/otp';
  static const String home = '/home';

  static GoRouter router(BuildContext context) {
    return GoRouter(
      initialLocation: splash,
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final authProvider = context.read<AuthProvider>();
        final isAuthenticated = authProvider.isAuthenticated;
        final currentLocation = state.uri.path;

        // Auth guard logic
        if (currentLocation == splash) {
          // Always allow splash screen
          return null;
        }

        // If authenticated and trying to access auth screens, redirect to home
        if (isAuthenticated &&
            (currentLocation == phoneInput ||
                currentLocation == otpVerification)) {
          return home;
        }

        // If not authenticated and trying to access home, redirect to phone input
        if (!isAuthenticated && currentLocation == home) {
          return phoneInput;
        }

        return null; // Allow navigation
      },
      routes: [
        GoRoute(
          path: splash,
          name: 'splash',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SplashScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: phoneInput,
          name: 'phone',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const PhoneInputScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeInOut)),
                ),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: otpVerification,
          name: 'otp',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: OtpVerificationScreen(
              phoneNumber: state.extra as String? ?? '',
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeInOut)),
                ),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: home,
          name: 'home',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        ),
      ],
      errorPageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.go(splash),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
