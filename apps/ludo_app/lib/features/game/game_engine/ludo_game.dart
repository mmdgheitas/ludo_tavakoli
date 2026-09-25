import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_command_sink.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/upper_controller.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/lower_controller.dart';
import 'package:ludo_app/features/game/game_engine/components/board/ludo_board.dart';
import 'package:ludo_app/features/game/game_engine/components/board/spot.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/ludo_dice.dart';
import 'package:ludo_app/features/game/game_engine/components/overlays/rank_modal_component.dart';
import 'package:ludo_app/features/game/game_engine/components/overlays/rocket_component.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';
import 'package:ludo_app/features/game/game_engine/models/ludo_game_state.dart';
import 'package:ludo_app/features/game/game_engine/managers/ludo_layout_config.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_initializer.dart';
import 'package:ludo_app/features/game/game_engine/managers/tile_manager.dart';
import 'package:ludo_app/features/game/game_engine/managers/token_manager.dart';

class Ludo extends FlameGame
    with HasCollisionDetection, KeyboardEvents, TapDetector {
  final List<PlayerTeam> teams;
  final BuildContext context;
  final Future<void> Function(Ludo game)? onReady;
  final GameCommandSink? commandSink;

  Ludo(this.teams, this.context, {this.onReady, this.commandSink});

  double get width => size.x;
  double get height => size.y;

  late UpperController _upperController;
  late LowerController _lowerController;

  // Keep direct ownership, including dice whose Flame add is still queued.
  // Searching children can return the outgoing player's dice during a switch.
  final Map<PlayerTeam, LudoDice> _diceByTeam = {};

  static final Map<PlayerTeam, TeamBaseConfig> _teamConfigs = {
    PlayerTeam.red: TeamBaseConfig(
      homePlateIndex: 0,
      blinkColor: const Color(0xffa3333d),
      staticColor: GameState().red,
      isUpper: true,
      diceComponentIndex: 0,
    ),
    PlayerTeam.green: TeamBaseConfig(
      homePlateIndex: 2,
      blinkColor: Colors.lightGreenAccent,
      staticColor: GameState().green,
      isUpper: true,
      diceComponentIndex: 2,
    ),
    PlayerTeam.blue: TeamBaseConfig(
      homePlateIndex: 6,
      blinkColor: Colors.lightBlueAccent,
      staticColor: GameState().blue,
      isUpper: false,
      diceComponentIndex: 0,
    ),
    PlayerTeam.yellow: TeamBaseConfig(
      homePlateIndex: 8,
      blinkColor: Colors.yellowAccent,
      staticColor: GameState().yellow,
      isUpper: false,
      diceComponentIndex: 2,
    ),
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    GameState().game = this;
    GameState().commandSink = commandSink;
    camera = CameraComponent.withFixedResolution(
      width: width,
      height: height,
    );
    camera.viewfinder.anchor = Anchor.topLeft;

    final layout = LudoLayoutConfig(screenWidth: width, screenHeight: height);
    GameState().layoutConfig = layout;

    _upperController = UpperController(
      position: layout.upperControllerPosition,
      width: layout.upperControllerWidth,
      height: layout.upperControllerHeight,
    );
    world.add(_upperController);

    world.add(LudoBoard());

    _lowerController = LowerController(
      position: layout.lowerControllerPosition,
      width: layout.lowerControllerWidth,
      height: layout.lowerControllerHeight,
    );
    world.add(_lowerController);

    /*
    add(FpsTextComponent(
      position: Vector2(10, 10), // Adjust position as needed
      anchor: Anchor.topLeft, // Set anchor to align top-left
    ));
    */

    GameState().ludoBoard = world.children.whereType<LudoBoard>().first;
    final ludoBoard = GameState().ludoBoard as PositionComponent;
    GameState().ludoBoardAbsolutePosition = ludoBoard.absolutePosition;

    await startGame();
    await onReady?.call(this);
  }

  void switchOffPointer() {
    // Online snapshots can replace currentPlayerIndex before hiding the old
    // turn. Clear every slot rather than relying on that mutable index.
    _lowerController.hidePointers();
    _upperController.hidePointers();
  }

  void blinkBaseForTeam(PlayerTeam team) {
    // Reconcile pointer visibility independently from dice ownership, including
    // same-team bonus rolls and switches before Flame's next lifecycle tick.
    if (GameState().state == LudoGameState.needRoll) {
      _upperController.showPointer(team);
      _lowerController.showPointer(team);
    } else {
      switchOffPointer();
    }
    _activateDiceForTeam(team);
  }

  void _activateDiceForTeam(PlayerTeam team) {
    final selected = _diceForTeam(team);
    for (final dice in _diceByTeam.values) {
      dice.setActive(identical(dice, selected));
    }
  }

  LudoDice? _diceForTeam(PlayerTeam team) {
    final existing = _diceByTeam[team];
    if (existing != null) return existing;
    final player = GameState().players
        .where((player) => player.playerId == team)
        .firstOrNull;
    if (player == null) return null;

    final config = _teamConfigs[team]!;
    final PositionComponent controller =
        config.isUpper ? _upperController : _lowerController;
    final controllerComponents = controller.children.toList();
    if (controllerComponents.length <= config.diceComponentIndex) return null;
    final diceBlock = controllerComponents[config.diceComponentIndex]
        .children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (diceBlock == null) return null;
    final diceContainer =
        diceBlock.children.whereType<RectangleComponent>().firstOrNull;
    if (diceContainer == null) return null;

    final dice = LudoDice(player: player, faceSize: diceBlock.size.x * 0.70);
    _diceByTeam[team] = dice;
    diceContainer.add(dice);
    return dice;
  }

  void syncDiceValue(int? value, {required PlayerTeam team}) {
    if (value == null || value < 1 || value > 6) return;
    _diceForTeam(team)?.diceFace.updateDiceValue(value);
  }

  void animateDiceValue(int value, {required PlayerTeam team}) {
    if (value < 1 || value > 6) return;
    switchOffPointer();
    // The roller can differ from both the currently displayed player and the
    // incoming snapshot's turn (a no-move roll advances the server turn).
    _activateDiceForTeam(team);
    _diceByTeam[team]?.showServerRoll(value);
  }

  /// Cosmetic Fattah strike: a rocket flies from the attacker's home area to the
  /// struck token and detonates. Resolves when the effect ends, or immediately
  /// when the board or token cannot be resolved — the authoritative snapshot has
  /// already sent the piece home, so a skipped effect is never fatal.
  Future<void> launchFattahRocket({
    required PlayerTeam attackerTeam,
    required String targetTokenId,
  }) async {
    final board = GameState().ludoBoard;
    if (board is! PositionComponent) return;
    final target = TokenManager()
        .allTokens
        .where((token) => token.tokenId == targetTokenId)
        .firstOrNull;
    if (target == null) return;

    final component = GameState().getComponentForToken(target);
    // No mounted component means no trustworthy board coordinates, so the
    // effect is skipped rather than drawn somewhere wrong.
    if (component == null) return;
    // Visual position, not logical: the snapshot already parked the token in
    // its base, but the walk-home animation has not started yet.
    final impact = Vector2(
      component.position.x + component.size.x / 2,
      component.position.y + component.size.y / 2,
    );
    final impactScale = component.size.x;

    final origin = _homeAreaCentre(attackerTeam) ?? Vector2(size.x / 2, size.y / 2);
    final rocket = RocketComponent(
      from: origin,
      to: impact,
      bodyColor: _teamConfigs[attackerTeam]?.staticColor ?? GameState().red,
      rocketSize: impactScale.clamp(size.x * 0.055, size.x * 0.12).toDouble(),
    );
    board.add(rocket);
    await rocket.finished.timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  /// Centre of a team's base plate in board coordinates — the rocket launch pad.
  Vector2? _homeAreaCentre(PlayerTeam team) {
    final baseSpotIds = switch (team) {
      PlayerTeam.blue => TokenManager().blueTokensBase.values,
      PlayerTeam.red => TokenManager().redTokensBase.values,
      PlayerTeam.green => TokenManager().greenTokensBase.values,
      PlayerTeam.yellow => TokenManager().yellowTokensBase.values,
    };
    double totalX = 0;
    double totalY = 0;
    var count = 0;
    for (final spotId in baseSpotIds) {
      final Spot? spot = TileManager().getSpot(spotId);
      if (spot == null) continue;
      totalX += spot.position.x;
      totalY += spot.position.y;
      count += 1;
    }
    if (count == 0) return null;
    return Vector2(totalX / count, totalY / count);
  }

  Future<void> startGame() async {
    await GameInitializer.run(this, teams);
  }

  @override
  Color backgroundColor() => const Color.fromARGB(0, 0, 0, 0);

  @override
  void onRemove() {
    _diceByTeam.clear();
    GameState().detachGame(this);
    TokenManager().allTokens.clear();
    TileManager().clear();
    super.onRemove();
  }

  RankModalComponent? _playerModal;

  void showPlayerModal() {
    _playerModal = RankModalComponent(
      players: GameState().players,
      position: Vector2(size.x * 0.05, size.y * 0.10),
      size: Vector2(size.x * 0.90, size.y * 0.90),
      context: context,
    );
    world.add(_playerModal!);
  }

  void hidePlayerModal() {
    _playerModal?.removeFromParent();
    _playerModal = null;
  }
}

class TeamBaseConfig {
  final int homePlateIndex;
  final Color blinkColor;
  final Color staticColor;
  final bool isUpper;
  final int diceComponentIndex;

  const TeamBaseConfig({
    required this.homePlateIndex,
    required this.blinkColor,
    required this.staticColor,
    required this.isUpper,
    required this.diceComponentIndex,
  });
}

