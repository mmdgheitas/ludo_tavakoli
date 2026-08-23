import 'dart:async';
import 'package:flame_audio/flame_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AudioManager {
  static AudioPool? _diceSoundPool;
  static AudioPool? _moveSoundPool;
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

  static Future<void> dispose() async {
    await _diceSoundPool?.dispose();
    await _moveSoundPool?.dispose();
    _diceSoundPool = null;
    _moveSoundPool = null;
    _initialized = false;
  }
}