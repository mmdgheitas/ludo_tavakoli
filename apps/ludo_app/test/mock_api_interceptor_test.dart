import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_app/core/network/mock_api_interceptor.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://mock.local'));
    dio.interceptors.add(MockApiInterceptor());
  });

  test('returns a mock user without network access', () async {
    final response = await dio.get<Map<String, dynamic>>('/users/me');
    expect(response.statusCode, 200);
    expect(response.data?['username'], 'بازیکن_آزمایشی');
  });

  test('daily reward updates the in-memory wallet', () async {
    final before = await dio.get<Map<String, dynamic>>('/users/me');
    await dio.post<void>('/wallet/daily-reward');
    final after = await dio.get<Map<String, dynamic>>('/users/me');
    expect(after.data?['coinBalance'], (before.data?['coinBalance'] as int) + 100);
  });

  test('unknown routes never fall through to the real backend', () async {
    await expectLater(
      dio.get<void>('/unknown'),
      throwsA(isA<DioException>().having((error) => error.response?.statusCode, 'status', 404)),
    );
  });
}
