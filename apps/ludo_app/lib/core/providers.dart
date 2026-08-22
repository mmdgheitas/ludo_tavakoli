import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ludo_app/core/network/api_client.dart';
import 'package:ludo_app/features/auth/data/auth_repository.dart';
import 'package:ludo_app/features/auth/domain/user_profile.dart';

final secureStorageProvider = Provider((_) => const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
));

final apiClientProvider = Provider((ref) => ApiClient(ref.watch(secureStorageProvider)));
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));

final currentUserProvider = StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  AuthController(this._repository) : super(const AsyncValue.loading()) { unawaited(restore()); }
  final AuthRepository _repository;
  Timer? _heartbeat;

  Future<void> restore() async {
    try {
      final user = await _repository.me();
      state = AsyncValue.data(user);
      if (user != null) _startHeartbeat();
    } catch (_) {
      state = const AsyncValue.data(null);
      _heartbeat?.cancel();
    }
  }

  Future<void> login({required String identifier, required String password}) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.login(identifier: identifier, password: password));
    state = result;
    if (result is AsyncData<UserProfile?> && result.value != null) _startHeartbeat();
  }

  Future<void> register({required String username, required String email, required String password}) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.register(username: username, email: email, password: password));
    state = result;
    if (result is AsyncData<UserProfile?> && result.value != null) _startHeartbeat();
  }

  Future<void> enter({String? displayName}) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.createGuest(displayName: displayName));
    state = result;
    if (result is AsyncData<UserProfile?> && result.value != null) _startHeartbeat();
  }

  Future<void> logout() async {
    _heartbeat?.cancel();
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    unawaited(_repository.heartbeat().catchError((_) {}));
    _heartbeat = Timer.periodic(const Duration(minutes: 4), (_) {
      unawaited(_repository.heartbeat().catchError((_) {}));
    });
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }
}
