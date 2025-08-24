// test/utils/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_pass_qr/utils/validators.dart';

void main() {
  group('Validators', () {
    test('validatePhone returns null for valid TR number', () {
      final res = Validators.validatePhone('+90 555 123 4567');
      expect(res, isNull);
    });

    test('validatePhone returns error for short number', () {
      final res = Validators.validatePhone('12345');
      expect(res, isNotNull);
    });

    test('validateOtp accepts 6 digits', () {
      expect(Validators.validateOtp('123456'), isNull);
    });

    test('validateOtp rejects non-digits', () {
      expect(Validators.validateOtp('12ab56'), isNotNull);
    });

    test('cleanPhoneForApi adds +90 when missing', () {
      expect(Validators.cleanPhoneForApi('05551234567'), '+905551234567');
    });
  });
}
