import 'dart:async';
import 'dart:convert'; // base64Url
import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:gym_pass_qr/config/constans.dart';
import 'package:gym_pass_qr/models/auth_model.dart';
import 'package:gym_pass_qr/models/user_model.dart';

class MockDataService {
  factory MockDataService() => _instance;
  MockDataService._internal();
  static final MockDataService _instance = MockDataService._internal();

  // Simulate network delay
  final _networkDelay = const Duration(milliseconds: 800);

  // Store OTP for verification (in real app, this happens on backend)
  String? _lastOtp;
  String? _lastPhoneNumber;

  // Mock user database
  final Map<String, User> _mockUsers = {
    '+905551234567': User(
      id: 'user_001',
      firstName: 'Ahmet',
      lastName: 'Yılmaz',
      phoneNumber: '+905551234567',
      profilePhotoUrl: 'https://i.pravatar.cc/150?img=1',
      membershipStart: DateTime.now().subtract(const Duration(days: 30)),
      membershipEnd: DateTime.now().add(const Duration(days: 150)),
      membershipType: 'Premium',
      isActive: true,
    ),
    '+905559876543': User(
      id: 'user_002',
      firstName: 'Ayşe',
      lastName: 'Demir',
      phoneNumber: '+905559876543',
      profilePhotoUrl: 'https://i.pravatar.cc/150?img=2',
      membershipStart: DateTime.now().subtract(const Duration(days: 60)),
      membershipEnd: DateTime.now().add(const Duration(days: 5)),
      membershipType: 'Standard',
      isActive: true,
    ),
    '+905555555555': User(
      id: 'user_003',
      firstName: 'Test',
      lastName: 'User',
      phoneNumber: '+905555555555',
      profilePhotoUrl: null,
      membershipStart: DateTime.now().subtract(const Duration(days: 365)),
      membershipEnd: DateTime.now().subtract(const Duration(days: 1)),
      membershipType: 'Basic',
      isActive: false,
    ),
  };

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    await Future.delayed(_networkDelay);

    // Normalize phone number
    String normalizedPhone = _normalizePhone(phoneNumber);

    // Check if user exists
    if (!_mockUsers.containsKey(normalizedPhone)) {
      throw Exception(
          'User not registered. Please contact gym administration.');
    }

    // Generate 6-digit OTP
    _lastOtp = (100000 + Random().nextInt(900000)).toString();
    _lastPhoneNumber = normalizedPhone;

    // In real app, SMS would be sent here
    debugPrint('🔐 MOCK OTP for testing: $_lastOtp');

    return {
      'success': true,
      'message': 'OTP sent successfully',
      'debug_otp': _lastOtp, // Only for testing!
    };
  }

  /// Verify OTP and return auth tokens
  Future<AuthResponse> verifyOtp(String phoneNumber, String otp) async {
    await Future.delayed(_networkDelay);

    String normalizedPhone = _normalizePhone(phoneNumber);

    // Simulate OTP verification
    if (normalizedPhone != _lastPhoneNumber) {
      throw Exception('Phone number mismatch');
    }

    // For testing: accept '123456' as universal OTP
    if (otp != _lastOtp && otp != '123456') {
      throw Exception('Invalid OTP code');
    }

    // Get user
    final user = _mockUsers[normalizedPhone]!;

    // Generate mock tokens
    final accessToken = _generateMockToken('access');
    final refreshToken = _generateMockToken('refresh');

    // Longer expiry for testing
    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: 2592000, // 30 days
      user: user,
    );
  }

  /// Get user profile
  Future<User> getUserProfile(String userId) async {
    await Future.delayed(_networkDelay);

    final user = _mockUsers.values.firstWhere(
      (u) => u.id == userId,
      orElse: () => throw Exception('User not found'),
    );

    return user;
  }

  /// Generate a strong random token (base64url, no padding)
  String _secureToken([int length = 32]) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generate QR code data
  Future<QrCodeData> generateQrCode(String userId) async {
    await Future.delayed(_networkDelay);

    return QrCodeData(
      userId: userId,
      token: _secureToken(32),
      validUntil: DateTime.now().add(
        const Duration(seconds: AppConstants.qrValiditySeconds), // ⬅️ TEK NOKTA
      ),
      metadata: {
        'gym_id': 'gym_001',
        'location': 'Main Branch',
        'generated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Refresh access token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    await Future.delayed(_networkDelay);

    if (refreshToken.isEmpty) {
      throw Exception('Invalid refresh token');
    }

    return {
      'accessToken': _generateMockToken('access'),
      'expiresIn': 2592000, // 30 days
    };
  }

  // Helper methods
  String _normalizePhone(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Add Turkey code if not present
    if (!cleaned.startsWith('+')) {
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }
      cleaned = '+90$cleaned';
    }

    return cleaned;
  }

  String _generateMockToken(String type) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return '${type}_token_${timestamp}_$random';
  }

  // Get all registered phone numbers (for testing UI)
  // ignore: public_member_api_docs
  List<String> get registeredPhoneNumbers => _mockUsers.keys.toList();
}
