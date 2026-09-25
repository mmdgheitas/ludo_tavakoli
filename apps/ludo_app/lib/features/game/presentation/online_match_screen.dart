import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/config/app_config.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/chat/data/quick_chat_repository.dart';
import 'package:ludo_app/features/game/data/online_game_repository.dart';
import 'package:ludo_app/features/game/data/online_session_adapter.dart';
import 'package:ludo_app/features/game/domain/fattah.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/domain/ludo_rules.dart';
import 'package:ludo_app/features/game/game_engine/ludo_game.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_command_sink.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';
import 'package:ludo_app/features/shop/presentation/shop_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class OnlineMatchScreen extends ConsumerStatefulWidget {
  const OnlineMatchScreen({super.key, required this.gameId, this.playerCount = 2});
  final String gameId;
  final int playerCount;

  @override
  ConsumerState<OnlineMatchScreen> createState() => _OnlineMatchScreenState();
}

class _OnlineMatchScreenState extends ConsumerState<OnlineMatchScreen> {
  static const _teamNamesFa = {
    Team.blue: 'آبی',
    Team.red: 'قرمز',
    Team.green: 'سبز',
    Team.yellow: 'زرد',
  };
  static const _teamColors = {
    Team.blue: Color(0xFF0D92F4),
    Team.red: Color(0xFFFF5B5B),
    Team.green: Color(0xFF41B06E),
    Team.yellow: Color(0xFFFFD966),
  };

  final _adapter = const OnlineSessionAdapter();
  late final GameCommandSink _commandSink;
  io.Socket? _socket;
  Ludo? _game;
  GameSnapshot? _latest;
  GameSnapshot? _pendingSnapshot;
  bool _syncingSnapshot = false;
  int? _appliedVersion;
  int? _autoMoveVersion;
  final Set<int> _manualMoveVersions = <int>{};
  DateTime? _holdSnapshotsUntil;
  Timer? _clock;
  Timer? _chatTimer;
  bool _ready = false;
  String _connectionLabel = 'در حال اتصال…';
  String _phase = 'WAITING_PLAYERS';
  DateTime? _deadline;
  List<Map<String, dynamic>> _players = const [];
  String? _chatText;
  String? _myUserId;
  String? _winnerId;
  int _turnIndex = 0;
  bool _commandPending = false;
  Timer? _commandTimer;
  Timer? _diceTimer;
  Timer? _sessionRenewal;
  int? _lastDice;
  String? _socketToken;
  bool _renewingToken = false;
  DateTime? _lastTokenRefreshAt;
  // Fattah inventory is server-owned. It is read once per match and spent
  // locally only when the server confirms the strike in a broadcast snapshot.
  int _fattahBalance = 0;
  int _fattahMaxPerGame = 1;
  String? _fattahBanner;
  Timer? _fattahBannerTimer;
  FattahStrike? _pendingStrike;

