import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:manche_irani/core/network/api_client.dart';
import 'package:manche_irani/features/auth/data/auth_repository.dart';
import 'package:manche_irani/features/auth/domain/user_profile.dart';

final secureStorageProvider = Provider((_) => const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
));

final apiClientProvider = Provider((ref) => ApiClient(ref.watch(secureStorageProvider)));
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));

final currentUserProvider = StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  AuthController(this._repository) : super(const AsyncValue.loading()) {
    restore();
  }

  final AuthRepository _repository;

  Future<void> restore() async {
    try {
      state = AsyncValue.data(await _repository.me());
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> enter({String? displayName}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.createGuest(displayName: displayName));
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}
