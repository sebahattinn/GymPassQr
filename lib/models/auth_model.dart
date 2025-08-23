import 'dart:convert';
import 'package:gym_pass_qr/models/user_model.dart';

/// Authentication related models
/// WHY: Separate auth logic from user data for clean architecture

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn; // seconds
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userMap = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    return AuthResponse(
      accessToken: (json['accessToken'] as String?) ??
          (json['access_token'] as String?) ??
          '',
      refreshToken: (json['refreshToken'] as String?) ??
          (json['refresh_token'] as String?) ??
          '',
      expiresIn: _asInt(json['expiresIn'] ?? json['expires_in']) ?? 3600,
      user: User.fromJson(userMap),
    );
  }

  DateTime get expiryTime => DateTime.now().add(Duration(seconds: expiresIn));

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresIn': expiresIn,
        'user': user.toJson(),
      };

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class OtpRequest {
  final String phoneNumber;
  const OtpRequest({required this.phoneNumber});

  Map<String, dynamic> toJson() => {'phoneNumber': phoneNumber};
}

class OtpVerification {
  final String phoneNumber;
  final String code;
  const OtpVerification({required this.phoneNumber, required this.code});

  Map<String, dynamic> toJson() => {'phoneNumber': phoneNumber, 'code': code};
}

class QrCodeData {
  final String userId;
  final String token;
  final DateTime validUntil;
  final Map<String, dynamic> metadata;

  const QrCodeData({
    required this.userId,
    required this.token,
    required this.validUntil,
    required this.metadata,
  });

  factory QrCodeData.fromJson(Map<String, dynamic> json) {
    return QrCodeData(
      userId: (json['userId'] as String?) ?? (json['user_id'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      validUntil: _asDateTime(json['validUntil'] ?? json['valid_until']) ??
          DateTime.now(),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'token': token,
        'validUntil': validUntil.toIso8601String(),
        'metadata': metadata,
      };

  bool get isValid => validUntil.isAfter(DateTime.now());

  /// QR içine sadece opaque token + expiry koy (PII yok, sade JSON)
  String get qrContent =>
      jsonEncode({'t': token, 'exp': validUntil.toIso8601String()});

  static DateTime? _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
