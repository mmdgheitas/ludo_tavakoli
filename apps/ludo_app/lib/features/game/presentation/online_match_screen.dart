import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/config/app_config.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/chat/data/quick_chat_repository.dart';
import 'package:ludo_app/features/game/data/offline_session_adapter.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/game_engine/ludo_game.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_command_sink.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class OnlineMatchScreen extends ConsumerStatefulWidget {
  const OnlineMatchScreen({super.key, required this.gameId, this.playerCount = 2});
  final String gameId;
  final int playerCount;

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
  Timer? _clock;
  Timer? _chatTimer;
  bool _ready = false;
  String _connectionLabel = 'در حال اتصال…';
  String _phase = 'WAITING_PLAYERS';
  DateTime? _deadline;
  List<Map<String, dynamic>> _players = const [];
  String? _chatText;

  @override
  void initState() {
    super.initState();
    _commandSink = _OnlineCommandSink(
      onRoll: () => _socket?.emit('game:roll', {'gameId': widget.gameId}),
      onMove: (tokenId) {
        final number = int.tryParse(tokenId.substring(tokenId.length - 1)) ?? 1;
        _socket?.emit('game:move', {'gameId': widget.gameId, 'tokenIndex': number - 1});
      },
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_phase == 'WAITING_PLAYERS' && timer.tick % 3 == 0) _socket?.emit('game:subscribe', {'gameId': widget.gameId});
    });
    unawaited(_connect());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final teams = widget.playerCount == 4 ? PlayerTeam.values : const [PlayerTeam.blue, PlayerTeam.red];
    _game ??= Ludo(
      teams,
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
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).enableReconnection().setReconnectionAttempts(10).disableAutoConnect().build(),
    );
    _socket = socket;
    socket
      ..onConnect((_) {
        if (mounted) setState(() => _connectionLabel = 'آنلاین');
        socket.emit('game:subscribe', {'gameId': widget.gameId});
      })
      ..onDisconnect((_) { if (mounted) setState(() => _connectionLabel = 'در حال اتصال دوباره…'); })
      ..onConnectError((_) { if (mounted) setState(() => _connectionLabel = 'خطا در اتصال'); })
      ..on('game:state', _handleState)
      ..on('chat:message', _handleChat)
      ..on('game:error', (data) {
        if (!mounted) return;
        final message = data is Map ? data['message']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'فرمان بازی پذیرفته نشد.')));
      })
      ..connect();
  }

  void _handleChat(dynamic data) {
    if (data is! Map || !mounted) return;
    final message = Map<String, dynamic>.from(data);
    _chatTimer?.cancel();
    setState(() => _chatText = '${message['emoji'] ?? ''} ${message['textFa'] ?? ''}'.trim());
    _chatTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _chatText = null); });
  }

  void _handleState(dynamic payload) {
    if (payload is! Map) return;
    final outer = Map<String, dynamic>.from(payload);
    final rawState = outer['state'] is Map ? Map<String, dynamic>.from(outer['state'] as Map) : outer;
    final playersRaw = rawState['players'];
    if (playersRaw is! List) return;
    final players = playersRaw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final teams = players.map((player) => Team.values.byName((player['team'] as String).toLowerCase())).toList();
    final phase = switch (rawState['phase']) { 'WAITING_MOVE' => MatchPhase.waitingForMove, 'FINISHED' => MatchPhase.finished, _ => MatchPhase.waitingForRoll };
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
            TokenSnapshot(id: '${(player['team'] as String).substring(0, 1)}T${index + 1}', team: Team.values.byName((player['team'] as String).toLowerCase()), progress: ((player['tokens'] as List)[index] as num).toInt()),
      ],
    );
    if (_latest != null && snapshot.version <= _latest!.version) return;
    _latest = snapshot;
    _players = players;
    _phase = rawState['phase']?.toString() ?? 'WAITING_PLAYERS';
    _deadline = DateTime.tryParse(rawState['turnDeadlineAt']?.toString() ?? '');
    if (_ready && _game != null && _phase != 'WAITING_PLAYERS') _animationQueue = _animationQueue.then((_) => _adapter.restore(_game!, snapshot));
    if (mounted) setState(() {});
  }

  int get secondsLeft {
    if (_deadline == null) return 0;
    final seconds = _deadline!.difference(DateTime.now().toUtc()).inSeconds;
    return seconds.clamp(0, 999).toInt();
  }

  Future<void> _showQuickChat() async {
    try {
      final options = await ref.read(quickChatOptionsProvider.future);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: options.map((option) => ActionChip(label: Text('${option.emoji ?? ''} ${option.text}'.trim()), onPressed: () { _socket?.emit('chat:send', {'gameId': widget.gameId, 'messageId': option.id}); Navigator.pop(sheetContext); })).toList(),
          ),
        ),
      );
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پیام‌ها دریافت نشدند.'))); }
  }

  Future<void> _confirmForfeit() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('ترک مسابقه؟'), content: const Text('با خروج، نتیجه به سود بازیکنان باقی‌مانده ثبت می‌شود.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسلیم می‌شوم'))])) ?? false;
    if (accepted) _socket?.emit('game:forfeit', {'gameId': widget.gameId});
  }

  @override
  void dispose() {
    _clock?.cancel(); _chatTimer?.cancel(); _socket?.dispose();
    if (GameState().commandSink == _commandSink) GameState().commandSink = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disconnected = _players.where((player) => player['connected'] == false && player['forfeited'] != true).length;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        title: Text(widget.playerCount == 4 ? 'مسابقه آنلاین ۴ نفره' : 'مسابقه آنلاین'),
        actions: [
          IconButton(onPressed: _showQuickChat, icon: const Icon(Icons.chat_bubble_outline_rounded)),
          PopupMenuButton<String>(onSelected: (value) { if (value == 'forfeit') _confirmForfeit(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'forfeit', child: Text('تسلیم و خروج'))]),
        ],
      ),
      body: Stack(children: [
        SafeArea(child: GameWidget(game: _game!)),
        Positioned(top: 8, left: 12, right: 12, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Chip(label: Text(_connectionLabel), avatar: Icon(_connectionLabel == 'آنلاین' ? Icons.cloud_done : Icons.cloud_off, size: 16)),
          if (_phase != 'WAITING_PLAYERS' && _phase != 'FINISHED') Chip(label: Text('$secondsLeft ثانیه'), avatar: const Icon(Icons.timer_outlined, size: 16)),
        ])),
        if (_phase == 'WAITING_PLAYERS') Positioned.fill(child: ColoredBox(color: const Color(0xCC151124), child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text('در انتظار تکمیل اتاق (${_players.length}/${widget.playerCount})', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('کد دعوت را برای دوستان بفرستید', style: TextStyle(color: AppColors.muted))])))))),
        if (disconnected > 0) Positioned(bottom: 18, left: 18, right: 18, child: Material(color: AppColors.coral, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.all(12), child: Text('$disconnected بازیکن قطع شده؛ ۶۰ ثانیه برای بازگشت فرصت دارد.', textAlign: TextAlign.center)))),
        if (_chatText != null) Positioned(top: 75, left: 30, right: 30, child: Center(child: Material(color: AppColors.ink, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: Text(_chatText!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))))),
        if (_latest?.phase == MatchPhase.finished) Positioned.fill(child: ColoredBox(color: const Color(0xAA151124), child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.emoji_events_rounded, size: 55, color: AppColors.gold), const SizedBox(height: 12), const Text('مسابقه به پایان رسید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 18), FilledButton(onPressed: () => Navigator.pop(context), child: const Text('بازگشت به خانه'))])))))),
      ]),
    );
  }
}

class _OnlineCommandSink implements GameCommandSink {
  const _OnlineCommandSink({required this.onRoll, required this.onMove});
  final VoidCallback onRoll;
  final ValueChanged<String> onMove;
  @override void move(String tokenId) => onMove(tokenId);
  @override void roll() => onRoll();
}
