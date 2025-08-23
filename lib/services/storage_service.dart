import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gym_pass_qr/config/constans.dart';
import 'package:gym_pass_qr/models/user_model.dart';
import 'package:gym_pass_qr/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Secure storage for sensitive data
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Regular storage for non-sensitive data
  SharedPreferences? _prefs;

  /// Initialize storage service
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      AppLogger.info('Storage service initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize storage', e);
    }
  }

  // ============== TOKEN MANAGEMENT ==============

  /// Save access token securely
  Future<bool> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(
        key: AppConstants.keyAccessToken,
        value: token,
      );
      AppLogger.debug('Access token saved');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save access token', e);
      return false;
    }
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: AppConstants.keyAccessToken);
      return token;
    } catch (e) {
      AppLogger.error('Failed to get access token', e);
      return null;
    }
  }

  /// Save refresh token securely
  Future<bool> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(
        key: AppConstants.keyRefreshToken,
        value: token,
      );
      AppLogger.debug('Refresh token saved');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save refresh token', e);
      return false;
    }
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    try {
      final token =
          await _secureStorage.read(key: AppConstants.keyRefreshToken);
      return token;
    } catch (e) {
      AppLogger.error('Failed to get refresh token', e);
      return null;
    }
  }

  /// Save token expiry time
  Future<bool> saveTokenExpiry(DateTime expiry) async {
    try {
      await _prefs?.setString(
        AppConstants.keyTokenExpiry,
        expiry.toIso8601String(),
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to save token expiry', e);
      return false;
    }
  }

  /// Get token expiry time
  Future<DateTime?> getTokenExpiry() async {
    try {
      final expiryStr = _prefs?.getString(AppConstants.keyTokenExpiry);
      if (expiryStr != null) {
        return DateTime.parse(expiryStr);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get token expiry', e);
      return null;
    }
  }

  /// Check if token is valid (not expired)
  Future<bool> isTokenValid() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return false;

      final expiry = await getTokenExpiry();
      if (expiry == null) return false;

      // Add buffer time (5 minutes) for safety
      final bufferTime = DateTime.now().add(AppConstants.tokenRefreshBuffer);
      return expiry.isAfter(bufferTime);
    } catch (e) {
      AppLogger.error('Failed to check token validity', e);
      return false;
    }
  }

  // ============== USER DATA MANAGEMENT ==============

  /// Save user data
  Future<bool> saveUser(User user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await _prefs?.setString(AppConstants.keyUserData, userJson);
      AppLogger.debug('User data saved');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save user data', e);
      return false;
    }
  }

  /// Get user data
  Future<User?> getUser() async {
    try {
      final userJson = _prefs?.getString(AppConstants.keyUserData);
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return User.fromJson(userMap);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get user data', e);
      return null;
    }
  }

  /// Save last used phone number (for convenience)
  Future<bool> savePhoneNumber(String phoneNumber) async {
    try {
      await _prefs?.setString(AppConstants.keyPhoneNumber, phoneNumber);
      return true;
    } catch (e) {
      AppLogger.error('Failed to save phone number', e);
      return false;
    }
  }

  /// Get last used phone number
  String? getPhoneNumber() {
    return _prefs?.getString(AppConstants.keyPhoneNumber);
  }

  // ============== APP PREFERENCES ==============

  /// Check if this is first launch
  bool isFirstLaunch() {
    return _prefs?.getBool(AppConstants.keyFirstLaunch) ?? true;
  }

  /// Mark first launch as complete
  Future<void> setFirstLaunchComplete() async {
    await _prefs?.setBool(AppConstants.keyFirstLaunch, false);
  }

  // ============== CLEANUP ==============

  /// Clear all authentication data (logout)
  Future<void> clearAuthData() async {
    try {
      await _secureStorage.delete(key: AppConstants.keyAccessToken);
      await _secureStorage.delete(key: AppConstants.keyRefreshToken);
      await _prefs?.remove(AppConstants.keyTokenExpiry);
      await _prefs?.remove(AppConstants.keyUserData);
      AppLogger.info('Auth data cleared');
    } catch (e) {
      AppLogger.error('Failed to clear auth data', e);
    }
  }

  /// Clear all app data (full reset)
  Future<void> clearAllData() async {
    try {
      await _secureStorage.deleteAll();
      await _prefs?.clear();
      AppLogger.info('All data cleared');
    } catch (e) {
      AppLogger.error('Failed to clear all data', e);
    }
  }
}
