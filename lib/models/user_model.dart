import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// User model with null safety and JSON serialization
/// WHY: Equatable helps with state management comparisons
/// WHY: Factory constructors handle API response variations safely
class User extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? profilePhotoUrl;
  final DateTime membershipStart;
  final DateTime membershipEnd;
  final String membershipType;
  final bool isActive;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.profilePhotoUrl,
    required this.membershipStart,
    required this.membershipEnd,
    required this.membershipType,
    required this.isActive,
  });

  /// FACTORIES (lint: constructors first)
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: _asString(json['id'] ?? json['user_id']),
        firstName: _asString(json['firstName'] ?? json['first_name']),
        lastName: _asString(json['lastName'] ?? json['last_name']),
        phoneNumber: _asString(
            json['phoneNumber'] ?? json['phone_number'] ?? json['phone']),
        profilePhotoUrl: _asStringOrNull(
          json['profilePhotoUrl'] ??
              json['profile_photo_url'] ??
              json['avatar'],
        ),
        membershipStart:
            _parseDate(json['membershipStart'] ?? json['membership_start']),
        membershipEnd:
            _parseDate(json['membershipEnd'] ?? json['membership_end']),
        membershipType: _asString(
            json['membershipType'] ?? json['membership_type'] ?? 'Standard'),
        isActive: _asBool(json['isActive'] ?? json['is_active']) ?? true,
      );
    } catch (e) {
      debugPrint('Error parsing User: $e');
      return User.empty();
    }
  }

  factory User.empty() => User(
        id: '',
        firstName: 'Guest',
        lastName: 'User',
        phoneNumber: '',
        membershipStart: DateTime.now(),
        membershipEnd: DateTime.now(),
        membershipType: 'None',
        isActive: false,
      );

  // Computed
  String get fullName => '$firstName $lastName'.trim();
  bool get isMembershipValid => membershipEnd.isAfter(DateTime.now());
  int get daysRemaining => membershipEnd.difference(DateTime.now()).inDays;

  String get membershipStatus {
    if (!isActive) return 'Inactive';
    if (!isMembershipValid) return 'Expired';
    if (daysRemaining <= 7) return 'Expiring Soon';
    return 'Active';
  }

  // JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'profilePhotoUrl': profilePhotoUrl,
        'membershipStart': membershipStart.toIso8601String(),
        'membershipEnd': membershipEnd.toIso8601String(),
        'membershipType': membershipType,
        'isActive': isActive,
      };

  // Helpers
  static String _asString(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static String? _asStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = _asString(v).trim();
    return s.isEmpty ? null : s;
  }

  static bool? _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    if (v is num) return v != 0;
    return null;
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  // Copy
  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profilePhotoUrl,
    DateTime? membershipStart,
    DateTime? membershipEnd,
    String? membershipType,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      membershipStart: membershipStart ?? this.membershipStart,
      membershipEnd: membershipEnd ?? this.membershipEnd,
      membershipType: membershipType ?? this.membershipType,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        phoneNumber,
        profilePhotoUrl,
        membershipStart,
        membershipEnd,
        membershipType,
        isActive,
      ];
}
