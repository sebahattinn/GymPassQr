import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'utils/logger.dart';

class GymPassApp extends StatefulWidget {
  const GymPassApp({super.key});

  @override
  State<GymPassApp> createState() => _GymPassAppState();
}

class _GymPassAppState extends State<GymPassApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _router = AppRouter.router(context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();

      if (authProvider.isAuthenticated) {
        AppLogger.info('App started - User already logged in, going to home');
      } else {
        AppLogger.info('App started - No valid session, going to login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GymPass QR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      // builder paramını tamamen kaldırdık
    );
  }
}
