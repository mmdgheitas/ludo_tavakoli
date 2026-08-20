import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/config/app_config.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ActiveOnlineGame {
  const ActiveOnlineGame({required this.id, required this.playerCount, required this.status, this.roomCode});
  final String id;
  final int playerCount;
  final String status;
  final String? roomCode;

  factory ActiveOnlineGame.fromJson(Map<String, dynamic> json) => ActiveOnlineGame(
        id: json['id'] as String,
        playerCount: json['mode'] == 'ONLINE_4P' ? 4 : 2,
        status: json['status'] as String,
        roomCode: json['roomCode'] as String?,
      );
}

final activeOnlineGamesProvider = FutureProvider<List<ActiveOnlineGame>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get<List<dynamic>>('/games/active/me');
  return (response.data ?? const [])
      .map((item) => ActiveOnlineGame.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
});

final matchmakingProvider = StateNotifierProvider.autoDispose<MatchmakingController, MatchmakingState>(
  (ref) => MatchmakingController(ref),
);

enum MatchmakingStatus { idle, connecting, searching, found, error }

class MatchmakingState {
  const MatchmakingState(this.status, this.message, {this.gameId, this.playerCount});
  final MatchmakingStatus status;
  final String message;
  final String? gameId;
  final int? playerCount;
}

class MatchmakingController extends StateNotifier<MatchmakingState> {
  MatchmakingController(this._ref) : super(const MatchmakingState(MatchmakingStatus.idle, 'آماده جست‌وجو'));
  final Ref _ref;
  io.Socket? _socket;
  String _mode = 'ONLINE_2P';

  Future<void> join({String mode = 'ONLINE_2P'}) async {
    _mode = mode;
    _socket?.dispose();
    state = const MatchmakingState(MatchmakingStatus.connecting, 'در حال اتصال امن…');
    try {
      await _ref.read(authRepositoryProvider).me();
    } catch (_) {
      state = const MatchmakingState(MatchmakingStatus.error, 'نشست شما منقضی شده؛ دوباره وارد شوید');
      return;
    }
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
        state = MatchmakingState(
          MatchmakingStatus.found,
          'بازیکنان پیدا شدند؛ در حال ورود…',
          gameId: value['gameId'] as String?,
          playerCount: (value['playerCount'] as num?)?.toInt(),
        );
      })
      ..on('matchmaking:error', (data) {
        final value = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
        state = MatchmakingState(MatchmakingStatus.error, value['message']?.toString() ?? 'ساخت مسابقه انجام نشد');
      })
      ..onConnectError((_) => state = const MatchmakingState(MatchmakingStatus.error, 'اتصال برقرار نشد'))
      ..onError((_) => state = const MatchmakingState(MatchmakingStatus.error, 'خطایی رخ داد؛ دوباره تلاش کنید'))
      ..connect();
  }

  void cancel({bool resetState = true}) {
    _socket?.emit('matchmaking:leave');
    _socket?.dispose();
    _socket = null;
    if (resetState) state = const MatchmakingState(MatchmakingStatus.idle, 'جست‌وجو متوقف شد');
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
