import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gym_pass_qr/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:gym_pass_qr/providers/auth_provider.dart';
import 'package:gym_pass_qr/providers/user_provider.dart';
// import 'package:gym_pass_qr/screens/home/home_screen.dart';

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
          home: HomeScreen(),
        ),
      ),
    );

    // pumpAndSettle yerine sabit süre beklet
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('home_membership_card')), findsOneWidget);
  });
}
