import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/game/data/offline_game_repository.dart';
import 'package:ludo_app/features/game/data/offline_session_adapter.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/game_engine/ludo_game.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';
import 'package:uuid/uuid.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.playerCount, this.snapshot});
  final int playerCount;
  final GameSnapshot? snapshot;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final _repository = OfflineGameRepository();
  final _adapter = const OfflineSessionAdapter();
  Ludo? _game;
  late final String _gameId;
  int _version = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameId = widget.snapshot?.id ?? const Uuid().v4();
    _version = widget.snapshot?.version ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game ??= Ludo(
      widget.playerCount == 2
          ? [PlayerTeam.blue, PlayerTeam.green]
          : PlayerTeam.values,
      context,
      onReady: (game) async {
        if (widget.snapshot != null) {
          await _adapter.restore(game, widget.snapshot!);
        }
        _ready = true;
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_save());
    final game = _game;
    if (game != null) GameState().detachGame(game);
    super.dispose();
  }

  Future<void> _save() async {
    if (!_ready) return;
    final snapshot = _adapter.capture(_gameId, _version);
    _version = snapshot.version;
    if (snapshot.phase == MatchPhase.finished) {
      await _repository.remove(_gameId);
    } else {
      await _repository.save(snapshot);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.ink,
          title: Text(
            'بازی ${widget.playerCount} نفره',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              onPressed: () => _showExit(context),
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
        body: SafeArea(child: GameWidget(game: _game!)),
      );

  Future<void> _showExit(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'توقف بازی',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'بازی آفلاین شما پیش از خروج ذخیره می‌شود.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () async {
                  await _save();
                  if (!mounted) return;
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('ذخیره و خروج'),
              ),
            ],
          ),
        ),
      );
}
