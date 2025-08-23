import 'package:gym_pass_qr/config/constans.dart';
import 'package:gym_pass_qr/mock/mock_data_service.dart';
import 'package:gym_pass_qr/models/auth_model.dart';
import 'package:gym_pass_qr/models/user_model.dart';
import 'package:gym_pass_qr/services/api_service.dart';
import 'package:gym_pass_qr/services/storage_service.dart';
import 'package:gym_pass_qr/utils/logger.dart';
import 'package:gym_pass_qr/utils/validators.dart';

class AuthService {
  factory AuthService() => _instance;
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  final MockDataService _mock = MockDataService();

  User? _currentUser;
  User? get currentUser => _currentUser;

  Future<bool> initialize() async {
    try {
      final isValid = await _storage.isTokenValid();
      if (!isValid) {
        AppLogger.info('No valid session found');
        return false;
      }

      _currentUser = await _storage.getUser();
      if (_currentUser == null) {
        AppLogger.info('No user data found');
        return false;
      }

      AppLogger.info('Session restored for user: ${_currentUser!.fullName}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to initialize auth', e);
      return false;
    }
  }

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    try {
      final normalized = Validators.cleanPhoneForApi(phoneNumber);
      AppLogger.info('Sending OTP to: $normalized');

      if (AppConstants.useMockData) {
        await _mock.sendOtp(normalized);
      } else {
        await _api.post(
          AppConstants.sendOtpEndpoint,
          data: OtpRequest(phoneNumber: normalized).toJson(),
        );
      }

      await _storage.savePhoneNumber(normalized);
      AppLogger.info('OTP sent successfully');
    } catch (e) {
      AppLogger.error('Failed to send OTP', e);
      rethrow;
    }
  }

  /// Verify OTP and complete login
  Future<AuthResponse> verifyOtp(String phoneNumber, String otp) async {
    try {
      final normalized = Validators.cleanPhoneForApi(phoneNumber);
      AppLogger.info('Verifying OTP for: $normalized');

      final AuthResponse authResponse;
      if (AppConstants.useMockData) {
        authResponse = await _mock.verifyOtp(normalized, otp);
      } else {
        final resp = await _api.post(
          AppConstants.verifyOtpEndpoint,
          data: OtpVerification(phoneNumber: normalized, code: otp).toJson(),
        );
        final map = _asMap(resp.data);
        authResponse = AuthResponse.fromJson(map);
      }

      await _saveAuthData(authResponse);
      _currentUser = authResponse.user;

      AppLogger.info('Login successful for: ${_currentUser!.fullName}');
      return authResponse;
    } catch (e) {
      AppLogger.error('Failed to verify OTP', e);
      rethrow;
    }
  }

  /// Get current user profile (refresh from server)
  Future<User> getUserProfile() async {
    try {
      final cu = _currentUser;
      if (cu == null) {
        throw Exception('No user logged in');
      }

      AppLogger.info('Fetching user profile');

      final User user;
      if (AppConstants.useMockData) {
        user = await _mock.getUserProfile(cu.id);
      } else {
        final resp = await _api.get(AppConstants.getUserProfileEndpoint);
        final map = _asMap(resp.data);
        user = User.fromJson(map);
      }

      _currentUser = user;
      await _storage.saveUser(user);
      AppLogger.info('User profile updated');
      return user;
    } catch (e) {
      AppLogger.error('Failed to get user profile', e);
      rethrow;
    }
  }

  /// Generate QR code for current user
  Future<QrCodeData> generateQrCode() async {
    try {
      final cu = _currentUser;
      if (cu == null) {
        throw Exception('No user logged in');
      }

      AppLogger.info('Generating QR code');

      final QrCodeData qrData;
      if (AppConstants.useMockData) {
        qrData = await _mock.generateQrCode(cu.id);
      } else {
        final resp = await _api.post(AppConstants.generateQrEndpoint);
        final map = _asMap(resp.data);
        qrData = QrCodeData.fromJson(map);
      }

      AppLogger.debug('QR code generated successfully'); // info -> debug
      return qrData;
    } catch (e) {
      AppLogger.error('Failed to generate QR code', e);
      rethrow;
    }
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      final rt = await _storage.getRefreshToken();
      if (rt == null || rt.isEmpty) {
        AppLogger.warning('No refresh token available');
        return false;
      }

      AppLogger.info('Refreshing access token');

      if (AppConstants.useMockData) {
        final result = await _mock.refreshToken(rt);
        final newToken = (result['accessToken'] as String?) ?? '';
        final expiresIn = (result['expiresIn'] as num?)?.toInt() ?? 3600;
        if (newToken.isEmpty) return false;

        await _storage.saveAccessToken(newToken);
        await _storage.saveTokenExpiry(
          DateTime.now().add(Duration(seconds: expiresIn)),
        );
      } else {
        final resp = await _api.post(
          AppConstants.refreshTokenEndpoint,
          data: <String, dynamic>{'refreshToken': rt},
        );
        final map = _asMap(resp.data);
        final newToken = (map['accessToken'] as String?) ?? '';
        final expiresIn = (map['expiresIn'] as num?)?.toInt() ?? 3600;
        if (newToken.isEmpty) return false;

        await _storage.saveAccessToken(newToken);
        await _storage.saveTokenExpiry(
          DateTime.now().add(Duration(seconds: expiresIn)),
        );
      }

      AppLogger.info('Token refreshed successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to refresh token', e);
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      AppLogger.info('Logging out user: ${_currentUser?.fullName}');
      await _storage.clearAuthData();
      _currentUser = null;
      AppLogger.info('Logout successful');
    } catch (e) {
      AppLogger.error('Error during logout', e);
      _currentUser = null;
      await _storage.clearAuthData();
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final valid = await _storage.isTokenValid();
    return valid && _currentUser != null;
  }

  // ============== PRIVATE HELPERS ==============

  Future<void> _saveAuthData(AuthResponse a) async {
    await _storage.saveAccessToken(a.accessToken);
    await _storage.saveRefreshToken(a.refreshToken);
    await _storage.saveTokenExpiry(a.expiryTime);
    await _storage.saveUser(a.user);
  }

  /// Safely cast any `resp.data` to Map<String, dynamic>
  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
