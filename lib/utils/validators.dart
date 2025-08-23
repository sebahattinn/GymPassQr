import '../config/constans.dart';

/// Input validation utilities
/// WHY: Prevent bad data from entering the system
/// Validates at UI level before sending to API

class Validators {
  Validators._();

  /// Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove all spaces and special characters except + and digits
    final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');

    // Check length
    if (cleaned.length < AppConstants.minPhoneLength) {
      return 'Phone number is too short';
    }

    if (cleaned.length > AppConstants.maxPhoneLength) {
      return 'Phone number is too long';
    }

    // Check format
    if (!RegExp(AppConstants.phoneRegex).hasMatch(cleaned)) {
      return 'Invalid phone number format';
    }

    return null; // Valid
  }

  /// Validate OTP code
  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Verification code is required';
    }

    if (value.length != AppConstants.otpLength) {
      return 'Code must be ${AppConstants.otpLength} digits';
    }

    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Code must contain only numbers';
    }

    return null; // Valid
  }

  /// Format phone number for display
  static String formatPhoneForDisplay(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Format as Turkish phone number (90 555 123 45 67)
    if (cleaned.startsWith('90') && cleaned.length == 12) {
      return '+${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5, 8)} ${cleaned.substring(8, 10)} ${cleaned.substring(10)}';
    }

    // Format as standard international
    if (cleaned.length >= 10) {
      return '+$cleaned';
    }

    return phone;
  }

  /// Clean phone number for API
  static String cleanPhoneForApi(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Ensure it starts with +
    if (!cleaned.startsWith('+')) {
      // Assume Turkey if no country code
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }
      cleaned = '+90$cleaned';
    }

    return cleaned;
  }

  /// Validate membership status
  static bool isMembershipValid(DateTime? endDate) {
    if (endDate == null) return false;
    return endDate.isAfter(DateTime.now());
  }

  /// Check if membership is expiring soon (within 7 days)
  static bool isMembershipExpiringSoon(DateTime? endDate) {
    if (endDate == null) return false;
    final daysRemaining = endDate.difference(DateTime.now()).inDays;
    return daysRemaining > 0 && daysRemaining <= 7;
  }
}