  @override
  void initState() {
    super.initState();
    _commandSink = _OnlineCommandSink(
      onRoll: _requestRoll,
      onMove: _requestMove,
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_phase == 'WAITING_PLAYERS' && timer.tick % 3 == 0) _socket?.emit('game:subscribe', {'gameId': widget.gameId});
    });
    unawaited(_connect());
  }

  bool get _isMyTurn => _players.isNotEmpty &&
      _turnIndex >= 0 &&
      _turnIndex < _players.length &&
      _players[_turnIndex]['userId'] == _myUserId &&
      _players[_turnIndex]['forfeited'] != true;

  Map<String, dynamic>? get _myPlayer =>
      _players.where((player) => player['userId'] == _myUserId).firstOrNull;

  static const _fattahRules = FattahRules();

  bool get _fattahUsedThisGame => _myPlayer?['fattahUsed'] == true;

  /// The launcher is offered whenever this player could legally fire in this
  /// game, so an empty inventory is visible instead of failing silently.
  bool get _fattahVisible => _fattahRules.isLauncherVisible(
        phase: _phase,
        myTurn: _isMyTurn,
        usedThisGame: _fattahUsedThisGame,
      );

  bool get _fattahEnabled => _fattahRules.canFire(
        phase: _phase,
        myTurn: _isMyTurn,
        usedThisGame: _fattahUsedThisGame,
        balance: _fattahBalance,
      );

  void _requestRoll() {
    if (!_isMyTurn || _phase != 'WAITING_ROLL') return;
    _sendCommand('game:roll', {'gameId': widget.gameId});
  }

  void _requestMove(String tokenId) {
    if (!_isMyTurn || _phase != 'WAITING_MOVE') return;
    final number = int.tryParse(tokenId.substring(tokenId.length - 1));
    if (number == null || number < 1 || number > 4) return;
    final version = _latest?.version;
    if (version != null) _manualMoveVersions.add(version);
    _sendCommand('game:move', {'gameId': widget.gameId, 'tokenIndex': number - 1});
  }

  /// Sends one intent. Returns false — with a Persian explanation — when the
  /// command could not leave the device, so an interaction is never swallowed.
  bool _sendCommand(String event, Map<String, dynamic> payload) {
    final socket = _socket;
    if (_commandPending) {
      _toast('یک فرمان در حال ارسال است؛ چند لحظه صبر کنید.');
      return false;
    }
    if (socket == null || !socket.connected) {
      _toast('اتصال برقرار نیست؛ دوباره تلاش کنید.');
      return false;
    }
    setState(() => _commandPending = true);
    socket.emit(event, payload);
    _commandTimer?.cancel();
    _commandTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _commandPending = false);
    });
    return true;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _unlockCommands() {
    _commandTimer?.cancel();
    if (mounted && _commandPending) setState(() => _commandPending = false);
  }

  void _scheduleSnapshot(GameSnapshot snapshot, {FattahStrike? strike}) {
    _pendingSnapshot = snapshot;
    // A superseding snapshot drops the pending rocket: the struck piece is
    // already home in the newer state, and the banner has been shown anyway.
    _pendingStrike = strike;
    if (!_syncingSnapshot) unawaited(_drainSnapshots());
  }

  Future<void> _drainSnapshots() async {
    _syncingSnapshot = true;
    try {
      while (mounted && _pendingSnapshot != null && _game != null) {
        final snapshot = _pendingSnapshot!;
        final strike = _pendingStrike;
        _pendingSnapshot = null;
        _pendingStrike = null;
        final hold = _holdSnapshotsUntil;
        if (hold != null) {
          final wait = hold.difference(DateTime.now());
          if (wait > Duration.zero) await Future<void>.delayed(wait);
          _holdSnapshotsUntil = null;
        }
        try {
          // Only a consecutive version plays the offline-style movement
          // animation; gaps (initial sync, reconnects) fast-forward so
          // animation backlogs can never accumulate.
          final animate = _appliedVersion != null && snapshot.version == _appliedVersion! + 1;
          await _adapter.apply(_game!, snapshot, myTurn: _isMyTurn, animate: animate, strike: strike);
          _appliedVersion = snapshot.version;
          unawaited(_maybeAutoMove(snapshot));
        } catch (_) {
          // A failed animation must never poison later authoritative updates.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('همگام‌سازی نمایش انجام نشد؛ در حال تلاش مجدد…')),
            );
          }
        }
      }
    } finally {
      _syncingSnapshot = false;
      final pending = _pendingSnapshot;
      if (mounted && pending != null) _scheduleSnapshot(pending, strike: _pendingStrike);
    }
  }

  /// Offline parity: when the dice leaves exactly one legal token, the board
  /// plays that move without asking — same as a pass-and-play game.
  Future<void> _maybeAutoMove(GameSnapshot snapshot) async {
    if (_autoMoveVersion == snapshot.version) return;
    _autoMoveVersion = snapshot.version;
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted || !_isMyTurn || _phase != 'WAITING_MOVE' || _commandPending) return;
    if (_latest == null || _latest!.version != snapshot.version) return;
    if (_manualMoveVersions.contains(snapshot.version)) return;
    final legal = const LudoRules().legalTokenIds(snapshot);
    if (legal.length != 1) return;
    _requestMove(legal.first);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seat layout matches the server: 2P sits on the diagonal (blue/green,
    // exactly like offline games); 4P uses all four corners.
    final teams = widget.playerCount == 4
        ? const [PlayerTeam.blue, PlayerTeam.red, PlayerTeam.green, PlayerTeam.yellow]
        : const [PlayerTeam.blue, PlayerTeam.green];
    _game ??= Ludo(
      teams,
      context,
      commandSink: _commandSink,
      onReady: (_) {
        _ready = true;
        if (_latest != null && _phase != 'WAITING_PLAYERS') _scheduleSnapshot(_latest!);
        return Future.value();
      },
    );
  }

  Future<void> _renewSocketToken({bool reconnect = false}) async {
    if (_renewingToken || !mounted) return;
    _renewingToken = true;
    try {
      final client = ref.read(apiClientProvider);
      await client.refreshTokens();
      _socketToken = await client.readAccessToken();
      _lastTokenRefreshAt = DateTime.now();
      final socket = _socket;
      if (socket != null && _socketToken != null) {
        socket.auth = {'token': _socketToken};
        if (reconnect && !socket.connected) {
          socket.disconnect();
          socket.connect();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _connectionLabel = 'نشست منقضی شده است');
    } finally {
      _renewingToken = false;
    }
  }

  Future<void> _connect() async {
    _myUserId = ref.read(currentUserProvider).value?.id;
    int? profileRockets = ref.read(currentUserProvider).value?.fattahBalance;
    try {
      final profile = await ref.read(authRepositoryProvider).me();
      _myUserId = profile?.id ?? _myUserId;
      profileRockets = profile?.fattahBalance ?? profileRockets;
    } catch (_) {
      if (mounted) setState(() => _connectionLabel = 'ورود دوباره لازم است');
      return;
    }
    unawaited(_loadFattahBalance(profileRockets));
    final token = await ref.read(secureStorageProvider).read(key: 'access_token');
    if (token == null || !mounted) return;
    _socketToken = token;
    _lastTokenRefreshAt = DateTime.now();
    _sessionRenewal ??= Timer.periodic(
      const Duration(minutes: 9),
      (_) => unawaited(_renewSocketToken()),
    );
    final socket = io.io(
      AppConfig.socketBaseUrl,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).enableReconnection().setReconnectionAttempts(10).disableAutoConnect().build(),
    );
    _socket = socket;
    socket.io.on('reconnect_attempt', (_) {
      if (_socketToken != null) socket.auth = {'token': _socketToken};
    });
    socket
      ..onConnect((_) {
        if (mounted) setState(() => _connectionLabel = 'آنلاین');
        socket.emit('game:subscribe', {'gameId': widget.gameId});
      })
      ..onDisconnect((_) {
        _unlockCommands();
        if (mounted) setState(() => _connectionLabel = 'در حال اتصال دوباره…');
      })
      ..onConnectError((_) {
        _unlockCommands();
        final lastRefresh = _lastTokenRefreshAt;
        if (lastRefresh == null || DateTime.now().difference(lastRefresh) >= const Duration(minutes: 8)) {
          unawaited(_renewSocketToken(reconnect: true));
        }
        if (mounted) setState(() => _connectionLabel = 'خطا در اتصال');
      })
      ..on('game:state', _handleState)
      ..on('game:ack', (_) => _unlockCommands())
      ..on('chat:message', _handleChat)
      ..on('game:error', _handleSocketError)
      ..on('exception', _handleSocketError)
      ..connect();
  }

  /// Reads the rocket inventory once per match. The cached profile is only a
  /// fallback: `GET /fattah/balance` is the documented source, and the server
  /// stays authoritative when the shot is actually spent.
  Future<void> _loadFattahBalance(int? fallback) async {
    var balance = fallback ?? 0;
    var maxPerGame = 1;
    try {
      final response = await ref.read(apiClientProvider).dio.get<Map<String, dynamic>>('/fattah/balance');
      final data = response.data;
      if (data != null) {
        balance = (data['balance'] as num?)?.toInt() ?? balance;
        maxPerGame = (data['maxUsagePerGame'] as num?)?.toInt() ?? maxPerGame;
      }
    } catch (_) {
      // A failed lookup only affects the badge; firing still fails closed.
    }
    if (!mounted) return;
    setState(() {
      _fattahBalance = balance;
      _fattahMaxPerGame = maxPerGame;
    });
  }

  void _handleSocketError(dynamic data) {
    _unlockCommands();
    if (!mounted) return;
    final message = data is Map ? data['message']?.toString() : data?.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_errorText(message))),
    );
  }

  static const _errorTranslations = <String, String>{
    'NOT_YOUR_TURN': 'الان نوبت شما نیست',
    'ROLL_NOT_ALLOWED': 'فعلاً نمی‌توانید تاس بیندازید',
    'MOVE_NOT_ALLOWED': 'اول تاس بیندازید',
    'ILLEGAL_MOVE': 'این مهره نمی‌تواند این حرکت را بکند',
    'INVALID_TOKEN': 'مهره انتخابی نامعتبر است',
    'FATTAH_ALREADY_USED': 'فتاح این بازی قبلاً استفاده شده است',
    'INVALID_TARGET': 'هدف فتاح نامعتبر است',
    'Fattah inventory is empty': 'موجودی فتاح شما تمام شده است',
    'GAME_FINISHED': 'این مسابقه تمام شده است',
    'GAME_NOT_READY': 'مسابقه هنوز شروع نشده است',
    'INTERNAL_ERROR': 'خطای داخلی سرور؛ لطفاً دوباره تلاش کنید',
  };

  String _errorText(String? raw) {
    final message = raw?.trim() ?? '';
    if (message.isEmpty) return 'فرمان بازی پذیرفته نشد.';
    for (final entry in _errorTranslations.entries) {
      if (message.contains(entry.key)) return entry.value;
    }
    return message;
  }

  void _handleChat(dynamic data) {
    if (data is! Map || !mounted) return;
    final message = Map<String, dynamic>.from(data);
    _chatTimer?.cancel();
    setState(() => _chatText = '${message['emoji'] ?? ''} ${message['textFa'] ?? ''}'.trim());
    _chatTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _chatText = null); });
  }

  void _showReason(String? reason) {
    if (!mounted) return;
    const messages = {
      'TURN_TIMEOUT': 'یک نوبت با پایان زمان به بازیکن بعد رسید',
      'FORFEIT': 'یک بازیکن مسابقه را ترک کرد',
      'DISCONNECTED': 'بازیکن قطع‌شده از مسابقه حذف شد',
    };
    final text = messages[reason];
    if (text == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  void _handleState(dynamic payload) {
    if (payload is! Map) return;
    _unlockCommands();
    final outer = Map<String, dynamic>.from(payload);
    final rawState = outer['state'] is Map ? Map<String, dynamic>.from(outer['state'] as Map) : outer;
    final playersRaw = rawState['players'];
    if (playersRaw is! List || playersRaw.isEmpty) return;
    final players = <Map<String, dynamic>>[];
    for (final item in playersRaw) {
      if (item is! Map) return;
      final player = Map<String, dynamic>.from(item);
      if (player['team'] is! String || player['tokens'] is! List) return;
      players.add(player);
    }
    final version = (rawState['version'] as num?)?.toInt() ?? 0;
    if (_latest != null && version <= _latest!.version) return;

    final teams = players.map((player) => Team.values.byName((player['team'] as String).toLowerCase())).toList();
    final phase = switch (rawState['phase']) { 'WAITING_MOVE' => MatchPhase.waitingForMove, 'FINISHED' => MatchPhase.finished, _ => MatchPhase.waitingForRoll };
    Team? winner;
    final winnerId = rawState['winnerId']?.toString();
    if (winnerId != null) {
      final winnerPlayer = players.where((player) => player['userId'] == winnerId).firstOrNull;
      if (winnerPlayer != null) winner = Team.values.byName((winnerPlayer['team'] as String).toLowerCase());
    }

    // The server dice roll is animated exactly like an offline roll, and the
    // resulting movement is held briefly so the dice lands before tokens hop.
    final rolledDice = (outer['dice'] as num?)?.toInt();
    if (rolledDice != null) {
      _lastDice = rolledDice;
      _holdSnapshotsUntil = DateTime.now().add(const Duration(milliseconds: 340));
      if (_ready) _game?.animateDiceValue(rolledDice);
      _diceTimer?.cancel();
      _diceTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _lastDice = null);
      });
    }

    final snapshot = GameSnapshot(
      id: widget.gameId,
      version: version,
      teams: teams,
      currentTurn: (rawState['turnIndex'] as num?)?.toInt() ?? 0,
      phase: phase,
      pendingDice: (rawState['pendingRoll'] as num?)?.toInt(),
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

    _latest = snapshot;
    _players = players;
    _turnIndex = (rawState['turnIndex'] as num?)?.toInt() ?? 0;
    _phase = rawState['phase']?.toString() ?? 'WAITING_PLAYERS';
    _deadline = DateTime.tryParse(rawState['turnDeadlineAt']?.toString() ?? '');
    _winnerId = winnerId;
    _showReason(outer['reason']?.toString());
    final strike = _readFattahStrike(outer, players);
    if (_ready && _game != null && _phase != 'WAITING_PLAYERS') {
      _scheduleSnapshot(snapshot, strike: strike);
    }
    if (mounted) setState(() {});
  }

  /// Decodes the server's `fattah` marker, spends the local rocket when this
  /// device fired it, and announces the strike to every player. Without the
  /// marker a rocket hit is indistinguishable from an ordinary capture.
  FattahStrike? _readFattahStrike(Map<String, dynamic> result, List<Map<String, dynamic>> players) {
    final raw = result['fattah'];
    if (raw is! Map) return null;
    final payload = Map<String, dynamic>.from(raw);
    final String? actorId = payload['actorId']?.toString();
    final String? targetUserId = payload['targetUserId']?.toString();
    final targetIndex = (payload['targetTokenIndex'] as num?)?.toInt();
    if (actorId == null || targetUserId == null || targetIndex == null) return null;
    if (targetIndex < 0 || targetIndex > 3) return null;
    final attacker = players.where((player) => player['userId'] == actorId).firstOrNull;
    final victim = players.where((player) => player['userId'] == targetUserId).firstOrNull;
    final attackerTeam = attacker == null ? null : FattahRules.teamOf(attacker['team']);
    final targetTeam = victim == null ? null : FattahRules.teamOf(victim['team']);
    if (attackerTeam == null || targetTeam == null) return null;

    final isMine = actorId == _myUserId;
    if (isMine) {
      if (_fattahBalance > 0) _fattahBalance -= 1;
      // Keep the rocket count shown on the profile honest after spending one.
      unawaited(ref.read(currentUserProvider.notifier).restore());
    }
    _showBanner(_fattahBannerText(
      isMine: isMine,
      isVictim: targetUserId == _myUserId,
      targetTeam: targetTeam,
      targetIndex: targetIndex,
    ));
    return FattahStrike(
      attackerTeam: attackerTeam,
      targetTeam: targetTeam,
      targetTokenIndex: targetIndex,
    );
  }

  String _fattahBannerText({
    required bool isMine,
    required bool isVictim,
    required Team targetTeam,
    required int targetIndex,
  }) {
    final teamFa = _teamNamesFa[targetTeam] ?? '';
    if (isVictim) return '🚀 مهره ${targetIndex + 1} شما با موشک فتاح به خانه برگشت';
    if (isMine) return '🚀 موشک فتاح شلیک شد! مهره ${targetIndex + 1} تیم $teamFa به خانه برگشت';
    return '🚀 موشک فتاح! مهره ${targetIndex + 1} تیم $teamFa به خانه برگشت';
  }

  void _showBanner(String message) {
    _fattahBannerTimer?.cancel();
    _fattahBanner = message;
    _fattahBannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _fattahBanner = null);
    });
    if (mounted) setState(() {});
  }

  bool get _localPlayerForfeited => _players.any(
        (player) => player['userId'] == _myUserId && player['forfeited'] == true,
      );

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

  void _exitMatch() {
    ref.invalidate(activeOnlineGamesProvider);
    Navigator.pop(context);
  }

  Future<void> _confirmForfeit() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('ترک مسابقه؟'), content: const Text('با خروج، نتیجه به سود بازیکنان باقی‌مانده ثبت می‌شود.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسلیم می‌شوم'))])) ?? false;
    if (accepted) _sendCommand('game:forfeit', {'gameId': widget.gameId});
  }

  Future<void> _onFattahPressed() async {
    if (!_fattahEnabled) {
      await _showFattahShopPrompt();
      return;
    }
    if (_commandPending) {
      _toast('یک فرمان در حال ارسال است؛ چند لحظه صبر کنید.');
      return;
    }
    await _showFattahSheet();
  }

  /// An empty inventory is a shopping problem, not a dead button. The shop is
  /// pushed over the match, so the socket — and the seat — stay alive.
  Future<void> _showFattahShopPrompt() async {
    final goShop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('موشک فتاح ندارید'),
        content: const Text('موجودی فتاح شما صفر است. با خرید موشک می‌توانید در نوبت خود یک مهره حریف را به خانه بفرستید. فروشگاه روی مسابقه باز می‌شود و ساعت نوبت شما همچنان در جریان است.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('بستن')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text('خرید موشک'),
          ),
        ],
      ),
    ) ?? false;
    if (!goShop) return;
    if (!mounted) return;
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const ShopScreen()));
    if (!mounted) return;
    // A purchase may have landed while the shop was open; read the count again.
    await _loadFattahBalance(_fattahBalance);
  }

  Future<void> _showFattahSheet() async {
    final targets = _fattahRules.targets(_players, _myUserId);
    if (!mounted) return;
    if (targets.isEmpty) {
      _toast('هیچ مهره‌ای از حریفان روی زمین نیست.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('موشک فتاح — یک مهره حریف را انتخاب کنید', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'موجودی: $_fattahBalance موشک · حداکثر $_fattahMaxPerGame بار در هر مسابقه',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ]),
            ),
            Flexible(
              child: ListView(
                children: [
                  for (final target in targets)
                    ListTile(
                      leading: CircleAvatar(backgroundColor: _teamColors[target.team], radius: 14),
                      title: Text('تیم ${_teamNamesFa[target.team]} — مهره ${target.tokenIndex + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('خانه ${target.progress} از ۵۶'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(_fireFattah(target));
                      },
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Confirms the spend, re-validates against the freshest snapshot and fires.
  /// Spending a paid consumable must never be a silent or stale action.
  Future<void> _fireFattah(FattahTarget chosen) async {
    final target = _fattahRules.validate(_players, _myUserId, chosen.userId, chosen.tokenIndex);
    if (target == null) {
      _toast('این مهره دیگر روی زمین نیست.');
      return;
    }
    if (_commandPending) {
      _toast('یک فرمان در حال ارسال است؛ چند لحظه صبر کنید.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('شلیک موشک فتاح؟'),
        content: Text('مهره ${target.tokenIndex + 1} تیم ${_teamNamesFa[target.team]} به خانه برمی‌گردد. فتاح در هر مسابقه فقط یک بار قابل استفاده است.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.rocket_launch_rounded, size: 18),
            label: const Text('شلیک'),
          ),
        ],
      ),
    ) ?? false;
    if (!confirmed || !mounted) return;
    // Re-check after the dialog: the turn may have timed out while it was open.
    final fresh = _fattahRules.validate(_players, _myUserId, chosen.userId, chosen.tokenIndex);
    if (fresh == null || !_fattahEnabled) {
      _toast('این هدف دیگر در دسترس نیست.');
      return;
    }
    _sendCommand('game:fattah', {
      'gameId': widget.gameId,
      'targetUserId': fresh.userId,
      'targetTokenIndex': fresh.tokenIndex,
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _chatTimer?.cancel();
    _commandTimer?.cancel();
    _diceTimer?.cancel();
    _sessionRenewal?.cancel();
    _fattahBannerTimer?.cancel();
    _pendingSnapshot = null;
    _pendingStrike = null;
    _socket?.dispose();
    final game = _game;
    if (game != null) GameState().detachGame(game);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disconnected = _phase == 'WAITING_PLAYERS'
        ? 0
        : _players.where((player) => player['connected'] == false && player['forfeited'] != true).length;
    final finished = _latest?.phase == MatchPhase.finished;
    return SafeArea(
      child: Scaffold(
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
            if (_phase != 'WAITING_PLAYERS' && !finished)
              Chip(label: Text(_isMyTurn ? 'نوبت شما' : 'نوبت حریف'), avatar: Icon(_isMyTurn ? Icons.touch_app : Icons.hourglass_top, size: 16)),
            if (_phase != 'WAITING_PLAYERS' && !finished) Chip(label: Text('$secondsLeft ثانیه'), avatar: const Icon(Icons.timer_outlined, size: 16)),
          ])),
          if (_fattahVisible)
            Positioned(
              bottom: 18, left: 18,
              child: Tooltip(
                message: _fattahEnabled ? 'موشک فتاح — $_fattahBalance بار باقی مانده' : 'موشک فتاح ندارید؛ برای خرید بزنید',
                child: Material(
                  color: _fattahEnabled ? AppColors.coral : AppColors.muted,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _onFattahPressed,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Stack(clipBehavior: Clip.none, children: [
                        const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 26),
                        Positioned(
                          top: -9, right: -11,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _fattahEnabled ? AppColors.gold : AppColors.ink,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: Colors.white, width: 1.2),
                            ),
                            child: Text(
                              '$_fattahBalance',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _fattahEnabled ? AppColors.ink : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          if (_commandPending) const Positioned.fill(child: AbsorbPointer(child: ColoredBox(color: Colors.transparent, child: Center(child: CircularProgressIndicator())))),
          if (_phase == 'WAITING_PLAYERS') Positioned.fill(child: ColoredBox(color: const Color(0xCC151124), child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text('در انتظار تکمیل اتاق (${_players.length}/${widget.playerCount})', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('بازیکنان در حال اتصال امن به مسابقه هستند', style: TextStyle(color: AppColors.muted))])))))),
          if (disconnected > 0) Positioned(bottom: 18, left: 70, right: 18, child: Material(color: AppColors.coral, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.all(12), child: Text('$disconnected بازیکن قطع شده؛ ۶۰ ثانیه برای بازگشت فرصت دارد.', textAlign: TextAlign.center)))),
          if (_lastDice != null) Positioned(top: 72, left: 30, right: 30, child: Center(child: Material(color: AppColors.gold, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), child: Text('تاس: $_lastDice', style: const TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w900)))))),
          if (_fattahBanner != null) Positioned(top: 172, left: 24, right: 24, child: Center(child: Material(color: AppColors.coral, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(_fattahBanner!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)))))),
          if (_chatText != null) Positioned(top: 120, left: 30, right: 30, child: Center(child: Material(color: AppColors.ink, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: Text(_chatText!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))))),
          if (_localPlayerForfeited && !finished)
            Positioned.fill(child: ColoredBox(color: const Color(0xAA151124), child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.flag_rounded, size: 50, color: AppColors.coral), const SizedBox(height: 12), const Text('از مسابقه خارج شدید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 18), FilledButton(onPressed: _exitMatch, child: const Text('بازگشت به خانه'))])))))),
          if (finished)
            Positioned.fill(child: ColoredBox(color: const Color(0xAA151124), child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _winnerId == null
                    ? Icons.cancel_rounded
                    : _winnerId == _myUserId
                        ? Icons.emoji_events_rounded
                        : Icons.flag_rounded,
                size: 55,
                color: _winnerId == null ? AppColors.muted : AppColors.gold,
              ),
              const SizedBox(height: 12),
              Text(
                _winnerId == null
                    ? 'مسابقه لغو شد'
                    : _winnerId == _myUserId
                        ? 'شما قهرمان شدید! 🎉'
                        : 'مسابقه به پایان رسید',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              if (_winnerId != null && _winnerId != _myUserId && _latest?.winner != null) ...[
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: _teamColors[_latest!.winner!], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('برنده: تیم ${_teamNamesFa[_latest!.winner!]}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                ]),
              ],
              if (_winnerId == _myUserId) ...[
                const SizedBox(height: 6),
                const Text('جایزه سکه‌ای به کیف پول شما اضافه شد', style: TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 18),
              FilledButton(onPressed: _exitMatch, child: const Text('بازگشت به خانه')),
            ])))))),
        ]),
      ),
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
