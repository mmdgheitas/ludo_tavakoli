import 'package:manche_irani/core/network/api_client.dart';
import 'package:manche_irani/features/auth/domain/user_profile.dart';
import 'package:uuid/uuid.dart';

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  Future<UserProfile> createGuest({String? displayName}) async {
    const uuid = Uuid();
    final response = await _client.dio.post<Map<String, dynamic>>('/auth/guest', data: {
      'displayName': displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      'deviceId': uuid.v4(),
    });
    final data = response.data!;
    await _client.saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserProfile?> me() async {
    final response = await _client.dio.get<Map<String, dynamic>>('/users/me');
    return UserProfile.fromJson(response.data!);
  }

  Future<void> logout() async {
    try {
      await _client.dio.post<void>('/auth/logout');
    } finally {
      await _client.clearTokens();
    }
  }
}
