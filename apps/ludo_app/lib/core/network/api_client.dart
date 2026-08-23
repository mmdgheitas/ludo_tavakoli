import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ludo_app/core/config/app_config.dart';
import 'package:ludo_app/core/network/mock_api_interceptor.dart';

class ApiClient {
  ApiClient(this._storage)
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        )) {
    if (AppConfig.useMockData) {
      dio.interceptors.add(MockApiInterceptor());
      return;
    }
    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final refresh = _refreshing;
        if (refresh != null) await refresh;
        final token = await _storage.read(key: 'access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401 || error.requestOptions.extra['retried'] == true) {
          return handler.next(error);
        }
        try {
          await refreshTokens();
          final accessToken = await readAccessToken();
          if (accessToken == null) return handler.next(error);
          final request = error.requestOptions;
          request.extra['retried'] = true;
          request.headers['Authorization'] = 'Bearer $accessToken';
          return handler.resolve(await dio.fetch(request));
        } catch (_) {
          return handler.next(error);
        }
      },
    ));
  }

  final FlutterSecureStorage _storage;
  final Dio dio;
  Future<void>? _refreshing;

  Future<void> refreshTokens() {
    final existing = _refreshing;
    if (existing != null) return existing;
    final operation = _performRefresh();
    _refreshing = operation;
    return operation.whenComplete(() => _refreshing = null);
  }

  Future<void> _performRefresh() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) throw StateError('No refresh token');
    try {
      final response = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)))
          .post<Map<String, dynamic>>('${AppConfig.apiBaseUrl}/auth/refresh', data: {'refreshToken': refreshToken});
      final data = response.data!;
      await saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
    } catch (_) {
      await clearTokens();
      rethrow;
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: 'access_token');

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _storage.write(key: 'access_token', value: accessToken),
      _storage.write(key: 'refresh_token', value: refreshToken),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: 'access_token'),
      _storage.delete(key: 'refresh_token'),
    ]);
  }
}
