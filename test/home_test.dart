import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gym_pass_qr/providers/auth_provider.dart';
import 'package:gym_pass_qr/providers/user_provider.dart';
import 'package:gym_pass_qr/screens/home/home_screen.dart'; // doğru import path’i yaz

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home widgetında home_membership_card görünüyor',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MaterialApp(
          home: HomeScreen(), // direkt Home’u yükle
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_membership_card')), findsOneWidget);
  });
}
