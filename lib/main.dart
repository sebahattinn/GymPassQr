import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_pass_qr/app.dart';
import 'package:gym_pass_qr/config/theme.dart';
import 'package:gym_pass_qr/providers/auth_provider.dart';
import 'package:gym_pass_qr/providers/user_provider.dart';
import 'package:gym_pass_qr/services/api_service.dart';
import 'package:gym_pass_qr/services/storage_service.dart';
import 'package:gym_pass_qr/utils/logger.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Not: Testlerde bu builder override edileceği için sorun yok.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text('Something went wrong!', style: AppTheme.heading3),
            SizedBox(height: 8),
            Text('Please restart the app', style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );
  };

  await _initializeServices();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const GymPassApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  try {
    AppLogger.info('Initializing services...');
    await StorageService().init();
    ApiService().init(); // ✅ _init değil, init
    AppLogger.info('All services initialized successfully');
  } catch (e) {
    AppLogger.error('Failed to initialize services', e);
  }
}
