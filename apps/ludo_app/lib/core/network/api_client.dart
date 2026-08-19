import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ludo_app/core/config/app_config.dart';

class ApiClient {
  ApiClient(this._storage)
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        )) {
    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401 ||
            error.requestOptions.extra['retried'] == true) {
          return handler.next(error);
        }
        try {
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken == null) return handler.next(error);
          final response = await Dio().post<Map<String, dynamic>>(
            '${AppConfig.apiBaseUrl}/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          final data = response.data!;
          await saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
          final request = error.requestOptions;
          request.extra['retried'] = true;
          request.headers['Authorization'] = 'Bearer ${data['accessToken']}';
          return handler.resolve(await dio.fetch(request));
        } catch (_) {
          await clearTokens();
          return handler.next(error);
        }
      },
    ));
  }

  final FlutterSecureStorage _storage;
  final Dio dio;

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
