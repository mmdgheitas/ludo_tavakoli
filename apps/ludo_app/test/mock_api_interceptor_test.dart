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

  test('fattah inventory is readable and grows with a rocket purchase', () async {
    final before = await dio.get<Map<String, dynamic>>('/fattah/balance');
    expect(before.statusCode, 200);
    expect(before.data?['maxUsagePerGame'], 1);
    final initial = before.data?['balance'] as int;

    await dio.post<Map<String, dynamic>>('/shop/purchase', data: {
      // `fattah.single` from the mock catalogue.
      'itemId': '20000000-0000-4000-8000-000000000003',
      'idempotencyKey': 'mock-fattah-purchase',
    });

    final after = await dio.get<Map<String, dynamic>>('/fattah/balance');
    expect(after.data?['balance'], initial + 1);
    final profile = await dio.get<Map<String, dynamic>>('/users/me');
    expect(profile.data?['fattahBalance'], initial + 1);
  });
}
