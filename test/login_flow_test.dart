import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_pass_qr/app.dart';
import 'package:gym_pass_qr/providers/auth_provider.dart';
import 'package:gym_pass_qr/providers/user_provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 120),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  // son bir kez
  await tester.pump();
  expect(finder.evaluate().isNotEmpty, true,
      reason: 'Beklenen widget belirtilen süre içinde görünmedi: $finder');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: child,
      );

  testWidgets('Login flow: phone -> otp -> home', (tester) async {
    // Küçük ekran sorunlarını önlemek için viewport genişlet
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrap(const GymPassApp()));
    await tester.pump(const Duration(milliseconds: 400));

    // 1) Phone screen geldi: IntlPhoneField'ı bekle
    final phoneField = find.byType(IntlPhoneField);
    await pumpUntilFound(tester, phoneField);

    final innerTF =
        find.descendant(of: phoneField, matching: find.byType(TextFormField));
    await tester.enterText(innerTF, '5551234567');
    await tester.pump(const Duration(milliseconds: 150));

    // Gönder butonunu KEY ile bul
    Finder sendBtn = find.byKey(const ValueKey('send_code_btn'));
    if (sendBtn.evaluate().isEmpty) {
      // Yedek - metinle bulup atasını tıkla (eğer key eklemeyi atladıysan)
      final sendLabelTr = find.text('Doğrulama Kodunu Gönder');
      final sendLabelEn = find.text('Send Verification Code');
      final label =
          sendLabelTr.evaluate().isNotEmpty ? sendLabelTr : sendLabelEn;
      sendBtn = label.evaluate().isNotEmpty
          ? find.ancestor(of: label, matching: find.byType(ElevatedButton))
          : sendBtn;
    }

    if (sendBtn.evaluate().isEmpty) {
      // görünürlük için yukarı kaydır
      final scrollable = find.byType(Scrollable).first;
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
      }
    }

    await tester.ensureVisible(sendBtn);
    await tester.tap(sendBtn);
    await tester.pump(const Duration(milliseconds: 500));

    // 2) OTP ekranı: PinCodeTextField KEY ile bekle
    final otpField = find.byKey(const ValueKey('otp_field'));
    // Eğer key eklenmediyse, tipten yakalamayı dene
    final otpFallback = find.byType(PinCodeTextField);
    await pumpUntilFound(
      tester,
      otpField.evaluate().isNotEmpty ? otpField : otpFallback,
    );

    await tester.enterText(
      otpField.evaluate().isNotEmpty ? otpField : otpFallback,
      '123456',
    );
    await tester.pump(const Duration(milliseconds: 250));

    // Opsiyonel doğrulama butonu
    final verifyBtn = find.byKey(const ValueKey('verify_code_btn'));
    if (verifyBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(verifyBtn);
      await tester.tap(verifyBtn);
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 3) Home ekranı: KEY ile bekle (metin bağımlılığı yok!)
    final homeQrCard = find.byKey(const ValueKey('home_qr_card'));
    final homeMembership = find.byKey(const ValueKey('home_membership_card'));

    // İkisinden biri gelene kadar bekle
    await pumpUntilFound(
      tester,
      homeQrCard.evaluate().isNotEmpty ? homeQrCard : homeMembership,
    );

    // Güvence olsun diye Scaffold varlığını da kontrol edelim
    final homeRoot = find.byKey(const ValueKey('home_scaffold'));
    expect(
        homeRoot.evaluate().isNotEmpty ||
            find.byType(Scaffold).evaluate().isNotEmpty,
        true);
  });
}
