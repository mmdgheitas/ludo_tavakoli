import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/config/app_config.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

final matchmakingProvider = StateNotifierProvider.autoDispose<MatchmakingController, MatchmakingState>((ref) {
  final controller = MatchmakingController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

enum MatchmakingStatus { idle, connecting, searching, found, error }

class MatchmakingState {
  const MatchmakingState(this.status, this.message, {this.gameId});
  final MatchmakingStatus status;
  final String message;
  final String? gameId;
}

class MatchmakingController extends StateNotifier<MatchmakingState> {
  MatchmakingController(this._ref) : super(const MatchmakingState(MatchmakingStatus.idle, 'آماده جست‌وجو'));
  final Ref _ref;
  io.Socket? _socket;
  String _mode = 'ONLINE_2P';

  Future<void> join({String mode = 'ONLINE_2P'}) async {
    _mode = mode;
    state = const MatchmakingState(MatchmakingStatus.connecting, 'در حال اتصال امن…');
    final token = await _ref.read(secureStorageProvider).read(key: 'access_token');
    if (token == null) {
      state = const MatchmakingState(MatchmakingStatus.error, 'برای بازی آنلاین دوباره وارد شوید');
      return;
    }
    _socket = io.io(AppConfig.socketBaseUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .disableAutoConnect()
      .enableReconnection()
      .setReconnectionAttempts(8)
      .build());

    _socket!
      ..onConnect((_) {
        state = const MatchmakingState(MatchmakingStatus.searching, 'در حال پیدا کردن حریف…');
        _socket!.emit('matchmaking:join', {'mode': _mode});
      })
      ..on('matchmaking:matched', (data) {
        final value = Map<String, dynamic>.from(data as Map);
        state = MatchmakingState(MatchmakingStatus.found, 'حریف پیدا شد!', gameId: value['gameId'] as String?);
      })
      ..onConnectError((_) => state = const MatchmakingState(MatchmakingStatus.error, 'اتصال برقرار نشد'))
      ..onError((_) => state = const MatchmakingState(MatchmakingStatus.error, 'خطایی رخ داد؛ دوباره تلاش کنید'))
      ..connect();
  }

  void cancel() {
    _socket?.emit('matchmaking:leave');
    _socket?.disconnect();
    state = const MatchmakingState(MatchmakingStatus.idle, 'جست‌وجو متوقف شد');
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
