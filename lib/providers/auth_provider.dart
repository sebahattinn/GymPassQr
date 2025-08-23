import 'package:flutter/foundation.dart';
import 'package:gym_pass_qr/models/user_model.dart';
import 'package:gym_pass_qr/services/auth_service.dart';
import 'package:gym_pass_qr/utils/logger.dart';

/// Authentication state management
/// WHY: Separates UI from business logic, provides reactive updates
/// Manages: Login flow, user state, loading states, errors

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // State variables
  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  String? _phoneNumber;
  bool _isResendEnabled = false;
  int _resendCountdown = 0;
  bool _isLoading = false;

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get phoneNumber => _phoneNumber;
  bool get isResendEnabled => _isResendEnabled;
  int get resendCountdown => _resendCountdown;
  bool get isLoading => _isLoading;
  bool get isAuthenticated =>
      _state == AuthState.authenticated && _user != null;

  /// Initialize provider and check existing session
  Future<void> initialize() async {
    try {
      AppLogger.info('AuthProvider: Initializing...');
      _setState(AuthState.loading);

      // Check if we have an existing valid session
      final hasSession = await _authService.initialize();

      if (hasSession) {
        // We have a valid session, get the user
        _user = _authService.currentUser;

        if (_user != null) {
          _setState(AuthState.authenticated);
          AppLogger.info(
              'AuthProvider: User session restored for ${_user!.fullName}');
        } else {
          // This shouldn't happen, but handle it
          _setState(AuthState.unauthenticated);
          AppLogger.warning('AuthProvider: Session exists but no user data');
        }
      } else {
        // No valid session
        _setState(AuthState.unauthenticated);
        AppLogger.info('AuthProvider: No valid session found');
      }
    } catch (e) {
      AppLogger.error('AuthProvider: Failed to initialize', e);
      _setState(AuthState.unauthenticated);
    }
  }

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _phoneNumber = phoneNumber;
      notifyListeners();

      await _authService.sendOtp(phoneNumber);

      // Start resend countdown
      _startResendCountdown();

      // Clear loading state
      _isLoading = false;
      notifyListeners();

      AppLogger.info('AuthProvider: OTP sent successfully');
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      AppLogger.error('AuthProvider: Failed to send OTP', e);
      rethrow;
    }
  }

  /// Verify OTP code
  Future<bool> verifyOtp(String otp) async {
    try {
      if (_phoneNumber == null) {
        throw Exception('Phone number not set');
      }

      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Verify OTP and get auth response
      final authResponse = await _authService.verifyOtp(_phoneNumber!, otp);

      // Set user and update state
      _user = authResponse.user;
      _isLoading = false;
      _setState(AuthState.authenticated);

      AppLogger.info(
          'AuthProvider: OTP verified successfully for ${_user!.fullName}');
      AppLogger.info(
          'AuthProvider: Token will be valid for ${authResponse.expiresIn} seconds');

      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setState(AuthState.error);
      AppLogger.error('AuthProvider: Failed to verify OTP', e);
      return false;
    }
  }

  /// Resend OTP
  Future<void> resendOtp() async {
    try {
      if (_phoneNumber == null) {
        throw Exception('Phone number not set');
      }

      if (!_isResendEnabled) {
        return;
      }

      _errorMessage = null;
      await _authService.sendOtp(_phoneNumber!);

      // Restart countdown
      _startResendCountdown();

      AppLogger.info('AuthProvider: OTP resent successfully');
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      AppLogger.error('AuthProvider: Failed to resend OTP', e);
    }
  }

  /// Refresh user profile
  Future<void> refreshUserProfile() async {
    try {
      if (!isAuthenticated) return;

      final updatedUser = await _authService.getUserProfile();
      _user = updatedUser;
      notifyListeners();

      AppLogger.info('AuthProvider: User profile refreshed');
    } catch (e) {
      AppLogger.error('AuthProvider: Failed to refresh user profile', e);
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      AppLogger.info('AuthProvider: Logging out user ${_user?.fullName}');

      // Clear all auth data from storage
      await _authService.logout();

      // Clear local state
      _user = null;
      _phoneNumber = null;
      _errorMessage = null;
      _isLoading = false;
      _setState(AuthState.unauthenticated);

      AppLogger.info('AuthProvider: Logged out successfully');
    } catch (e) {
      AppLogger.error('AuthProvider: Error during logout', e);
      // Even if error, clear local state
      _user = null;
      _isLoading = false;
      _setState(AuthState.unauthenticated);
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _setState(AuthState.unauthenticated);
    } else {
      notifyListeners();
    }
  }

  // ============== PRIVATE HELPER METHODS ==============

  /// Update state and notify listeners
  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Start OTP resend countdown
  void _startResendCountdown() {
    _isResendEnabled = false;
    _resendCountdown = 30;
    notifyListeners();

    // Countdown timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      _resendCountdown--;

      if (_resendCountdown <= 0) {
        _isResendEnabled = true;
        _resendCountdown = 0;
        notifyListeners();
        return false;
      }

      notifyListeners();
      return true;
    });
  }
}
