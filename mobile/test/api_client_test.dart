import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:dreamcast/app_state.dart';
import 'package:dreamcast/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request with [status] and records the paths it was asked for.
class _FakeBackend implements HttpClientAdapter {
  final int Function(RequestOptions options) status;
  final List<String> calls = [];

  _FakeBackend(this.status);

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(options.path);
    final code = status(options);
    final body = code == 200
        ? {'status': 'free', 'provider': 'none', 'plan': 'free', 'current_period_end': null}
        : {'detail': 'Could not validate credentials'};
    return ResponseBody.fromString(jsonEncode(body), code, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // A session saved by an earlier run whose user no longer exists on the server.
    FlutterSecureStorage.setMockInitialValues({'access_token': 'stale', 'refresh_token': 'stale'});
  });

  test('a rejected session ends in sign-in instead of refreshing forever', () async {
    // Not Android, so AppState doesn't start Play Billing (absent in tests).
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final backend = _FakeBackend((_) => 401);
    final api = ApiClient(baseUrl: 'http://test')..useAdapter(backend);
    final appState = AppState(api);

    await appState.bootstrap().timeout(const Duration(seconds: 5));

    expect(appState.isLoading, isFalse);
    expect(appState.isLoggedIn, isFalse);
    expect(backend.calls, ['/subscriptions/me', '/auth/refresh']); // one refresh, no loop
    expect(await api.isLoggedIn(), isFalse, reason: 'stale tokens are cleared');
  });

  test('a successful refresh retries the original request once', () async {
    final backend =
        _FakeBackend((o) => o.path == '/subscriptions/me' && o.extra['retried'] != true ? 401 : 200);
    final api = ApiClient(baseUrl: 'http://test')..useAdapter(backend);

    await api.getSubscription();

    expect(backend.calls, ['/subscriptions/me', '/auth/refresh', '/subscriptions/me']);
  });

  test('a wrong password does not try to refresh', () async {
    final backend = _FakeBackend((_) => 401);
    final api = ApiClient(baseUrl: 'http://test')..useAdapter(backend);

    await expectLater(api.login(email: 'a@b.co', password: 'wrongpass'), throwsA(isA<DioException>()));
    expect(backend.calls, ['/auth/login']);
  });
}
