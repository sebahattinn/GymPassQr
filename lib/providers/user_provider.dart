import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gym_pass_qr/config/constans.dart';
import 'package:gym_pass_qr/models/auth_model.dart';
import 'package:gym_pass_qr/models/user_model.dart';
import 'package:gym_pass_qr/services/auth_service.dart';
import 'package:gym_pass_qr/utils/logger.dart';

/// User and QR code state management
/// WHY: Manages user-specific data and QR generation
/// Separate from auth to keep concerns isolated
class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // State
  User? _user;
  QrCodeData? _qrCodeData;
  bool _isLoadingQr = false; // manuel (buton/pull-to-refresh) için
  bool _isRefreshing = false; // manuel tüm veriyi yenileme için
  String? _errorMessage;

  // Tek otomatik yenileme zamanlayıcısı
  Timer? _qrTimer;

  // 🔒 Spam ve hot-reload timerlarına karşı koruma
  bool _autoRefreshing = false; // eşzamanlı çağrıyı engeller
  DateTime? _lastAutoRefreshAt; // en son otomatik yenileme zamanı

  // Getters
  User? get user => _user;
  QrCodeData? get qrCodeData => _qrCodeData;
  bool get isLoadingQr => _isLoadingQr;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  bool get hasValidQr => _qrCodeData != null && _qrCodeData!.isValid;

  /// Login sonrası çağrılır
  void setUser(User user) {
    _user = user;
    notifyListeners();

    // İlk QR'ı hemen üret (overlay ile)
    generateQrCode(silent: false);

    // Tek timer başlat (tek merkez: AppConstants)
    _startQrAutoRefresh();
  }

  /// QR üret
  /// silent=true -> otomatik yenilemede overlay açma (UI titremez)
  Future<void> generateQrCode({bool silent = false}) async {
    try {
      if (_user == null) {
        AppLogger.warning('Cannot generate QR - no user');
        return;
      }

      if (!silent) {
        _isLoadingQr = true;
        _errorMessage = null;
        notifyListeners();
      } else {
        _errorMessage = null;
      }

      final newQr = await _authService.generateQrCode();
      _qrCodeData = newQr;

      // İlk/manuel üretimden sonra throttle referansı oluşsun
      _lastAutoRefreshAt ??= DateTime.now();

      if (!silent) _isLoadingQr = false;
      notifyListeners();

      AppLogger.debug('QR code generated successfully'); // info -> debug
    } catch (e) {
      if (!silent) _isLoadingQr = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      AppLogger.error('Failed to generate QR code', e);
    }
  }

  /// Tüm verileri manuel yenile (pull-to-refresh)
  Future<void> refreshData() async {
    try {
      _isRefreshing = true;
      _errorMessage = null;
      notifyListeners();

      _user = await _authService.getUserProfile();
      _qrCodeData = await _authService.generateQrCode();

      // Manuel yenilemede de referansı güncelle
      _lastAutoRefreshAt = DateTime.now();

      _isRefreshing = false;
      notifyListeners();

      AppLogger.info('User data refreshed');
    } catch (e) {
      _isRefreshing = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      AppLogger.error('Failed to refresh user data', e);
    }
  }

  /// Logout sırasında çağrılmalı
  void clearData() {
    _qrTimer?.cancel();
    _qrTimer = null;

    _autoRefreshing = false;
    _lastAutoRefreshAt = null;

    _user = null;
    _qrCodeData = null;
    _errorMessage = null;
    _isLoadingQr = false;
    _isRefreshing = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============== PRIVATE ==============

  void _startQrAutoRefresh() {
    _qrTimer?.cancel();

    if (!AppConstants.autoQrRefreshEnabled) {
      AppLogger.debug('Auto QR refresh disabled.');
      return;
    }

    const period = Duration(seconds: AppConstants.qrRefreshSeconds);
    AppLogger.debug(
      'Starting periodic QR refresh every ${period.inSeconds}s',
    );

    _qrTimer = Timer.periodic(period, (_) async {
      if (_user == null || _autoRefreshing) return;

      // Eski bir timer/hot-reload olsa bile, zorunlu minimum aralığı uygula
      final now = DateTime.now();
      if (_lastAutoRefreshAt != null) {
        final elapsed = now.difference(_lastAutoRefreshAt!).inSeconds;
        if (elapsed < AppConstants.qrRefreshSeconds) return;
      }

      _autoRefreshing = true;
      try {
        await generateQrCode(silent: AppConstants.silentAutoRefresh);
        _lastAutoRefreshAt = now;
      } finally {
        _autoRefreshing = false;
      }
    });
  }
}
