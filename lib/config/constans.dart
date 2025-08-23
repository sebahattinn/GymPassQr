class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // App Info
  static const String appName = 'GymPass QR';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String baseUrl = 'https://api.gympass.com/v1';
  static const String mockBaseUrl = 'mock://api';
  static const bool useMockData = true; // Toggle this for real API

  // API Endpoints
  static const String sendOtpEndpoint = '/auth/send-otp';
  static const String verifyOtpEndpoint = '/auth/verify-otp';
  static const String getUserProfileEndpoint = '/user/profile';
  static const String refreshTokenEndpoint = '/auth/refresh';
  static const String generateQrEndpoint = '/user/generate-qr';

  // Timing Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration otpResendTimeout = Duration(seconds: 30);
  static const int otpLength = 6;
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration tokenRefreshBuffer = Duration(minutes: 5);

  // ---- QR Refresh (TEK NOKTA) ----
  /// Otomatik QR yenileme periyodu (saniye).
  /// Sadece burayı değiştir: örn. 30, 45, 60...
  static const int qrRefreshSeconds = 60;

  /// Mock/gerçek tarafında QR geçerlilik süresi (saniye).
  /// (Mock service bunu kullanır; gerçek API’de de bu değere göre plan yapabilirsiniz.)
  static const int qrValiditySeconds = 60;

  /// Otomatik yenilemeyi aç/kapat.
  static const bool autoQrRefreshEnabled = true;

  /// Otomatik yenileme sırasında overlay açma (sessiz yenile).
  static const bool silentAutoRefresh = true;

  // Storage Keys (for SharedPreferences/SecureStorage)
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyTokenExpiry = 'token_expiry';
  static const String keyUserData = 'user_data';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyPhoneNumber = 'phone_number';

  // Validation Rules
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;
  static const String phoneRegex = r'^\+?[\d\s\-\(\)]+$';

  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const double buttonHeight = 56.0;
  static const int animationDuration = 300; // milliseconds

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String timeoutError = 'Request timed out. Please try again.';
  static const String invalidPhoneError = 'Please enter a valid phone number.';
  static const String invalidOtpError = 'Invalid verification code.';
  static const String sessionExpiredError =
      'Session expired. Please login again.';
  static const String qrGenerationError = 'Failed to generate QR code.';

  // Success Messages
  static const String otpSentSuccess = 'Verification code sent successfully!';
  static const String loginSuccess = 'Login successful!';
  static const String qrGeneratedSuccess = 'QR code ready!';

  // Asset Paths
  static const String logoPath = 'assets/images/logo.png';
  static const String splashBgPath = 'assets/images/splash_bg.png';
  static const String defaultAvatarPath = 'assets/icons/default_avatar.png';
}
