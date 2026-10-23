import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/dream.dart';
import '../models/plan.dart';
import '../models/subscription.dart';

/// Central API client for the DreamCast backend.
///
/// Set [baseUrl] to your deployed backend (e.g. https://api.dreamcast.app/api/v1)
/// via --dart-define=API_BASE_URL=... at build time. Defaults to localhost
/// for local development against `docker compose up`.
class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final Dio _dio;

  /// Bare client for token refresh: it has no 401 handling of its own, so a
  /// rejected refresh can never trigger another refresh.
  final Dio _authDio;

  Future<bool>? _refreshing;

  /// Language the backend should answer in ("en" or "fr"): plan copy, error
  /// messages and AI readings. Kept in sync with the app's active locale.
  String languageCode = 'en';

  static BaseOptions _options(String? baseUrl) => BaseOptions(
        baseUrl: baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000/api/v1',
            ),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      );

  ApiClient({String? baseUrl})
      : _dio = Dio(_options(baseUrl)),
        _authDio = Dio(_options(baseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readToken(_accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Accept-Language'] = languageCode;
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final canRefresh = error.response?.statusCode == 401 &&
            request.extra['retried'] != true &&
            !request.path.startsWith('/auth/');
        if (!canRefresh) return handler.next(error);

        // One refresh at a time, and each request is retried at most once.
        final refreshed = await (_refreshing ??= _tryRefreshToken().whenComplete(() => _refreshing = null));
        if (!refreshed) {
          await logout(); // the session is gone; start clean next time
          return handler.next(error);
        }
        try {
          request.extra['retried'] = true;
          return handler.resolve(await _dio.fetch(request));
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      },
    ));
  }

  /// Routes all requests through [adapter] (tests use a fake backend).
  @visibleForTesting
  void useAdapter(HttpClientAdapter adapter) {
    _dio.httpClientAdapter = adapter;
    _authDio.httpClientAdapter = adapter;
  }

  /// Reads a stored token; unreadable storage (e.g. cleared browser keys) counts as signed out.
  Future<String?> _readToken(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _readToken(_refreshTokenKey);
    if (refreshToken == null) return false;
    try {
      final resp = await _authDio.post(
        '/auth/refresh',
        queryParameters: {'refresh_token': refreshToken},
        options: Options(headers: {'Accept-Language': languageCode}),
      );
      await _saveTokens(resp.data);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- Auth ----------
  Future<void> signup({required String email, required String password, String? displayName}) async {
    final resp = await _dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    await _saveTokens(resp.data);
  }

  Future<void> login({required String email, required String password}) async {
    final resp = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    await _saveTokens(resp.data);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(key: _accessTokenKey, value: data['access_token']);
    await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
  }

  Future<void> logout() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {
      // Nothing readable to delete.
    }
  }

  Future<bool> isLoggedIn() async {
    return (await _readToken(_accessTokenKey)) != null;
  }

  // ---------- Dreams ----------
  Future<Dream> submitDream(String rawText) async {
    // A detailed reading takes the Oracle up to a minute or two to write.
    final resp = await _dio.post(
      '/dreams',
      data: {'raw_text': rawText},
      options: Options(receiveTimeout: const Duration(minutes: 3)),
    );
    return Dream.fromJson(resp.data);
  }

  /// Flags an AI-generated reading or image for review.
  /// [reason]: offensive | harmful | inaccurate | image | other
  Future<void> reportDream(String dreamId, {required String reason, String? details}) async {
    await _dio.post('/dreams/$dreamId/report', data: {'reason': reason, 'details': details});
  }

  Future<List<Dream>> listDreams({int limit = 50, int offset = 0}) async {
    final resp = await _dio.get('/dreams', queryParameters: {'limit': limit, 'offset': offset});
    return (resp.data as List).map((d) => Dream.fromJson(d)).toList();
  }

  // ---------- Account ----------
  /// Permanently deletes the account and all its data, then signs out locally.
  Future<void> deleteAccount() async {
    await _dio.delete('/users/me');
    await logout();
  }

  // ---------- Subscriptions ----------
  Future<SubscriptionStatus> getSubscription() async {
    final resp = await _dio.get('/subscriptions/me');
    return SubscriptionStatus.fromJson(resp.data);
  }

  /// Paid plans in display order (Lucid, Mystic, Oracle) with their Play product ids.
  Future<List<Plan>> getPlans() async {
    final resp = await _dio.get('/subscriptions/plans');
    return (resp.data as List).map((p) => Plan.fromJson(p)).toList();
  }

  /// After a successful Google Play purchase, send the purchase token here
  /// so the backend can verify it server-side and unlock Pro features.
  Future<SubscriptionStatus> verifyMobilePurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final resp = await _dio.post('/subscriptions/verify-mobile-purchase', data: {
      'purchase_token': purchaseToken,
      'product_id': productId,
    });
    return SubscriptionStatus.fromJson(resp.data);
  }
}
