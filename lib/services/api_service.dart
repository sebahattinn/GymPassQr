import 'package:dio/dio.dart';
import 'package:gym_pass_qr/config/constans.dart';
import 'package:gym_pass_qr/services/storage_service.dart';
import 'package:gym_pass_qr/utils/logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Centralized API service using Dio
/// Handles: base config, auth header, refresh, retry, logging.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Dio? _dio; // lazy

  final StorageService _storage = StorageService();

  /// Public initializer (idempotent). Safe to call multiple times.
  void init() {
    if (_dio != null) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.useMockData
            ? AppConstants.mockBaseUrl
            : AppConstants.baseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio!.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_isAuthEndpoint(options.path)) {
            final token = await _storage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          AppLogger.debug('➡️ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (resp, handler) {
          AppLogger.debug('✅ ${resp.statusCode} ${resp.requestOptions.path}');
          handler.next(resp);
        },
        onError: (err, handler) async {
          AppLogger.error('❌ API Error: ${err.message}', err);

          final status = err.response?.statusCode;
          final isAuthPath = _isAuthEndpoint(err.requestOptions.path);

          if (status == 401 && !isAuthPath) {
            final ok = await _refreshToken();
            if (ok) {
              final retried = await _retry(err.requestOptions);
              return handler.resolve(retried);
            }
          }
          handler.next(err);
        },
      ),
      if (AppConstants.useMockData)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
        ),
    ]);
  }

  // ---------- Public HTTP helpers ----------
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final dio = _ensure();
    try {
      return await dio.get<T>(path,
          queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _asException(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final dio = _ensure();
    try {
      return await dio.post<T>(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _asException(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final dio = _ensure();
    try {
      return await dio.put<T>(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _asException(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final dio = _ensure();
    try {
      return await dio.delete<T>(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _asException(e);
    }
  }

  // ---------- Private ----------
  Dio _ensure() {
    init(); // lazy
    return _dio!;
  }

  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/') ||
      path.contains('/send-otp') ||
      path.contains('/verify-otp');

  Future<bool> _refreshToken() async {
    try {
      final rt = await _storage.getRefreshToken();
      if (rt == null || rt.isEmpty) return false;

      final resp = await _dio!.post(
        AppConstants.refreshTokenEndpoint,
        data: {'refreshToken': rt},
      );
      if (resp.statusCode == 200) {
        final newAccess = resp.data['accessToken'] as String?;
        final expiresIn = (resp.data['expiresIn'] as int?) ?? 3600;
        if (newAccess == null || newAccess.isEmpty) return false;

        await _storage.saveAccessToken(newAccess);
        await _storage.saveTokenExpiry(
          DateTime.now().add(Duration(seconds: expiresIn)),
        );
        AppLogger.info('🔄 Token refreshed');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Refresh token failed', e);
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions o) async {
    final token = await _storage.getAccessToken();
    final opts = Options(method: o.method, headers: {
      ...o.headers,
      if (token != null) 'Authorization': 'Bearer $token',
    });
    return _dio!.request<dynamic>(
      o.path,
      data: o.data,
      queryParameters: o.queryParameters,
      options: opts,
    );
  }

  Exception _asException(DioException e) {
    String msg;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        msg = AppConstants.timeoutError;
        break;
      case DioExceptionType.connectionError:
        msg = AppConstants.networkError;
        break;
      case DioExceptionType.badResponse:
        msg = _statusMessage(e.response?.statusCode);
        final data = e.response?.data;
        if (data is Map && (data['message'] ?? data['error']) != null) {
          msg = (data['message'] ?? data['error']).toString();
        }
        break;
      case DioExceptionType.cancel:
        msg = 'Request cancelled';
        break;
      default:
        msg = AppConstants.genericError;
    }
    return Exception(msg);
  }

  String _statusMessage(int? code) {
    switch (code) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Session expired. Please login again.';
      case 403:
        return 'Access denied.';
      case 404:
        return 'Resource not found.';
      case 422:
        return 'Invalid data provided.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        return AppConstants.genericError;
    }
  }
}
