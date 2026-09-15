import 'dart:async';
import 'package:flame_audio/flame_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AudioManager {
  static AudioPool? _diceSoundPool;
  static AudioPool? _moveSoundPool;
  static AudioPool? _rocketSoundPool;
  static bool _initialized = false;

  static bool get _enabled =>
      !Hive.isBoxOpen('settings') ||
      (Hive.box<dynamic>('settings').get('sound', defaultValue: true) as bool);

  static Future<void> initialize() async {
    if (_initialized || !_enabled) return;
    try {
      _diceSoundPool ??= await AudioPool.createFromAsset(
        path: 'audio/dice.mp3',
        maxPlayers: 3,
      );
      _moveSoundPool ??= await AudioPool.createFromAsset(
        path: 'audio/move.mp3',
        maxPlayers: 4,
      );
      _rocketSoundPool ??= await AudioPool.createFromAsset(
        path: 'audio/rocket.mp3',
        maxPlayers: 2,
      );
      _initialized = true;
    } catch (_) {
      // Audio problems must never break gameplay.
    }
  }

  static Future<void> playDiceSound({double volume = 1.0}) async {
    final pool = _diceSoundPool;
    if (!_enabled || pool == null) return;
    unawaited(pool.start(volume: volume));
  }

  static Future<void> playMoveSound() async {
    final pool = _moveSoundPool;
    if (!_enabled || pool == null) return;
    unawaited(pool.start());
  }

  /// Fattah rocket: a launch whoosh that swells for 0.55 s and then detonates,
  /// so one sample covers the whole flight of the rocket overlay.
  static Future<void> playRocketSound({double volume = 1.0}) async {
    final pool = _rocketSoundPool;
    if (!_enabled || pool == null) return;
    unawaited(pool.start(volume: volume));
  }

  static Future<void> dispose() async {
    await _diceSoundPool?.dispose();
    await _moveSoundPool?.dispose();
    await _rocketSoundPool?.dispose();
    _diceSoundPool = null;
    _moveSoundPool = null;
    _rocketSoundPool = null;
    _initialized = false;
  }
}