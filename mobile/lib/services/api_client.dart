import 'package:dio/dio.dart';
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

  ApiClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ??
              const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.0.2.2:8000/api/v1',
              ),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            final clone = await _retry(error.requestOptions);
            return handler.resolve(clone);
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await _storage.read(key: _accessTokenKey);
    final options = Options(method: requestOptions.method, headers: {
      ...requestOptions.headers,
      'Authorization': 'Bearer $token',
    });
    return _dio.request(requestOptions.path,
        data: requestOptions.data, queryParameters: requestOptions.queryParameters, options: options);
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return false;
    try {
      final resp = await _dio.post('/auth/refresh', queryParameters: {
        'refresh_token': refreshToken,
      });
      await _storage.write(key: _accessTokenKey, value: resp.data['access_token']);
      await _storage.write(key: _refreshTokenKey, value: resp.data['refresh_token']);
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
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> isLoggedIn() async {
    return (await _storage.read(key: _accessTokenKey)) != null;
  }

  // ---------- Dreams ----------
  Future<Dream> submitDream(String rawText) async {
    final resp = await _dio.post('/dreams', data: {'raw_text': rawText});
    return Dream.fromJson(resp.data);
  }

  Future<List<Dream>> listDreams({int limit = 50, int offset = 0}) async {
    final resp = await _dio.get('/dreams', queryParameters: {'limit': limit, 'offset': offset});
    return (resp.data as List).map((d) => Dream.fromJson(d)).toList();
  }

  // ---------- Subscriptions ----------
  Future<SubscriptionStatus> getSubscription() async {
    final resp = await _dio.get('/subscriptions/me');
    return SubscriptionStatus.fromJson(resp.data);
  }

  /// Paid plans in display order (Lucid, Mystic, Oracle), priced in XAF.
  Future<List<Plan>> getPlans() async {
    final resp = await _dio.get('/subscriptions/plans');
    return (resp.data as List).map((p) => Plan.fromJson(p)).toList();
  }

  /// Starts a Flutterwave checkout (mobile money or card) and returns the
  /// hosted payment page URL to open in the browser.
  Future<String> startCheckout(String planId) async {
    final resp = await _dio.post('/subscriptions/flutterwave/checkout', data: {'plan': planId});
    return resp.data['checkout_url'] as String;
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
