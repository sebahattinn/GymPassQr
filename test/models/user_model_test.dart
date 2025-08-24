// test/models/user_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_pass_qr/models/user_model.dart';

void main() {
  test('daysRemaining & membershipStatus behave as expected', () {
    final now = DateTime.now();
    final user = User(
      id: 'u1',
      firstName: 'Test',
      lastName: 'User',
      phoneNumber: '+905551234567',
      membershipStart: now.subtract(const Duration(days: 10)),
      membershipEnd: now.add(const Duration(days: 5)),
      membershipType: 'Premium',
      isActive: true,
    );

    expect(user.daysRemaining, inInclusiveRange(4, 5));
    expect(user.isMembershipValid, isTrue);
    expect(user.membershipStatus,
        anyOf('Active', 'Expiring Soon')); // 5 gün => Expiring Soon
  });

  test('expired membership', () {
    final now = DateTime.now();
    final user = User(
      id: 'u2',
      firstName: 'Expired',
      lastName: 'User',
      phoneNumber: '+905559999999',
      membershipStart: now.subtract(const Duration(days: 30)),
      membershipEnd: now.subtract(const Duration(days: 1)),
      membershipType: 'Basic',
      isActive: true,
    );

    expect(user.isMembershipValid, isFalse);
    expect(user.membershipStatus, 'Expired');
  });
}
