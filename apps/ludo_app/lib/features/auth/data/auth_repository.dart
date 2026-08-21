import 'package:ludo_app/core/network/api_client.dart';
import 'package:ludo_app/features/auth/domain/user_profile.dart';
import 'package:uuid/uuid.dart';

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  Future<UserProfile> register({required String username, required String email, required String password}) async {
    final response = await _client.dio.post<Map<String, dynamic>>('/auth/register', data: {
      'username': username.trim(), 'email': email.trim().toLowerCase(), 'password': password,
    });
    return _saveAuthResponse(response.data!);
  }

  Future<UserProfile> login({required String identifier, required String password}) async {
    final response = await _client.dio.post<Map<String, dynamic>>('/auth/login', data: {
      'identifier': identifier.trim(), 'password': password,
    });
    return _saveAuthResponse(response.data!);
  }

  Future<void> forgotPassword(String identifier) =>
      _client.dio.post<void>('/auth/password/forgot', data: {'identifier': identifier.trim()});

  Future<void> resetPassword({required String identifier, required String code, required String newPassword}) =>
      _client.dio.post<void>('/auth/password/reset', data: {
        'identifier': identifier.trim(), 'code': code.trim(), 'newPassword': newPassword,
      });

  Future<UserProfile> createGuest({String? displayName}) async {
    const uuid = Uuid();
    final response = await _client.dio.post<Map<String, dynamic>>('/auth/guest', data: {
      'displayName': displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      'deviceId': uuid.v4(),
    });
    return _saveAuthResponse(response.data!);
  }

  Future<UserProfile?> me() async {
    final response = await _client.dio.get<Map<String, dynamic>>('/users/me');
    return UserProfile.fromJson(response.data!);
  }

  Future<void> heartbeat() => _client.dio.post<void>('/auth/session/heartbeat');

  Future<List<Map<String, dynamic>>> sessions() async {
    final response = await _client.dio.get<List<dynamic>>('/auth/sessions');
    return (response.data ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> revokeSession(String id) => _client.dio.delete<void>('/auth/sessions/$id');

  Future<void> logout() async {
    try { await _client.dio.post<void>('/auth/logout'); }
    finally { await _client.clearTokens(); }
  }

  Future<UserProfile> _saveAuthResponse(Map<String, dynamic> data) async {
    await _client.saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }
}
