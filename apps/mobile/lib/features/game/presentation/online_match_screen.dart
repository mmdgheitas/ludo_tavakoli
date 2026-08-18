import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manche_irani/core/config/app_config.dart';
import 'package:manche_irani/core/providers.dart';
import 'package:manche_irani/core/theme/app_theme.dart';
import 'package:manche_irani/features/game/data/offline_session_adapter.dart';
import 'package:manche_irani/features/game/domain/game_snapshot.dart';
import 'package:manche_irani/features/game/game_engine/ludo_game.dart';
import 'package:manche_irani/features/game/game_engine/managers/game_command_sink.dart';
import 'package:manche_irani/features/game/game_engine/managers/game_state.dart';
import 'package:manche_irani/features/game/game_engine/models/player_team.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class OnlineMatchScreen extends ConsumerStatefulWidget {
  const OnlineMatchScreen({super.key, required this.gameId});
  final String gameId;

  @override
  ConsumerState<OnlineMatchScreen> createState() => _OnlineMatchScreenState();
}

class _OnlineMatchScreenState extends ConsumerState<OnlineMatchScreen> {
  final _adapter = const OfflineSessionAdapter();
  late final GameCommandSink _commandSink;
  io.Socket? _socket;
  Ludo? _game;
  GameSnapshot? _latest;
  Future<void> _animationQueue = Future.value();
  bool _ready = false;
  String _connectionLabel = 'در حال اتصال…';

  @override
  void initState() {
    super.initState();
    _commandSink = _OnlineCommandSink(
      roll: () => _socket?.emit('game:roll', {'gameId': widget.gameId}),
      move: (tokenId) {
        final number = int.tryParse(tokenId.substring(tokenId.length - 1)) ?? 1;
        _socket?.emit('game:move', {'gameId': widget.gameId, 'tokenIndex': number - 1});
      },
    );
    unawaited(_connect());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game ??= Ludo(
      const [PlayerTeam.blue, PlayerTeam.red],
      context,
      commandSink: _commandSink,
      onReady: (game) async {
        _ready = true;
        if (_latest != null) await _adapter.restore(game, _latest!);
      },
    );
  }

  Future<void> _connect() async {
    final token = await ref.read(secureStorageProvider).read(key: 'access_token');
    if (token == null || !mounted) return;
    final socket = io.io(
      AppConfig.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    socket
      ..onConnect((_) {
        if (mounted) setState(() => _connectionLabel = 'آنلاین');
        socket.emit('game:subscribe', {'gameId': widget.gameId});
      })
      ..onDisconnect((_) {
        if (mounted) setState(() => _connectionLabel = 'در حال اتصال دوباره…');
      })
      ..onConnectError((_) {
        if (mounted) setState(() => _connectionLabel = 'خطا در اتصال');
      })
      ..on('game:state', _handleState)
      ..on('game:error', (data) {
        if (!mounted) return;
        final message = data is Map ? data['message']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'فرمان بازی پذیرفته نشد.')),
        );
      })
      ..connect();
  }

  void _handleState(dynamic payload) {
    if (payload is! Map) return;
    final outer = Map<String, dynamic>.from(payload);
    final rawState = outer['state'] is Map
        ? Map<String, dynamic>.from(outer['state'] as Map)
        : outer;
    final playersRaw = rawState['players'];
    if (playersRaw is! List) return;
    final players = playersRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final teams = players.map((player) => Team.values.byName((player['team'] as String).toLowerCase())).toList();
    final phase = switch (rawState['phase']) {
      'WAITING_MOVE' => MatchPhase.waitingForMove,
      'FINISHED' => MatchPhase.finished,
      _ => MatchPhase.waitingForRoll,
    };
    Team? winner;
    final winnerId = rawState['winnerId'];
    if (winnerId != null) {
      final winnerPlayer = players.where((player) => player['userId'] == winnerId).firstOrNull;
      if (winnerPlayer != null) winner = Team.values.byName((winnerPlayer['team'] as String).toLowerCase());
    }
    final snapshot = GameSnapshot(
      id: widget.gameId,
      version: (rawState['version'] as num?)?.toInt() ?? 0,
      teams: teams,
      currentTurn: (rawState['turnIndex'] as num?)?.toInt() ?? 0,
      phase: phase,
      pendingDice: (rawState['pendingRoll'] as num?)?.toInt() ?? (outer['dice'] as num?)?.toInt(),
      winner: winner,
      updatedAt: DateTime.tryParse(rawState['lastActionAt']?.toString() ?? '') ?? DateTime.now().toUtc(),
      tokens: [
        for (final player in players)
          for (var index = 0; index < (player['tokens'] as List).length; index++)
            TokenSnapshot(
              id: '${(player['team'] as String).substring(0, 1)}T${index + 1}',
              team: Team.values.byName((player['team'] as String).toLowerCase()),
              progress: ((player['tokens'] as List)[index] as num).toInt(),
            ),
      ],
    );
    if (_latest != null && snapshot.version <= _latest!.version) return;
    _latest = snapshot;
    if (_ready && _game != null) {
      _animationQueue = _animationQueue.then((_) => _adapter.restore(_game!, snapshot));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _socket?.dispose();
    if (GameState().commandSink == _commandSink) GameState().commandSink = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.ink,
          title: const Text('مسابقه آنلاین', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: Center(
                child: Text(
                  _connectionLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.turquoise),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(child: GameWidget(game: _game!)),
            if (_latest?.phase == MatchPhase.finished)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xAA151124),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 55, color: AppColors.gold),
                            const SizedBox(height: 12),
                            const Text('مسابقه به پایان رسید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 18),
                            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('بازگشت به خانه')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _OnlineCommandSink implements GameCommandSink {
  const _OnlineCommandSink({ roll,  move});

  @override
  void move(String tokenId) {
    // TODO: implement move
  }

  @override
  void roll() {
    // TODO: implement roll
  }

  

}
